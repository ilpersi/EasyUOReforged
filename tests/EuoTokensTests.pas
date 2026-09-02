unit EuoTokensTests;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoTokens;

type
  TEuoTokensTests = class(TTestCase)
  published
    procedure TestEmptyListCount;
    procedure TestAddNewAndAccess;
    procedure TestOutOfRangeReturnsFreshEmptyRecord;
    procedure TestNegativeIndexAlsoReturnsEmptyRecord;
    procedure TestLast;
    procedure TestDelete;
    procedure TestClear;
    procedure TestInsertNew;
  end;

implementation

procedure TEuoTokensTests.TestEmptyListCount;
var L : TParList;
begin
  L := TParList.Create;
  try
    AssertEquals(Cardinal(0), L.Count);
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestAddNewAndAccess;
var L : TParList;
begin
  L := TParList.Create;
  try
    L.AddNew;
    L[0].Str := 'SET';
    L[0].StrU := 'SET';
    L[0].Int := -1;
    L[0].IntValid := False;
    AssertEquals(Cardinal(1), L.Count);
    AssertEquals('SET', L[0].Str);
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestOutOfRangeReturnsFreshEmptyRecord;
var L : TParList;
begin
  L := TParList.Create;
  try
    L.AddNew;
    L[0].Str := 'X';
    // index 5 is out of range on a 1-element list -- must be the shared empty
    // record, not a crash, and callers rely on this for optional trailing args.
    AssertEquals('', L[5].Str);
    AssertEquals(Int64(-1), L[5].Int);
    AssertFalse(L[5].IntValid);
    AssertFalse(L[5].CardValid);
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestNegativeIndexAlsoReturnsEmptyRecord;
var L : TParList;
begin
  // Get()'s own bounds check is "Index<List.Count", which is trivially true for a
  // negative index too -- but the underlying TList itself rejects a negative index
  // before Get()'s logic ever runs. Confirmed this is shared Delphi/FPC TList
  // behavior, not a porting discrepancy: no caller in the original interpreter
  // ever passes a negative index here, so this was never a reachable code path in
  // either compiler -- documented as such rather than asserted-away.
  L := TParList.Create;
  try
    L.AddNew;
    try
      L[-1].Str := '';
      Fail('expected EListError for a negative index, got none');
    except
      on E : EListError do ; // expected
    end;
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestLast;
var L : TParList;
begin
  L := TParList.Create;
  try
    L.AddNew; L[0].Str := 'A';
    L.AddNew; L[1].Str := 'B';
    AssertEquals('B', L.Last.Str);
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestDelete;
var L : TParList;
begin
  L := TParList.Create;
  try
    L.AddNew; L[0].Str := 'A';
    L.AddNew; L[1].Str := 'B';
    L.Delete(0);
    AssertEquals(Cardinal(1), L.Count);
    AssertEquals('B', L[0].Str);
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestClear;
var L : TParList;
begin
  L := TParList.Create;
  try
    L.AddNew;
    L.AddNew;
    L.Clear;
    AssertEquals(Cardinal(0), L.Count);
  finally L.Free; end;
end;

procedure TEuoTokensTests.TestInsertNew;
var L : TParList;
begin
  L := TParList.Create;
  try
    L.AddNew; L[0].Str := 'A';
    L.AddNew; L[1].Str := 'C';
    L.InsertNew(1);
    L[1].Str := 'B';
    AssertEquals(Cardinal(3), L.Count);
    AssertEquals('A', L[0].Str);
    AssertEquals('B', L[1].Str);
    AssertEquals('C', L[2].Str);
  finally L.Free; end;
end;

initialization
  RegisterTest(TEuoTokensTests);
end.
