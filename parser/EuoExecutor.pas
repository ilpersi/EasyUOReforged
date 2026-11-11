unit EuoExecutor;

{
  Ported from the original Delphi 7 parser\executor.pas (read in full, 259 lines) --
  the TExeThread/TExecutor state machine that runs one TEuoInterpreter on a
  background thread with Play/Pause/Stop/StepInto/StepOver/StepOut control. One
  TExecutor exists per open script tab in the GUI (Phase 5).

  Ported near-verbatim; the original already uses a proper TThread (not a raw
  BeginThread+TerminateThread poller), so none of the migration plan's uoselector.pas
  threading-modernization guidance applies here -- this file was already the
  well-structured pattern that guidance describes moving *towards*. Kept
  TThread.Resume (not the newer TThread.Start) unless/until the real compiler
  demands otherwise, per this migration's "verify before changing" discipline.

  Must-preserve-exactly behaviors, both already present in the original and kept
  as-is here:
  - The Term-flag shutdown handshake in Free: request Term:=True, poll for up to
    3000ms, and only escalate to TerminateThread as a last-resort fallback if the
    thread hasn't exited cooperatively in that window. The GetTickCount-wraparound
    exposure in that comparison is the same pre-existing, unfixed characteristic
    already flagged in EuoComm.pas -- not addressed here either, for the same
    reason (not a porting risk, not something this migration was asked to fix).
  - The "j:=(j+1) and $3FF; if j=0 then Sleep(1);" freeze-prevention counter inside
    the LPC (lines-per-cycle) loop -- lets the thread yield periodically even when
    a script sets an extremely high #LPC.
  - SetState's exact legal-transition table and the StepOut->StepOver downgrade
    when already at the outermost call/sub level (an OldCall=0/OldSub=0 StepOut
    would otherwise never trigger its own stop condition).
  - KillDisplayBox's exact window-matching (#32770 dialog class + the DISPLAY
    caption) so a pending DISPLAY message box for a stopped/freed script tab gets
    closed automatically rather than leaking a modal dialog no one can dismiss.
    The caption is now EuoStdCommands.DISPLAY_CAPTION ('Reforged Message', was
    'EUO Message'); its buffer grew from 16 to 64 chars, since GetWindowText
    keeps at most size-1 chars and the 16-char new caption would never match.
  - STOP/PLAY/PAUSE/STEPINTO/STEPOVER/STEPOUT are declared once here (the original
    duplicated this same const block in both executor.pas and easyuo\insthandler.pas)
    per the migration plan's interface-contracts section.

  Breakpoint support (below) is a new addition, not present in the original
  Delphi 7 app at all. Checked at exactly the same point Step* already
  checks its own pause conditions -- right after each Parser.PlayLine call,
  inside the background thread's own loop -- rather than via the GUI's
  external ~100ms poll timer, for the same reason Step* already lives here:
  a poll could miss a breakpoint between ticks or add latency, where
  checking inline (against Parser.NextLine, which PlayLine has already
  advanced to "the line about to run next") catches it exactly, every time.
  Breaks/BreaksCS guard a small per-executor breakpoint list; toggled from
  the main thread (a gutter click) and checked from the background thread
  on every line, so this is genuine concurrent access, unlike Stat's
  existing bare-Cardinal benign race (a single scalar poll flag tolerates
  that; a list being mutated mid-scan does not) -- hence the dedicated
  TCriticalSection, matching the pattern variables.pas already uses for a
  similar frequently-read/occasionally-written shared structure.

  Two more additions, for a host that runs a script with nobody watching (EUOCli run,
  docs\agent-support.md phase 3). Both are off unless the host turns them on, so the editor
  runs scripts exactly as before:
  - StopOnRestart: the run stops when the main script starts over (an EXIT or its end at
    the outermost level, a preserved quirk that makes a script without HALT run for ever).
    Checked right after PlayLine, where the breakpoint and Step* checks are, so the first
    line does not run a second time. Restarted then says that is why it stopped.
  - OnLine: called on the script's thread with the 0-based line about to run, for a trace.

  One deliberate change to the original's behaviour, made at the owner's request
  (2026-11-11): Stop marks the script stopped BEFORE it breaks the script's current wait.
  The original's SetState did it the other way round -- Parser.Brk:=True, then the search
  for a DISPLAY box to close, and only then Stat:=Stop -- and in between the script's thread
  could leave its wait, find the state still Play, and run the line after the wait once.
  Stopping during a WAIT, TARGET, WAITFOR, ... therefore ran one more line about one time
  in four (TestWaitForEndsAtOnceOnStop failed at that rate). The original's own Free
  already used the safe order (Stat:=Stop, then Brk:=True); SetState now does the same.
  Nothing else in the transition table changes.
}

