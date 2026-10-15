unit AccessTests;

{ FPCUnit tests for common\access.pas. FindPos is the one genuine inline-asm block in
  the whole codebase and had to be rewritten (not just re-syntaxed) for 64-bit -- see
  the unit's header comment. Tested directly against crafted buffers: exact match,
  match at both boundaries, no match, joker/wildcard matching, and the sliding-window
  resync-after-partial-match case (the trickiest part of the algorithm to get wrong). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, fpcunit, testregistry, uotypes, access;

type
  TAccessTests = class(TTestCase)
  private
    Buf : String;
    function Find(const APat : String; AJoker : Byte = 0) : Integer;
  protected
    procedure SetUp; override;
  published
    procedure TestExactMatch;
    procedure TestMatchAtStart;
    procedure TestMatchAtEnd;
    procedure TestNoMatch;
    procedure TestJokerWildcard;
    procedure TestSlidingWindowResync;
    procedure TestNumStrIntelOrder;
    procedure TestNumStrByteSwapped;
    procedure TestSearchMemInvalidHandleFailsSafely;
    procedure TestMCDefaultInitialValue;
    procedure TestSearchMemRangeFindsOnlyInsideRange;
    procedure TestGetImageBaseOfNativeProcessIsLegacyDefault;
  end;

implementation

const
  RangeProbe = $10000000;          // a low address we can claim in the (64-bit) test process

procedure TAccessTests.SetUp;
begin
  Buf := 'The quick brown fox jumps over the lazy dog';
end;

function TAccessTests.Find(const APat : String; AJoker : Byte) : Integer;
var Pat : String;
begin
  Pat := APat;
  Result := FindPos(@Buf[1], @Pat[1], Length(Buf), Length(Pat), AJoker);
end;

procedure TAccessTests.TestExactMatch;
begin
  AssertEquals(10, Find('brown'));
end;

procedure TAccessTests.TestMatchAtStart;
begin
  AssertEquals(0, Find('The'));
end;

procedure TAccessTests.TestMatchAtEnd;
begin
  AssertEquals(40, Find('dog'));
end;

procedure TAccessTests.TestNoMatch;
begin
  AssertEquals(-1, Find('zzz'));
end;

procedure TAccessTests.TestJokerWildcard;
begin
  AssertEquals('? stands in for the letter o', 10, Find('br?wn', Ord('?')));
end;

procedure TAccessTests.TestSlidingWindowResync;
begin
  // "ver the" only appears starting inside "over the"; a false-start partial match
  // earlier in the scan must not desync the search from finding it at the right offset.
  AssertEquals(27, Find('ver the'));
end;

procedure TAccessTests.TestNumStrIntelOrder;
var s : String;
begin
  s := NumStr($12345678, 4, True);
  AssertEquals(4, Length(s));
  AssertEquals($78, Ord(s[1]));
  AssertEquals($56, Ord(s[2]));
  AssertEquals($34, Ord(s[3]));
  AssertEquals($12, Ord(s[4]));
end;

procedure TAccessTests.TestNumStrByteSwapped;
var s : String;
begin
  s := NumStr($12345678, 4, False);
  AssertEquals($12, Ord(s[1]));
  AssertEquals($34, Ord(s[2]));
  AssertEquals($56, Ord(s[3]));
  AssertEquals($78, Ord(s[4]));
end;

procedure TAccessTests.TestSearchMemInvalidHandleFailsSafely;
begin
  AssertEquals('invalid handle must not crash, just report not-found',
               Cardinal(0), SearchMem(0, 'ABCD', #$11));
end;

procedure TAccessTests.TestMCDefaultInitialValue;
begin
  AssertEquals(False, MCDefault);
end;

// SearchMemRange scans the caller's [Start, End] window rather than the legacy fixed one.
procedure TAccessTests.TestSearchMemRangeFindsOnlyInsideRange;
var
  P : Pointer;
  M : String;
  H : Cardinal;
begin
  // A real handle to ourselves: the access.pas API takes Cardinal handles, which cannot
  // carry the 64-bit GetCurrentProcess pseudo-handle (-1).
  H := OpenProcess(PROCESS_ALL_ACCESS, False, GetCurrentProcessId);
  if H = 0 then Ignore('Cannot open the test process');
  P := VirtualAlloc(Pointer(RangeProbe), $10000, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
  if P = nil then
  begin
    CloseHandle(H);
    Ignore('Cannot claim a low address range in the test process');
  end;
  try
    M := 'EUO-RANGE-PROBE';
    Move(M[1], Pointer(PtrUInt(P) + $2345)^, Length(M));
    Move(M[1], Pointer(PtrUInt(P) + $9000)^, Length(M));    // a second copy, far from the first

    AssertEquals('found inside the window', Cardinal(RangeProbe + $2345),
                 SearchMemRange(H, M, #0, RangeProbe, RangeProbe + $8000));
    // The scan walks $4000-byte blocks, so a window is honoured to block granularity.
    AssertEquals('window ends before the far copy', Cardinal(RangeProbe + $2345),
                 SearchMemRange(H, M, #0, RangeProbe, RangeProbe + $2000));
    AssertEquals('window starts past the first copy', Cardinal(RangeProbe + $9000),
                 SearchMemRange(H, M, #0, RangeProbe + $4000, RangeProbe + $C000));
    AssertEquals('window holds neither', Cardinal(0),
                 SearchMemRange(H, M, #0, RangeProbe + $A000, RangeProbe + $E000));
  finally
    VirtualFree(P, 0, MEM_RELEASE);
    CloseHandle(H);
  end;
end;

// A 64-bit (non-WOW64) target has no 32-bit PEB to ask, so the image base falls back to the
// $400000 every fixed-base client is linked at.
procedure TAccessTests.TestGetImageBaseOfNativeProcessIsLegacyDefault;
var
  H : Cardinal;
begin
  H := OpenProcess(PROCESS_ALL_ACCESS, False, GetCurrentProcessId);
  if H = 0 then Ignore('Cannot open the test process');
  try
    AssertEquals(Cardinal($400000), GetImageBase(H));
  finally
    CloseHandle(H);
  end;
end;

initialization
  RegisterTest(TAccessTests);
end.
