unit access;

{
  Ported from the original Delphi 7 common\access.pas.

  Fix applied (required regardless of host bitness -- see migration plan): the original
  hand-declared ReadProcessMemory/WriteProcessMemory via LoadLibrary+GetProcAddress into
  function-pointer types whose byte-count parameter was typed Cardinal (4 bytes). FPC's
  (and the real Win32 API's) declaration types that parameter PTRUINT -- 4 bytes on
  Win32, 8 bytes on Win64. Calling through the mistyped pointer on a 64-bit build would
  corrupt the stack. Fixed by deleting that plumbing and calling Windows.ReadProcessMemory/
  WriteProcessMemory directly, with a correctly-widthed PtrUInt local for the byte-count
  out-parameter. The algorithm (binary-search shrink in ReadMem, discarding the API's own
  boolean result and only inspecting the bytes-transferred count) is otherwise unchanged.

  FindPos below is the one genuine x86 inline-asm block in the whole codebase. The
  ASMMODE INTEL compiler directive added below selects Delphi-compatible Intel syntax
  (FPC defaults to AT&T). Unlike everything else in this unit, this block could NOT be
  ported as pure syntax translation: the original uses 32-bit registers (edi/esi/edx/
  ebx/ecx/eax) to hold PBuf/PScanStr, which are Pointer parameters -- 4 bytes on Win32,
  but 8 bytes on Win64. Two real problems, not just syntax: (1) x86-64's PUSH/POP have
  no encoding for a 32-bit register operand in long mode, so "push edi" etc. simply
  fails to assemble; (2) even where it would assemble, truncating a genuine 64-bit host
  pointer into a 32-bit register would silently corrupt it whenever the buffer's real
  address exceeds 4GB, which is common for a 64-bit process's heap/stack. Rewritten
  below using the 64-bit register forms (rdi/rsi/rdx/rbx) for everything that holds a
  pointer or pointer-range boundary, while the small bounded values (the byte-match
  counter, the Joker byte) stay in their 32-/8-bit forms exactly as before -- with
  explicit zero-extending loads (mov reg32, CardinalParam) wherever a 32-bit Cardinal
  parameter (BufLen/ScanLen) needs to combine with a 64-bit pointer register, since x86
  has no direct 64-bit-register-op-32-bit-memory-operand form. The underlying byte-
  matching algorithm (naive sliding-window scan with a wildcard/joker byte) is otherwise
  bit-for-bit the same as the original -- verified against a live in-process buffer via
  Lazarus\tests\tools\smoketest_access.pas, not just "it compiles."
}

{$mode delphi}{$H+}
{$ASMMODE INTEL}

interface

uses
  Windows;

function ReadMem(PHandle : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal) : Boolean;
function WriteMem(PHandle : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal) : Boolean;
function NumStr(DW : Cardinal; Size : Integer; Intel : Boolean) : String;
function SearchMem(PHandle : Cardinal; ScanStr : String; Joker : Char) : Cardinal;

// Port additions (not in the original) for clients that are not loaded at the fixed
// $400000 image base. The "modern" builds (DYNAMIC_BASE set in the PE header) are
// relocated by the loader, e.g. to $E10000, and their code is far larger than the
// $400000-$650000 window SearchMem is hard-wired to.
type
  TImageInfo = record
    Valid          : Boolean;
    Base           : Cardinal;       // where the exe is actually loaded in the process
    PreferredBase  : Cardinal;       // OptionalHeader.ImageBase -- NB the loader rewrites this to Base when it relocates
    SizeOfImage    : Cardinal;
    TimeDateStamp  : Cardinal;       // FileHeader.TimeDateStamp -- identifies the exact build
    DllChars       : Word;           // OptionalHeader.DllCharacteristics ($40 = DYNAMIC_BASE)
    CodeStart      : Cardinal;       // live address range of the exe's executable section(s)
    CodeEnd        : Cardinal;
  end;

// Same scan as SearchMem but over [StartAddr, EndAddr] instead of the fixed legacy window.
function SearchMemRange(PHandle : Cardinal; ScanStr : String; Joker : Char;
                        StartAddr, EndAddr : Cardinal) : Cardinal;
// Load address of the process's main exe (WOW64 PEB lookup); $400000 if it can't be determined.
function GetImageBase(PHandle : Cardinal) : Cardinal;
function ReadImageInfo(PHandle : Cardinal; out Info : TImageInfo) : Boolean;

// Implementation-private in the original (used only by SearchMem); exposed here, harmlessly,
// so it can be unit-tested directly against crafted in-memory buffers with no OS process
// involvement at all, per the migration plan's testing strategy.
function FindPos(PBuf, PScanStr : Pointer; BufLen, ScanLen : Cardinal; Joker : Byte) : Integer;

var
  MCDefault : Boolean = False;

implementation

////////////////////////////////////////////////////////////////////////////////
function ReadMem(PHandle : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal) : Boolean;
var
  Code  : PtrUInt;                                                              // widened: real API param is PTRUINT, not Cardinal
  A,E,I : Cardinal;
begin
  Result:=False;
  E:=Length;
  A:=0;
  I:=Length;
  ZeroMemory(Buf,Length);
  repeat
    Windows.ReadProcessMemory(THandle(PHandle),Pointer(PtrUInt(MemPos)),Buf,I,Code); // boolean result
                                                                                       // deliberately ignored,
                                                                                       // exactly as original
    if Code=0 then E:=I
    else begin
      A:=I;
      Result:=True;
    end;
    if E-A<2 then Break;
    I:=A+((E-A)div 2);
  until False;
end;

////////////////////////////////////////////////////////////////////////////////
function WriteMem(PHandle : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal) : Boolean;
var
  Code : PtrUInt;                                                               // widened: real API param is PTRUINT, not Cardinal
begin
  Result:=Windows.WriteProcessMemory(THandle(PHandle),Pointer(PtrUInt(MemPos)),Buf,Length,Code);
end;

////////////////////////////////////////////////////////////////////////////////
function NumStr(DW : Cardinal; Size : Integer; Intel : Boolean) : String;
var
  sBuf : String;
  sCh  : Char;
begin
  SetLength(sBuf,Size);
  Move(DW,sBuf[1],Size);

  if not Intel then
  case Size of
    4 : begin
          sCh:=sBuf[1];
          sBuf[1]:=sBuf[4];
          sBuf[4]:=sCh;
          sCh:=sBuf[2];
          sBuf[2]:=sBuf[3];
          sBuf[3]:=sCh;
        end;
    2 : begin
          sCh:=sBuf[1];
          sBuf[1]:=sBuf[2];
          sBuf[2]:=sCh;
        end;
  end;

  Result:=sBuf;
end;

////////////////////////////////////////////////////////////////////////////////
function FindPos(PBuf, PScanStr : Pointer; BufLen, ScanLen : Cardinal; Joker : Byte) : Integer;
var
  RetVal : Integer;
label N1,N2,W1,W2,W3;
begin
  asm
    push  rdi
    push  rsi
    push  rbp
    push  rbx

    mov   rdi, PBuf                // rdi = PBuf (Pointer param, 8 bytes -- direct width-matched load)

    mov   rdx, rdi                 // rdx = PBuf
    mov   ecx, BufLen              // ecx = BufLen (32-bit load zero-extends rcx's upper half)
    add   rdx, rcx                 // rdx = PBuf + BufLen           (64-bit reg + 64-bit reg)
    mov   ecx, ScanLen             // ecx = ScanLen (zero-extends rcx again)
    sub   rdx, rcx                 // rdx = PBuf + BufLen - ScanLen (64-bit reg - 64-bit reg)

    mov   eax, -1                  // eax = -1 sentinel; RetVal is 32-bit, only eax is ever read back
    mov   ecx, 0

    N1:
    mov   rsi, PScanStr            // rsi = PScanStr (Pointer param, direct width-matched load)
    sub   rdi, rcx                 // rewind by previous partial-match length (rcx's upper bits are 0)
    mov   ecx, 0

    cmp   rdi, rdx
    jg    W1

    N2:
    mov   bl, Joker
    cmp   [rsi], bl
    jne   W3
    cmpsb                         // 64-bit mode: implicitly advances RSI/RDI (not ESI/EDI)
    jmp   W2
    W3:

    cmpsb
    jne   N1

    W2:
    inc   ecx
    cmp   ecx, ScanLen             // ecx (32-bit) vs ScanLen (Cardinal, 32-bit) -- width matched, unchanged
    jne   N2

    sub   rdi, rcx                 // rcx == ScanLen here (the comparison above didn't jump away)
    mov   rax, rdi
    sub   rax, PBuf                // rax -= PBuf (64-bit reg - 64-bit Pointer param, width matched)
    W1:
    mov   RetVal, eax              // store the low 32 bits (every real BufLen here is $4000, so the
                                    // true offset always fits in 32 bits; the "not found" path never
                                    // wrote anything past the initial eax=-1)

    pop   rbx
    pop   rbp
    pop   rsi
    pop   rdi
  end;
  FindPos:=RetVal;
end;

////////////////////////////////////////////////////////////////////////////////
function SearchMemRange(PHandle : Cardinal; ScanStr : String; Joker : Char;
                        StartAddr, EndAddr : Cardinal) : Cardinal;
var
  Cnt  : Int64;
  Cnt2 : Integer;
  Buf  : Array[0..$3FFF] of Byte;
begin
  Cnt:=StartAddr;
  Cnt2:=-1;
  repeat
    if not ReadMem(PHandle,Cardinal(Cnt),@Buf,$4000) then Break;
    Cnt2:=FindPos(@Buf,@ScanStr[1],$4000,Length(ScanStr),Byte(Joker));
    if Cnt2>-1 then Break;
    Cnt:=Cnt+$4000-Length(ScanStr)+1;
  until Cnt>EndAddr;
  Cnt:=Cnt+Cnt2;

  if Cnt2>-1 then Result:=Cardinal(Cnt)
  else Result:=0;
end;

////////////////////////////////////////////////////////////////////////////////
function SearchMem(PHandle : Cardinal; ScanStr : String; Joker : Char) : Cardinal;
begin
  Result:=SearchMemRange(PHandle,ScanStr,Joker,$00400000,$00650000);
end;

////////////////////////////////////////////////////////////////////////////////
function GetImageBase(PHandle : Cardinal) : Cardinal;
type
  TNtQueryInformationProcess = function(hProc : THandle; InfoClass : Cardinal;
    Info : Pointer; InfoLen : Cardinal; RetLen : PCardinal) : LongInt; stdcall;
const
  ProcessWow64Information = 26;
var
  NtQIP : TNtQueryInformationProcess;
  Peb32 : PtrUInt;
  Base  : Cardinal;
begin
  Result:=$00400000;
  NtQIP:=TNtQueryInformationProcess(GetProcAddress(GetModuleHandle('ntdll.dll'),'NtQueryInformationProcess'));
  if not Assigned(NtQIP) then Exit;
  Peb32:=0;
  if NtQIP(THandle(PHandle),ProcessWow64Information,@Peb32,SizeOf(Peb32),nil)<>0 then Exit;
  if Peb32=0 then Exit;                                   // not a WOW64 (32-bit) target
  Base:=0;
  ReadMem(PHandle,Cardinal(Peb32)+8,@Base,4);             // PEB32.ImageBaseAddress
  if Base<>0 then Result:=Base;
end;

////////////////////////////////////////////////////////////////////////////////
function ReadImageInfo(PHandle : Cardinal; out Info : TImageInfo) : Boolean;
var
  Hdr  : Array[0..$FFF] of Byte;
  PE   : Cardinal;
  Cnt  : Integer;
  Sec  : Cardinal;
  VA,VS: Cardinal;
begin
  FillChar(Info,SizeOf(Info),0);
  Result:=False;
  Info.Base:=GetImageBase(PHandle);
  if not ReadMem(PHandle,Info.Base,@Hdr,SizeOf(Hdr)) then Exit;
  if PWord(@Hdr[0])^<>$5A4D then Exit;                    // 'MZ'
  PE:=PCardinal(@Hdr[$3C])^;
  if (PE>SizeOf(Hdr)-$200) or (PCardinal(@Hdr[PE])^<>$00004550) then Exit;   // 'PE'#0#0
  Info.TimeDateStamp:=PCardinal(@Hdr[PE+8])^;
  Info.PreferredBase:=PCardinal(@Hdr[PE+24+28])^;
  Info.SizeOfImage:=PCardinal(@Hdr[PE+24+56])^;
  Info.DllChars:=PWord(@Hdr[PE+24+70])^;

  // Executable section range (IMAGE_SCN_CNT_CODE / MEM_EXECUTE) for scanning.
  Sec:=PE+24+PWord(@Hdr[PE+20])^;
  for Cnt:=0 to PWord(@Hdr[PE+6])^-1 do
  begin
    if Sec+40>SizeOf(Hdr) then Break;
    if PCardinal(@Hdr[Sec+36])^ and ($00000020 or $20000000)<>0 then
    begin
      VA:=PCardinal(@Hdr[Sec+12])^;
      VS:=PCardinal(@Hdr[Sec+8])^;
      if Info.CodeStart=0 then Info.CodeStart:=Info.Base+VA;
      if Info.Base+VA+VS>Info.CodeEnd then Info.CodeEnd:=Info.Base+VA+VS;
    end;
    Inc(Sec,40);
  end;
  Info.Valid:=True;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  // IMPORTANT: matches the original's IsMultiThread:=True / Set8087CW($27F) intent --
  // FPC's multithreading support is enabled per-program via the cthreads/cmem unit
  // wiring in each project's .lpr, not per-unit here; see EasyUOReforged.lpr / uo.lpr.
end.