{$mode delphi}{$H+}

interface
uses SysUtils, Windows, Classes, SyncObjs, EuoInterpreter, EuoBreakCondition;

type
  TExeThread    = class(TThread)
  private
    Parent      : TObject;
    Term        : Boolean;
  protected
    procedure   Execute; override;
  end;

  // One entry per breakpointed line. Condition='' means unconditional.
  // OneShot marks a "Run to Cursor" breakpoint: removed automatically the
  // first time it's hit, never shown/toggle-able as a regular breakpoint.
  TEuoBreakpoint = class(TObject)
  public
    Line      : Integer;
    Condition : String;
    OneShot   : Boolean;
  end;

  // Port addition: see OnLine. Line is 0-based.
  TEuoLineEvent = procedure(Line : Integer) of object;

  TExecutor     = class(TObject)
  private
    Thrd        : TExeThread;
    ParWnd      : Cardinal;
    Stat        : Cardinal;
    OldCall     : Cardinal;
    OldSub      : Cardinal;
    Breaks      : TList;      // of TEuoBreakpoint
    BreaksCS    : TCriticalSection;
    FBreakLine  : Integer;    // 1-based line currently causing a breakpoint
                               // pause, or -1
    FRestarted  : Boolean;    // port addition: StopOnRestart ended the run
    FLastError  : String;     // set by TExeThread.Execute when a command raises an
                               // uncaught exception (see that method's own comment);
                               // '' means no unreported error is pending.
    procedure   SetState(Value : Cardinal);
    function    FindBreakpoint(Line : Integer) : TEuoBreakpoint; // caller
                               // must hold BreaksCS
    procedure   CheckBreakpoints;
  public
    Parser      : TEuoInterpreter;
    constructor Create(PWnd : Cardinal);
    procedure   Free;
    procedure   LoadScript(Scr : String);
    procedure   SetVar(Name, Value : String);
    function    GetVar(Name : String) : String;
    function    GetVarDump : String;
    function    CurLine : Cardinal;
    function    NextLine : Cardinal;
    function    Paused : Boolean;
    property    State : Cardinal read Stat write SetState;
    // Set when a command raised an uncaught exception on the background thread (see
    // TExeThread.Execute) -- State is already forced to STOP by then. Writable so a
    // caller (the GUI) can clear it back to '' after showing/consuming the message,
    // matching the same "poll and consume" idiom Paused already uses elsewhere in this
    // codebase for cross-thread signals.
    property    LastError : String read FLastError write FLastError;
    // Breakpoints -- Line is always 1-based, matching editor line numbers
    // (TSynEdit.CaretY / OnGutterClick's Line param), NOT Parser.CurLine/
    // NextLine's 0-based script-buffer indices.
    procedure   ToggleBreakpoint(Line : Integer);
    procedure   SetBreakpointCondition(Line : Integer; const Cond : String);
    function    HasBreakpoint(Line : Integer) : Boolean;
    function    BreakpointCondition(Line : Integer) : String;
    procedure   ClearAllBreakpoints;
    // One-shot breakpoint at Line, then State:=Play. If a real breakpoint
    // already exists on that line, this is a plain no-op resume (the real
    // one will fire anyway; no need for a redundant one-shot underneath).
    procedure   RunToLine(Line : Integer);
    function    BreakLine : Integer;
  public
    // Port additions for a host with nobody watching; see the unit header. Set them while
    // the script is stopped.
    StopOnRestart : Boolean;        // default False
    OnLine        : TEuoLineEvent;  // default nil
    // The run was stopped by StopOnRestart.
    function    Restarted : Boolean;
  end;

