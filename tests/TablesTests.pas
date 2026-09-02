unit TablesTests;

{ FPCUnit tests for the fixed uo\tables.pas -- the binary-search dispatch primitive
  every UO.xxx call is routed through. Uses small synthetic TItem/TIndex fixtures
  (testing against the real 140-row UOTbl/11-row Commands tables happens once
  uowrap.pas itself is ported, in a later phase). Covers Find_First (both overloads),
  Find_Next walking overloads, and ParComp's mask grammar via Check. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, stack, tables;

type
  TAlphaBeta = class(TObject)
  end;

  TTablesTests = class(TTestCase)
  private
    Items : array[0..3] of TItem;   // sorted: Alpha, Beta, Beta, Gamma
  protected
    procedure SetUp; override;
  published
    procedure TestFindFirstExactMatch;
    procedure TestFindFirstFindsFirstOfDuplicates;
    procedure TestFindFirstNotFound;
    procedure TestFindNextWalksOverloadsThenStops;
    procedure TestCheckFiltersByKind;
    procedure TestCheckResolvesOverloadByArgCount;
    procedure TestCheckReturnsWrongParamsWhenNoOverloadMatches;
    procedure TestParCompWildcardAndVariadic;
    procedure TestParCompNilTolerantAndClassTyped;
    procedure TestFindFirstClassIndexedOverload;
  end;

implementation

procedure TTablesTests.SetUp;
begin
  Items[0].N := 'Alpha'; Items[0].T := RO; Items[0].C := 100; Items[0].P := 'n';
  Items[1].N := 'Beta';  Items[1].T := ME; Items[1].C := 200; Items[1].P := 'nn';
  Items[2].N := 'Beta';  Items[2].T := ME; Items[2].C := 201; Items[2].P := 'n';
  Items[3].N := 'Gamma'; Items[3].T := RW; Items[3].C := 300; Items[3].P := 's';
end;

procedure TTablesTests.TestFindFirstExactMatch;
var Res : TFindRes;
begin
  AssertTrue(Find_First(Res, 'Alpha', Items));
  AssertEquals(100, Res.I^.C);
  AssertEquals(3, Res.C);   // 3 more entries follow index 0 in a 4-element array
end;

procedure TTablesTests.TestFindFirstFindsFirstOfDuplicates;
var Res : TFindRes;
begin
  AssertTrue(Find_First(Res, 'Beta', Items));
  AssertEquals('lands on the FIRST Beta, not the second', 200, Res.I^.C);
  AssertEquals(2, Res.C);
end;

procedure TTablesTests.TestFindFirstNotFound;
var Res : TFindRes;
begin
  AssertFalse(Find_First(Res, 'Zulu', Items));
  AssertTrue(Res.I = nil);
  AssertEquals(0, Res.C);
end;

procedure TTablesTests.TestFindNextWalksOverloadsThenStops;
var Res : TFindRes;
begin
  Find_First(Res, 'Beta', Items);
  AssertTrue('advances to the second Beta overload', Find_Next(Res));
  AssertEquals(201, Res.I^.C);
  AssertFalse('no third Beta -- stops', Find_Next(Res));
end;

procedure TTablesTests.TestCheckFiltersByKind;
var
  Res : TFindRes;
  S   : TStack;
begin
  S := TStack.Create;
  try
    Find_First(Res, 'Alpha', Items);   // kind RO
    AssertEquals('RW not requested -> not found', -1, tables.Check(Res, S, 1, [RW]));
    Find_First(Res, 'Alpha', Items);
    AssertEquals('RO requested, no PA -> matches straight away', 100, tables.Check(Res, S, 1, [RO]));
  finally S.Free; end;
end;

procedure TTablesTests.TestCheckResolvesOverloadByArgCount;
var
  Res : TFindRes;
  S   : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);                  // exactly one numeric argument on the stack
    Find_First(Res, 'Beta', Items);    // first overload wants 'nn' (two numbers)
    AssertEquals('one-arg call must resolve to the ME,''n'' overload', 201,
                 tables.Check(Res, S, 1, [ME, PA]));
  finally S.Free; end;
end;

procedure TTablesTests.TestCheckReturnsWrongParamsWhenNoOverloadMatches;
var
  Res : TFindRes;
  S   : TStack;
begin
  S := TStack.Create;
  try
    S.PushStrVal('not a number');
    Find_First(Res, 'Beta', Items);
    AssertEquals('neither ''nn'' nor ''n'' accepts a string arg', -2,
                 tables.Check(Res, S, 1, [ME, PA]));
  finally S.Free; end;
end;

procedure TTablesTests.TestParCompWildcardAndVariadic;
var S : TStack;
begin
  // '?' is NOT "optional" (confirmed by reading ParComp directly: the '?' branch is
  // just `Continue`, which skips the type check for that position but still requires
  // a value to be present there -- the real UOTbl uses this for e.g. Set's "s?" mask,
  // where the value being set can be any type). A position governed by '?' rejects an
  // absent argument exactly like a concrete type letter would.
  S := TStack.Create;
  try
    S.PushInteger(1);
    AssertFalse('''?'' still requires a value to be present at that position',
                ParComp(S, 1, 'n?'));
    S.PushStrVal('anything');
    AssertTrue('''?'' accepts any type once present', ParComp(S, 1, 'n?'));

    S.Free; S := TStack.Create;
    // 's*' : a string then anything else (variadic tail)
    S.PushStrVal('x');
    AssertTrue('variadic with nothing extra', ParComp(S, 1, 's*'));
    S.PushInteger(1);
    S.PushInteger(2);
    AssertTrue('variadic absorbs extra args', ParComp(S, 1, 's*'));
  finally S.Free; end;
end;

procedure TTablesTests.TestParCompNilTolerantAndClassTyped;
var
  S   : TStack;
  Obj : TAlphaBeta;
begin
  S := TStack.Create;
  Obj := TAlphaBeta.Create;
  try
    S.PushNil;
    AssertTrue('''-'' tolerates nil', ParComp(S, 1, '-'));
    AssertFalse('''n'' does not tolerate nil', ParComp(S, 1, 'n'));

    S.Free; S := TStack.Create;
    S.PushPointer(Obj);
    AssertTrue('(ClassName) matches an instance of that class',
               ParComp(S, 1, '(TAlphaBeta)'));
    AssertFalse('(ClassName) rejects a mismatched class',
               ParComp(S, 1, '(TStringList)'));
  finally
    S.Free;
    Obj.Free;
  end;
end;

procedure TTablesTests.TestFindFirstClassIndexedOverload;
var
  Index : array[0..0] of TIndex;
  Res   : TFindRes;
begin
  // Basic sanity check for the class-indexed overload (unused by uowrap.pas today,
  // but fixed by the same change and worth confirming it still works).
  Index[0].N := 'TAlphaBeta';
  Index[0].C := 0;
  Index[0].T := @Items;
  Index[0].H := High(Items);

  AssertTrue(Find_First(Res, TAlphaBeta, 'Gamma', Index));
  AssertEquals(300, Res.I^.C);
end;

initialization
  RegisterTest(TTablesTests);
end.
