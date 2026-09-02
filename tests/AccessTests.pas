unit AccessTests;

{ FPCUnit tests for common\access.pas. FindPos is the one genuine inline-asm block in
  the whole codebase and had to be rewritten (not just re-syntaxed) for 64-bit -- see
  the unit's header comment. Tested directly against crafted buffers: exact match,
  match at both boundaries, no match, joker/wildcard matching, and the sliding-window
  resync-after-partial-match case (the trickiest part of the algorithm to get wrong). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uotypes, access;

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
  end;

implementation

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

initialization
  RegisterTest(TAccessTests);
end.