const
  STOP     = 0;
  PLAY     = 1;
  PAUSE    = 2;
  STEPINTO = 3;
  STEPOVER = 4;
  STEPOUT  = 5;

implementation
uses EuoStdCommands;

////////////////////////////////////////////////////////////////////////////////
/// External Thread ////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
function KillDisplayBox(Wnd : HWnd; ThrdID : Cardinal) : Boolean; stdcall;
const
  WM_CLOSE = $0010;
var
  Buf : Array[1..64] of Char;
begin
  Result:=True;
  if GetWindowThreadProcessID(Wnd,LPDWORD(nil))<>ThrdID then Exit;
  // FPC's GetWindowThreadProcessID has no 1-arg overload (Delphi's has a
  // process-id-out-param default); confirmed via compiler error, not guessed.
  GetClassName(Wnd,@Buf,64);
  if StrPas(@Buf[1])<>'#32770' then Exit;
  GetWindowText(Wnd,@Buf,64);
  if StrPas(@Buf[1])<>DISPLAY_CAPTION then Exit;
  PostMessage(Wnd,WM_CLOSE,0,0);
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TExecutor.Create(PWnd : Cardinal);
begin
  inherited Create;

  Parser:=TEuoInterpreter.Create(PWnd);
  ParWnd:=PWnd;

  Stat:=Stop;
  Breaks:=TList.Create;
  BreaksCS:=TCriticalSection.Create;
  FBreakLine:=-1;
  StopOnRestart:=False;
  FRestarted:=False;
  OnLine:=nil;
  Thrd:=TExeThread.Create(True);
  Thrd.Parent:=self;
  Thrd.Resume;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.Free;
var
  GTC : Cardinal;
  Cnt : Integer;
begin
  EnumWindows(@KillDisplayBox,Thrd.ThreadID);

  Thrd.Term:=True;
  Stat:=Stop;
  Parser.Brk:=True;
  GTC:=GetTickCount;
  while Thrd.Term do
  begin
    Sleep(1);
    if GTC+3000>GetTickCount then Continue;
    TerminateThread(Thrd.Handle,0);
    Break;
  end;
  Thrd.Free;

  for Cnt:=0 to Breaks.Count-1 do
    TEuoBreakpoint(Breaks[Cnt]).Free;
  Breaks.Free;
  BreaksCS.Free;

  Parser.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.LoadScript(Scr : String);
begin
  with Parser do
    if (Stat=Stop)and Paused then
  begin
    // Port addition (MENU 1.5/1.6): the text goes in before Clear too, because Clear
    // chooses the MENU logic from it, and Play does not reliably run SetState's own
    // Clear afterwards (that one waits for the thread to be Paused again). ScrList.Clear
    // leaves the main script's text alone.
    ScrList.Scrs[0].Text:=Scr;
    Clear;
    ScrList.Scr.Text:=Scr;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.GetVar(Name : String) : String;
begin
  Result:=Parser.GetVar(Name);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.SetVar(Name, Value : String);
begin
  Parser.SetVar(Name,Value);
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.GetVarDump : String;
begin
  Result:=Parser.GetVarDump;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.CurLine : Cardinal;
begin
  Result:=Parser.CurLine;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.NextLine : Cardinal;
begin
  Result:=Parser.NextLine;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.Paused : Boolean;
begin
  Result:=Parser.Paused;
end;

////////////////////////////////////////////////////////////////////////////////
// Caller must hold BreaksCS. Linear scan -- deliberately not indexed by
// line number: a real script's breakpoint count is always small (a
// handful at most), and this runs once per executed line from inside a
// loop that already sleeps 50ms per LPC batch, so the scan cost is
// unmeasurable next to that.
function TExecutor.FindBreakpoint(Line : Integer) : TEuoBreakpoint;
var
  Cnt : Integer;
begin
  Result:=nil;
  for Cnt:=0 to Breaks.Count-1 do
    if TEuoBreakpoint(Breaks[Cnt]).Line=Line then
    begin
      Result:=TEuoBreakpoint(Breaks[Cnt]);
      Exit;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.ToggleBreakpoint(Line : Integer);
