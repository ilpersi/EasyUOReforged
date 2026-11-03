unit EuoJumpTargetTests;

{
  Tests for EuoJumpTarget.pas -- where the editor's Ctrl+click on a GOSUB/GOTO name
  leads. Each lookup must land where the interpreter would go (GoSubProc: last SUB of
  that name; GoToProc: nearest label, the one below first), see EuoJumpTarget.pas's
  header comment.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoJumpTarget;

type
  TEuoJumpTargetTests = class(TTestCase)
  private
    // EuoJumpTargetAt on Src with the caret at the '|' in it (which is removed).
    function  TargetAt(const Src : array of String) : Integer;
  published
    procedure TestGosubFindsItsSub;
    procedure TestGosubIgnoresCase;
    procedure TestGosubLastSubWins;
    procedure TestSubLineWithComment;
    procedure TestGosubWithArguments;
    procedure TestGotoFindsItsLabel;
    procedure TestGotoNameWithColon;
    procedure TestGotoNearestLabelWins;
    procedure TestGotoBelowBeforeAboveAtSameDistance;
    procedure TestTabsAndIndentation;
    procedure TestColumnMustBeOnTheName;
    procedure TestUndefinedName;
    procedure TestRunTimeNamesAreNoLinks;
    procedure TestOtherCommandsAreNoLinks;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
function TEuoJumpTargetTests.TargetAt(const Src : array of String) : Integer;
var
  SL       : TStringList;
  Cnt, Col : Integer;
  Line     : Integer;
  S        : String;
begin
  SL:=TStringList.Create;
  try
    Line:=-1;
    Col:=0;
    for Cnt:=Low(Src) to High(Src) do
    begin
      S:=Src[Cnt];
      if Pos('|',S)>0 then
      begin
        Line:=Cnt;
        Col:=Pos('|',S);
        Delete(S,Col,1);
      end;
      SL.Add(S);
    end;
    AssertTrue('the test source marks the caret with |',Line>=0);
    Result:=EuoJumpTargetAt(SL,Line,Col);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestGosubFindsItsSub;
begin
  AssertEquals(3,TargetAt(['gosub fi|rst','halt','sub other','sub first','return']));
  // the first and the last character of the name both count
  AssertEquals(2,TargetAt(['gosub |first','halt','sub first','return']));
  AssertEquals(2,TargetAt(['gosub firs|t','halt','sub first','return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestGosubIgnoresCase;
begin
  AssertEquals(2,TargetAt(['GoSub My|Sub','halt','SUB mysub','return']));
end;

////////////////////////////////////////////////////////////////////////////////
// GoSubProc scans from the end: with two subs of one name the last one runs.
procedure TEuoJumpTargetTests.TestGosubLastSubWins;
begin
  AssertEquals(4,TargetAt(['gosub |a','halt','sub a','return','sub a','return']));
  // also when the gosub sits below both
  AssertEquals(2,TargetAt(['sub a','return','sub a','return','gosub |a']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestSubLineWithComment;
begin
  AssertEquals(2,TargetAt(['gosub |a','halt','sub a ; the a sub','return']));
  AssertEquals(-1,TargetAt(['gosub |a','halt','; sub a','return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestGosubWithArguments;
begin
  AssertEquals(2,TargetAt(['gosub mo|ve 10 %x','halt','sub move','return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestGotoFindsItsLabel;
begin
  AssertEquals(2,TargetAt(['goto sk|ip','halt','skip:','halt']));
  AssertEquals(0,TargetAt(['top:','wait 1','goto |top']));
  AssertEquals(2,TargetAt(['goto |Skip','halt','SKIP: ; comment','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestGotoNameWithColon;
begin
  AssertEquals(2,TargetAt(['goto sk|ip:','halt','skip:','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestGotoNearestLabelWins;
begin
  // above at distance 1 beats below at distance 2
  AssertEquals(0,TargetAt(['a:','goto |a','halt','a:']));
  // below at distance 1 beats above at distance 2
  AssertEquals(3,TargetAt(['a:','halt','goto |a','a:']));
end;

////////////////////////////////////////////////////////////////////////////////
// GoToProc tests the line below before the line above at each distance.
procedure TEuoJumpTargetTests.TestGotoBelowBeforeAboveAtSameDistance;
begin
  AssertEquals(2,TargetAt(['a:','goto |a','a:']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestTabsAndIndentation;
begin
  AssertEquals(2,TargetAt(['  if #true',#9'gosub'#9#9'a|b','  sub ab','return']));
  AssertEquals(2,TargetAt(['    goto lb|l','x','    lbl:']));
  AssertEquals(2,TargetAt(['goto l|bl','x',#9'lbl:']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestColumnMustBeOnTheName;
begin
  AssertEquals(-1,TargetAt(['gos|ub a','halt','sub a','return']));
  AssertEquals(-1,TargetAt(['gosub a |','halt','sub a','return']));
  AssertEquals(-1,TargetAt(['gosub a 1 |2','halt','sub a','return']));
  AssertEquals(-1,TargetAt(['gosub a ; |a','halt','sub a','return']));
  // just past the name is not on it
  AssertEquals(-1,TargetAt(['gosub a| 1','halt','sub a','return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestUndefinedName;
begin
  AssertEquals(-1,TargetAt(['gosub |nope','halt','sub a','return']));
  AssertEquals(-1,TargetAt(['goto |nope','halt','a:']));
  // a SUB line without a name, a sub is not a label and a label is not a sub
  AssertEquals(-1,TargetAt(['gosub |a','sub','a:']));
  AssertEquals(-1,TargetAt(['goto |a','sub a','return']));
end;

////////////////////////////////////////////////////////////////////////////////
// The interpreter compares the name after ParseLine, so these only resolve at run time.
procedure TEuoJumpTargetTests.TestRunTimeNamesAreNoLinks;
begin
  AssertEquals(-1,TargetAt(['gosub %na|me','halt','sub %name','return']));
  AssertEquals(-1,TargetAt(['gosub !na|me','halt','sub !name','return']));
  AssertEquals(-1,TargetAt(['gosub a|b . %n','halt','sub ab','return']));
  AssertEquals(-1,TargetAt(['gosub a|b , c','halt','sub ab','return']));
  AssertEquals(-1,TargetAt(['gosub a|b','  +c','halt','sub ab','return']));
  // not a variable by IsVar's test, so the interpreter takes it as written
  AssertEquals(2,TargetAt(['gosub a%|b','halt','sub a%b','return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJumpTargetTests.TestOtherCommandsAreNoLinks;
begin
  AssertEquals(-1,TargetAt(['call |a','halt','sub a','return']));
  AssertEquals(-1,TargetAt(['; gosub |a','halt','sub a','return']));
  AssertEquals(-1,TargetAt(['sub |a','return']));
  AssertEquals(-1,TargetAt(['set %a |a','a:']));
end;

initialization
  RegisterTest(TEuoJumpTargetTests);
end.
