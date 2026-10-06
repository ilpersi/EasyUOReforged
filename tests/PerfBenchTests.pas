unit PerfBenchTests;

{
  Opt-in interpreter micro-benchmark + in-process sampling profiler. Not a correctness test:
  every case is Ignore()d unless the environment variable EUO_PERF=1 is set, so the normal
  CI run stays fast.

  What it measures: lines/second through TEuoInterpreter.PlayLine, driven synchronously on
  the calling thread exactly as EuoInterpreterTests does (no TExecutor thread, so the 50 ms
  tick and #LPC are out of the picture) with no UO client attached (TUOSel.Nr = 0). Each
  workload runs for a fixed wall-clock window, so a faster interpreter simply executes more
  lines in it.

  Sampling: with EUO_PERF_SAMPLE=1 a helper thread suspends the benchmark thread about
  every millisecond, reads its instruction pointer and resumes it. The raw addresses are
  aggregated and written to perf_samples_<workload>.txt (as RVA + count) next to the
  executable; tests\tools\ResolveSamples.ps1 maps them to routine names via objdump's
  symbol table. The sampler allocates nothing while the target is suspended -- the target
  may be holding the heap lock.

  Build and run it through tests\tools\RunBench.ps1 (a Bench build mode: -O3 plus symbols).
  Numbers from the default (unoptimised) test build are not representative.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Windows, fpcunit, testregistry, EuoInterpreter,
  uotypes, uoselector, uovariables, uocommands;

type
  TWorkProc = procedure of object;

  TPerfBenchTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    Sel : TUOSel;
    Vr  : TUOVar;
    Cmd : TUOCmd;
    procedure Bench(const Name, Script : String);
    function  NoWaitDelay(Duration : Cardinal) : Boolean;
    procedure WorkItems;
    procedure WorkJournal;
    procedure WorkVars;
    procedure BenchLive(const Name : String; Work : TWorkProc);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSetIncrement;
    procedure TestSetExpression;
    procedure TestSetConcat;
    procedure TestIfBlock;
    procedure TestForLoop;
    procedure TestGoSub;
    procedure TestSetSysVar;
    procedure TestLongLine;
    procedure TestLiveScanItems;
    procedure TestLiveScanJournal;
    procedure TestLiveVarReads;
  end;

implementation

const
  RunSeconds    = 2.0;   // wall-clock window per workload
  WarmupSeconds = 0.25;
  MaxSamples    = 20000;

// Not declared in FPC 3.2.2's Windows unit. With GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS the
// "name" argument is an address inside the module, hence Pointer.
function GetModuleHandleEx(dwFlags : DWORD; lpModuleName : Pointer; var phModule : HMODULE) : BOOL;
  stdcall; external 'kernel32.dll' name 'GetModuleHandleExW';
function timeBeginPeriod(uPeriod : UINT) : UINT; stdcall; external 'winmm.dll' name 'timeBeginPeriod';
function timeEndPeriod(uPeriod : UINT) : UINT; stdcall; external 'winmm.dll' name 'timeEndPeriod';

////////////////////////////////////////////////////////////////////////////////
function PerfEnabled : Boolean;
begin
  Result := SysUtils.GetEnvironmentVariable('EUO_PERF') = '1';
end;

////////////////////////////////////////////////////////////////////////////////
function Now_Sec : Double;
var
  f, c : Int64;
begin
  QueryPerformanceFrequency(f);
  QueryPerformanceCounter(c);
  Result := c / f;
end;

////////////////////////////////////////////////////////////////////////////////
const
  MaxFrames = 64;      // frames kept per sample (innermost first)

// Win64 stack unwinding straight from the unwind tables every FPC-compiled function carries
// (.pdata). Kernel32 exports both; neither allocates, which matters: they run while the
// target thread is suspended and could be holding the heap lock.
function RtlLookupFunctionEntry(ControlPc : QWord; var ImageBase : QWord; HistoryTable : Pointer) : Pointer;
  stdcall; external 'kernel32.dll' name 'RtlLookupFunctionEntry';
function RtlVirtualUnwind(HandlerType : DWORD; ImageBase, ControlPc : QWord; FunctionEntry : Pointer;
  ContextRecord : Pointer; var HandlerData : Pointer; var EstablisherFrame : QWord;
  ContextPointers : Pointer) : Pointer; stdcall; external 'kernel32.dll' name 'RtlVirtualUnwind';

type
  TSample = record
    Rip     : PtrUInt;
    NFrames : Integer;
    Frames  : array[0..MaxFrames - 1] of PtrUInt;   // return addresses inside the exe, innermost first
  end;

  TSampler = class(TThread)
  private
    FTarget  : THandle;
    FTextLo  : PtrUInt;
    FTextHi  : PtrUInt;
  protected
    procedure Execute; override;
  public
    Samples  : array of TSample;
    Count    : Integer;
    constructor Create(ATargetThreadId : DWORD);
    destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
constructor TSampler.Create(ATargetThreadId : DWORD);
const
  THREAD_SUSPEND_RESUME    = $0002;
  THREAD_GET_CONTEXT       = $0008;
  THREAD_QUERY_INFORMATION = $0040;
var
  Base, Nt : PtrUInt;
begin
  inherited Create(True);
  SetLength(Samples, MaxSamples);
  Count := 0;
  FTarget := OpenThread(THREAD_SUSPEND_RESUME or THREAD_GET_CONTEXT or THREAD_QUERY_INFORMATION,
                        False, ATargetThreadId);
  // The exe's own code range, from its PE header: OptionalHeader.SizeOfCode / BaseOfCode.
  Base := PtrUInt(GetModuleHandle(nil));
  Nt := Base + PDWORD(Base + $3C)^;
  FTextLo := Base + PDWORD(Nt + 24 + 20)^;
  FTextHi := FTextLo + PDWORD(Nt + 24 + 4)^;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TSampler.Destroy;
begin
  if FTarget <> 0 then CloseHandle(FTarget);
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSampler.Execute;
const
  CTX_SIZE      = 1232;       // sizeof(CONTEXT) on x64
  CTX_FLAGS_OFS = $30;
  CTX_RSP_OFS   = $98;
  CTX_RIP_OFS   = $F8;
  CONTEXT_CONTROL_INTEGER_AMD64 = $100003;   // CONTROL or INTEGER: what unwinding needs
  MaxWalk       = 128;
var
  raw   : array[0..CTX_SIZE + 15] of Byte;
  p     : PByte;
  Rip   : QWord;
  Base  : QWord;
  Entry : Pointer;
  HData : Pointer;
  Frame : QWord;
  n, d  : Integer;
begin
  // GetThreadContext requires a 16-byte aligned CONTEXT.
  p := PByte((PtrUInt(@raw[0]) + 15) and not PtrUInt(15));
  while not Terminated do
  begin
    Sleep(1);
    if Count >= MaxSamples then Continue;
    if SuspendThread(FTarget) = DWORD(-1) then Continue;
    // Nothing between Suspend and Resume may allocate or take a lock.
    FillChar(p^, CTX_SIZE, 0);
    PDWORD(PtrUInt(p) + CTX_FLAGS_OFS)^ := CONTEXT_CONTROL_INTEGER_AMD64;
    if GetThreadContext(FTarget, PContext(p)) then
    begin
      Rip := PQWord(PtrUInt(p) + CTX_RIP_OFS)^;
      Samples[Count].Rip := Rip;
      n := 0;
      d := 0;
      while (Rip <> 0) and (d < MaxWalk) do
      begin
        Inc(d);
        // Only the exe's frames are kept: that is all the resolver can name, and it keeps
        // the file small. The leaf (Rip above) is recorded separately, wherever it is.
        if (Rip >= FTextLo) and (Rip < FTextHi) and (n < MaxFrames) then
        begin
          Samples[Count].Frames[n] := Rip;
          Inc(n);
        end;
        Base := 0;
        Entry := RtlLookupFunctionEntry(Rip, Base, nil);
        if Entry = nil then
        begin
          // Leaf function without unwind data: the return address is at [Rsp].
          Frame := PQWord(PtrUInt(p) + CTX_RSP_OFS)^;
          if Frame = 0 then Break;
          PQWord(PtrUInt(p) + CTX_RIP_OFS)^ := PQWord(Frame)^;
          PQWord(PtrUInt(p) + CTX_RSP_OFS)^ := Frame + 8;
        end
        else
        begin
          HData := nil;
          Frame := 0;
          RtlVirtualUnwind(0, Base, Rip, Entry, p, HData, Frame, nil);
        end;
        Rip := PQWord(PtrUInt(p) + CTX_RIP_OFS)^;
      end;
      Samples[Count].NFrames := n;
      Inc(Count);
    end;
    ResumeThread(FTarget);
  end;
end;


////////////////////////////////////////////////////////////////////////////////
// "<module path>|<RVA hex>" for an address inside a loaded module other than the exe
// (ntdll, kernel32, ...), or just "<RVA hex>" for the exe itself.
function ModuleKey(Addr, ExeBase : PtrUInt) : String;
const
  FROM_ADDRESS     = $4;
  UNCHANGED_REFCNT = $2;
var
  h    : HMODULE;
  Buf  : array[0..MAX_PATH] of Char;
  Len  : DWORD;
begin
  h := 0;
  if (GetModuleHandleEx(FROM_ADDRESS or UNCHANGED_REFCNT, Pointer(Addr), h)) and (h <> 0) and (PtrUInt(h) <> ExeBase) then
  begin
    Len := GetModuleFileName(h, @Buf[0], MAX_PATH);
    SetString(Result, PChar(@Buf[0]), Len);
    Result := Result + '|' + IntToHex(Addr - PtrUInt(h), 16);
    Exit;
  end;
  Result := IntToHex(Addr - ExeBase, 16);
end;

////////////////////////////////////////////////////////////////////////////////
procedure DumpSamples(const Name : String; S : TSampler);
// One line per sample: "<leaf key>;<caller RVA hex> <caller RVA hex> ..." (innermost first).
var
  Base : PtrUInt;
  i, j : Integer;
  Line : String;
  Out_ : TStringList;
begin
  Base := PtrUInt(GetModuleHandle(nil));
  Out_ := TStringList.Create;
  try
    Out_.Add('total=' + IntToStr(S.Count));
    for i := 0 to S.Count - 1 do
    begin
      Line := ModuleKey(S.Samples[i].Rip, Base) + ';';
      for j := 0 to S.Samples[i].NFrames - 1 do
        Line := Line + IntToHex(S.Samples[i].Frames[j] - Base, 1) + ' ';
      Out_.Add(Line);
    end;
    Out_.SaveToFile(ExtractFilePath(ParamStr(0)) + 'perf_samples_' + Name + '.txt');
  finally
    Out_.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.SetUp;
begin
  Interp := TEuoInterpreter.Create(0);
  Interp.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.TearDown;
begin
  Interp.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.Bench(const Name, Script : String);
var
  t0, t1, tEnd : Double;
  Lines        : Int64;
  i            : Integer;
  Sampler      : TSampler;
  Report       : String;
  F            : TextFile;
  LogName      : String;
  OldPrio      : DWORD;
begin
  if not PerfEnabled then
  begin
    Ignore('set EUO_PERF=1 to run the interpreter benchmark');
    Exit;
  end;

  Interp.ScrList.Scr.Text := Script;
  Interp.NextLine := 0;

  // Warm up (caches, lazy allocations), then reset to the top of the script.
  tEnd := Now_Sec + WarmupSeconds;
  while Now_Sec < tEnd do
    for i := 1 to 500 do Interp.PlayLine;
  Interp.NextLine := 0;

  // A benchmark on a busy desktop: run at high priority so other processes steal less.
  OldPrio := GetPriorityClass(GetCurrentProcess);
  SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS);
  timeBeginPeriod(1);
  Sampler := nil;
  try
    if SysUtils.GetEnvironmentVariable('EUO_PERF_SAMPLE') = '1' then
    begin
      Sampler := TSampler.Create(GetCurrentThreadId);
      Sampler.Start;
    end;

    Lines := 0;
    t0 := Now_Sec;
    tEnd := t0 + RunSeconds;
    repeat
      for i := 1 to 500 do Interp.PlayLine;
      Inc(Lines, 500);
      t1 := Now_Sec;
    until t1 >= tEnd;

    if Sampler <> nil then
    begin
      Sampler.Terminate;
      Sampler.WaitFor;
      DumpSamples(Name, Sampler);
    end;
  finally
    Sampler.Free;
    timeEndPeriod(1);
    SetPriorityClass(GetCurrentProcess, OldPrio);
  end;

  Report := Format('PERF %-12s %10.0f lines/s  (%d lines in %.2fs)',
                   [Name, Lines / (t1 - t0), Lines, t1 - t0]);
  Writeln(Report);
  LogName := ExtractFilePath(ParamStr(0)) + 'perf_results.txt';
  AssignFile(F, LogName);
  if FileExists(LogName) then Append(F) else Rewrite(F);
  Writeln(F, Report);
  CloseFile(F);

  AssertTrue('interpreter made progress', Lines > 0);
end;

////////////////////////////////////////////////////////////////////////////////
// Every workload is an endless loop (GOTO back to the top) so the line counter, not
// the script length, ends the run. CR/LF-separated, like the interpreter tests.

procedure TPerfBenchTests.TestSetIncrement;
begin
  Bench('set_inc',
    'SET %a 0' + #13#10 +
    'top:' + #13#10 +
    'SET %a %a +' + #13#10 +
    'GOTO top:');
end;

procedure TPerfBenchTests.TestSetExpression;
begin
  Bench('set_expr',
    'SET %a 7' + #13#10 +
    'top:' + #13#10 +
    'SET %b ( %a * 3 + 1 )' + #13#10 +
    'SET %c ( %b - %a )' + #13#10 +
    'GOTO top:');
end;

procedure TPerfBenchTests.TestSetConcat;
begin
  Bench('set_concat',
    'SET %a 5' + #13#10 +
    'top:' + #13#10 +
    'SET %s hello world %a' + #13#10 +
    'GOTO top:');
end;

procedure TPerfBenchTests.TestIfBlock;
begin
  Bench('if_block',
    'SET %a 0' + #13#10 +
    'top:' + #13#10 +
    'IF ( %a < 5 )' + #13#10 +
    '{' + #13#10 +
    'SET %x 1' + #13#10 +
    'SET %y 2' + #13#10 +
    '}' + #13#10 +
    'ELSE' + #13#10 +
    '{' + #13#10 +
    'SET %x 3' + #13#10 +
    'SET %y 4' + #13#10 +
    '}' + #13#10 +
    'GOTO top:');
end;

procedure TPerfBenchTests.TestForLoop;
begin
  Bench('for_loop',
    'top:' + #13#10 +
    'FOR %i 1 1000' + #13#10 +
    'SET %x %i' + #13#10 +
    'NEXT' + #13#10 +
    'GOTO top:');
end;

procedure TPerfBenchTests.TestGoSub;
begin
  Bench('gosub',
    'top:' + #13#10 +
    'GOSUB f 21' + #13#10 +
    'GOTO top:' + #13#10 +
    'SUB f' + #13#10 +
    'SET %x %1' + #13#10 +
    'RETURN ( %1 * 2 )');
end;

procedure TPerfBenchTests.TestSetSysVar;
begin
  Bench('set_sysvar',
    'top:' + #13#10 +
    'SET #LPC 10' + #13#10 +
    'GOTO top:');
end;

procedure TPerfBenchTests.TestLongLine;
begin
  Bench('long_line',
    'SET %a 1' + #13#10 +
    'top:' + #13#10 +
    'SET %z ( %a + %a + %a + %a + %a + %a + %a + %a + %a + %a + %a + %a ) ; trailing comment' + #13#10 +
    'GOTO top:');
end;


////////////////////////////////////////////////////////////////////////////////
// Live-client benchmarks. Read-only (memory reads through the same TUOVar/TUOCmd paths the
// scripts use); skipped unless EUO_PERF=1 AND a supported client is running and logged in.

function TPerfBenchTests.NoWaitDelay(Duration : Cardinal) : Boolean;
begin
  Result := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.WorkItems;
begin
  Cmd.ScanItems;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.WorkJournal;
begin
  Cmd.ScanJournal(0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.WorkVars;
begin
  // A representative handful of the cheap state reads scripts poll in a loop.
  if Vr.CharPosX = 0 then Exit;
  if Vr.CharPosY = 0 then Exit;
  if Vr.CharStatus = 'x' then Exit;
  if Vr.CharName = '' then Exit;
  if Vr.CharID = 0 then Exit;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.BenchLive(const Name : String; Work : TWorkProc);
var
  Probe   : TUOSel;
  Waited  : Cardinal;
  t0, t1, tEnd : Double;
  Calls   : Int64;
  Report  : String;
  F       : TextFile;
  LogName : String;
  OldPrio : DWORD;
begin
  if not PerfEnabled then
  begin
    Ignore('set EUO_PERF=1 to run the benchmark');
    Exit;
  end;

  Sel := TUOSel.Create;
  Vr  := TUOVar.Create(Sel);
  Cmd := TUOCmd.Create(Sel, Vr, NoWaitDelay);
  try
    Probe := Sel;
    Waited := 0;
    while (Probe.Cnt = 0) and (Waited < 1500) do begin Sleep(100); Inc(Waited, 100); end;
    if Probe.Cnt = 0 then begin Ignore('No live client detected.'); Exit; end;
    if not Sel.SelectClient(1) then begin Ignore('SelectClient(1) failed.'); Exit; end;
    if not Vr.CliLogged then begin Ignore('Client not logged in.'); Exit; end;

    OldPrio := GetPriorityClass(GetCurrentProcess);
    SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS);
    try
      tEnd := Now_Sec + 0.25;
      while Now_Sec < tEnd do Work;                 // warm-up

      Calls := 0;
      t0 := Now_Sec;
      tEnd := t0 + RunSeconds;
      repeat
        Work;
        Inc(Calls);
        t1 := Now_Sec;
      until t1 >= tEnd;
    finally
      SetPriorityClass(GetCurrentProcess, OldPrio);
    end;

    Report := Format('PERF %-12s %10.0f calls/s  (%d calls in %.2fs)',
                     [Name, Calls / (t1 - t0), Calls, t1 - t0]);
    Writeln(Report);
    LogName := ExtractFilePath(ParamStr(0)) + 'perf_results.txt';
    AssignFile(F, LogName);
    if FileExists(LogName) then Append(F) else Rewrite(F);
    Writeln(F, Report);
    CloseFile(F);
  finally
    Cmd.Free;
    Vr.Free;
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPerfBenchTests.TestLiveScanItems;
begin
  BenchLive('live_items', WorkItems);
end;

procedure TPerfBenchTests.TestLiveScanJournal;
begin
  BenchLive('live_journal', WorkJournal);
end;

procedure TPerfBenchTests.TestLiveVarReads;
begin
  BenchLive('live_vars', WorkVars);
end;
////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TPerfBenchTests);

end.