var
  BP : TEuoBreakpoint;
begin
  BreaksCS.Enter;
  try
    BP:=FindBreakpoint(Line);
    if BP<>nil then
    begin
      Breaks.Remove(BP);
      BP.Free;
    end
    else begin
      BP:=TEuoBreakpoint.Create;
      BP.Line:=Line;
      BP.Condition:='';
      BP.OneShot:=False;
      Breaks.Add(BP);
    end;
  finally
    BreaksCS.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.SetBreakpointCondition(Line : Integer; const Cond : String);
var
  BP : TEuoBreakpoint;
begin
  BreaksCS.Enter;
  try
    BP:=FindBreakpoint(Line);
    if BP=nil then
    begin
      BP:=TEuoBreakpoint.Create;
      BP.Line:=Line;
      BP.OneShot:=False;
      Breaks.Add(BP);
    end;
    BP.Condition:=Trim(Cond);
  finally
    BreaksCS.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.HasBreakpoint(Line : Integer) : Boolean;
begin
  BreaksCS.Enter;
  try
    Result:=FindBreakpoint(Line)<>nil;
  finally
    BreaksCS.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.BreakpointCondition(Line : Integer) : String;
var
  BP : TEuoBreakpoint;
begin
  Result:='';
  BreaksCS.Enter;
  try
    BP:=FindBreakpoint(Line);
    if BP<>nil then Result:=BP.Condition;
  finally
    BreaksCS.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.ClearAllBreakpoints;
var
  Cnt : Integer;
begin
  BreaksCS.Enter;
  try
    for Cnt:=0 to Breaks.Count-1 do
      TEuoBreakpoint(Breaks[Cnt]).Free;
    Breaks.Clear;
  finally
    BreaksCS.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TExecutor.RunToLine(Line : Integer);
var
  BP : TEuoBreakpoint;
begin
  BreaksCS.Enter;
  try
    if FindBreakpoint(Line)=nil then
    begin
      BP:=TEuoBreakpoint.Create;
      BP.Line:=Line;
      BP.Condition:='';
      BP.OneShot:=True;
      Breaks.Add(BP);
    end;
  finally
    BreaksCS.Leave;
  end;
  State:=Play;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.BreakLine : Integer;
begin
  Result:=FBreakLine;
end;

////////////////////////////////////////////////////////////////////////////////
function TExecutor.Restarted : Boolean;
begin
  Result:=FRestarted;
end;

////////////////////////////////////////////////////////////////////////////////
// Called from the background thread (TExeThread.Execute), right after each
// Parser.PlayLine, exactly where Step*'s own pause checks already live.
// Parser.NextLine has already been advanced to "the line about to run
// next" by that PlayLine call -- checking it here, before the NEXT
// iteration's PlayLine, is what actually prevents a breakpointed line from
// executing (the "if Stat in [Stop,Pause] then Break;" at the top of the
// next iteration catches the Pause this sets and stops before running it).
procedure TExecutor.CheckBreakpoints;
var
  BP   : TEuoBreakpoint;
  Line : Integer;
begin
  Line:=Parser.NextLine+1;
  BreaksCS.Enter;
  try
    BP:=FindBreakpoint(Line);
    if BP=nil then Exit;
    if (BP.Condition<>'') and not EvalBreakCondition(Parser,BP.Condition) then Exit;
    FBreakLine:=Line;
    Stat:=Pause;
    if BP.OneShot then
    begin
      Breaks.Remove(BP);
      BP.Free;
    end;
  finally
    BreaksCS.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
{
  Current State:      Valid Values:
  Stop                Play, Step
  Pause               Play, Stop, Step
  Play                Pause, Stop, Step
  Step                Play, Pause, Stop, Step
}

procedure TExecutor.SetState(Value : Cardinal);
begin
  if Value=Stat then Exit;

  if Value in [Play,StepInto,StepOver,StepOut] then
    with Parser do
  begin
    if ScrList.Scrs[0].Count=0 then Exit;
    if (Stat=STOP)and Paused then
    begin
      Parser.Clear;
      FRestarted:=False;   // port addition: a new run
    end;
    Brk:=False;
    Slp:=False;
    OldCall:=ScrList.CallLevel;
    OldSub:=ScrList.SubLevel;
    if (OldCall=0)and(OldSub=0) then
      if Value=StepOut then Value:=StepOver;
    FBreakLine:=-1; // resuming -- any breakpoint-pause marker is now stale
  end;

  if Value in [Pause] then
  begin
    if Stat=Stop then Exit;
    Parser.Slp:=True;
  end;

  if Value in [Stop] then
  begin
    // Stopped first, then the wait is broken: see the unit header. The script's thread
    // tests Stat before every line, so once it leaves its wait it runs nothing more.
    Stat:=Stop;
    Parser.Brk:=True;
    EnumWindows(@KillDisplayBox,Thrd.ThreadID);
  end;

  Stat:=Value;
end;

////////////////////////////////////////////////////////////////////////////////
/// Internal Thread ////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TExeThread.Execute;
const
  WM_CLOSE = $0010;
var
  i,j : Integer;
begin
  Term:=False;
  j:=0;

  while not Term do
    with TExecutor(Parent) do
  begin
    Sleep(50);

    for i:=1 to Parser.LPC do
    begin

      if Stat in [Stop,Pause] then Break;
      Parser.Paused:=False;

      // Prevent freeze even if LPC is very high!
      j:=(j+1) and $3FF;
      if j=0 then Sleep(1);

      // A command that raises (e.g. TUOCmd.TileInit's TFileStream.Create, when the
      // attached client's own install is missing an expected .mul file -- found via a
      // real user report against an EA "Ultima Online Classic" install that ships
      // UOP-packed maps instead of classic map0.mul) used to propagate straight out of
      // this method with nothing here to catch it. TThread's own internal ThreadProc
      // wrapper swallows an uncaught exception silently (stores it, doesn't re-raise,
      // doesn't crash the process) and the thread just quietly exits -- but Stat was
      // never touched, so it stays at Play forever: the GUI keeps showing the script as
      // running (Stop/Pause still enabled, Play greyed out) with no error, no crash, and
      // no further progress -- indistinguishable from a genuine hang. Catching it here
      // and forcing a clean Stop (exactly the same transition a normal Halt/Stop already
      // performs) turns that into the ordinary "script stopped" state instead, with the
      // message available via LastError for the GUI to surface.
      try
        if Assigned(OnLine) then OnLine(Parser.NextLine);   // port addition, nil in the editor
        Parser.PlayLine;
      except
        on E: Exception do
        begin
          FLastError:=E.Message;
          Stat:=Stop;
          Break;
        end;
      end;

      case Parser.ResInt of
        RES_PAUSE : Stat:=Pause;
        RES_STOP  : Stat:=Stop;
        RES_CLOSE : begin
                      PostMessage(ParWnd,WM_CLOSE,0,0);
                      Stat:=Stop;
                    end;
      end;

      // Port addition: off in the editor. PlayLine has just put the script back on its
      // first line; stopping here keeps that line from running a second time. A script
      // whose last line is HALT also passes through ExitProc (and so counts in Restarts)
      // but has stopped by now, which is not a restart.
      if StopOnRestart and (Parser.Restarts>0) and (Stat<>Stop) then
      begin
        FRestarted:=True;
        Stat:=Stop;
      end;

      if Stat=StepOver then
        with Parser.ScrList do
      begin
        if CallLevel<OldCall then Stat:=Pause;
        if CallLevel=OldCall then
          if SubLevel<=OldSub then Stat:=Pause;
      end;

      if Stat=StepOut then
        with Parser.ScrList do
      begin
        if CallLevel<OldCall then Stat:=Pause;
        if CallLevel=OldCall then
          if SubLevel<OldSub then Stat:=Pause;
      end;

      if Stat=StepInto then Stat:=Pause;

      // Breakpoints only apply during a plain Play run -- an active Step*
      // already has its own, more specific pause condition above, and
      // re-checking breakpoints on top of that could only ever pause
      // earlier than the step itself asked for, never later.
      if Stat=Play then CheckBreakpoints;

    end;
    Parser.Paused:=True;

  end;

  Term:=False;
end;

////////////////////////////////////////////////////////////////////////////////
end.
