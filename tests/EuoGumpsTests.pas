unit EuoGumpsTests;

{ ScanGumps without a client (port addition): how a gump's values are shown (EuoGumps.GumpFieldText),
  the filter words (uocommands.ParseGumpFilter), and uocommands.GumpLiteral, which must read an EUO
  literal exactly as EuoConversion.Sys26ToCard does (uo.dll shares it; the parser package is above
  the engine, so the engine has its own copy). Reading a fake client is in CstDbModernBuildTests. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uocommands, EuoGumps, EuoConversion;

type
  TEuoGumpsTests = class(TTestCase)
  private
    function Backpack : TGumpInfo;
    function ServerGump : TGumpInfo;
    function Text(const G : TGumpInfo; F : TGumpField) : String;
  published
    procedure TestIDsArtAndKindAreEuoLiterals;
    procedure TestPositionAndSizeArePlainNumbers;
    procedure TestNameShowsSpacesAsUnderscores;
    procedure TestMinimizedIsTrueOrFalse;
    procedure TestAbsentValuesReadNA;
    procedure TestNoSelectionReadsNAEverywhere;
    procedure TestGumpLiteralAgreesWithSys26ToCard;
    procedure TestGumpLiteralRejectsWhatSys26ToCardRejects;
    procedure TestFilterByType;
    procedure TestFilterByArtWithSeveralValues;
    procedure TestFilterBothWordsAndOtherWords;
    procedure TestFilterWordWithoutAValidValueStillFilters;
    procedure TestNoFilter;
  end;

implementation

function TEuoGumpsTests.Backpack : TGumpInfo;
begin
  Result := Default(TGumpInfo);
  Result.Name := 'container gump';
  Result.Kind := $E694;
  Result.X := 100;
  Result.Y := -20;
  Result.W := 230;
  Result.H := 204;
  Result.ObjID := $40000003;
  Result.ObjValid := True;
  Result.Art := $3C;
  Result.ArtValid := True;
  Result.MinValid := True;
end;

function TEuoGumpsTests.ServerGump : TGumpInfo;
begin
  Result := Default(TGumpInfo);
  Result.Name := 'generic gump';
  Result.Kind := $FD6C;
  Result.MinValid := True;
  Result.IsGeneric := True;
  Result.Serial := $E;
  Result.TypeID := $9E26D92D;
  Result.ServerValid := True;
end;

function TEuoGumpsTests.Text(const G : TGumpInfo; F : TGumpField) : String;
begin
  if not GumpFieldText(G, True, F, Result) then Result := 'N/A';
end;

procedure TEuoGumpsTests.TestIDsArtAndKindAreEuoLiterals;
begin
  AssertEquals('backpack art $3C', 'YE', Text(Backpack, gfArt));
  AssertEquals('type ID $9E26D92D', 'JHEIIPI', Text(ServerGump, gfTypeID));
  AssertEquals('object', CardToSys26($40000003), Text(Backpack, gfObjID));
  AssertEquals('serial', CardToSys26($E), Text(ServerGump, gfSerial));
  AssertEquals('kind', CardToSys26($E694), Text(Backpack, gfKind));
end;

procedure TEuoGumpsTests.TestPositionAndSizeArePlainNumbers;
begin
  AssertEquals('100', Text(Backpack, gfPosX));
  AssertEquals('-20', Text(Backpack, gfPosY));
  AssertEquals('230', Text(Backpack, gfSizeX));
  AssertEquals('204', Text(Backpack, gfSizeY));
end;

procedure TEuoGumpsTests.TestNameShowsSpacesAsUnderscores;
begin
  AssertEquals('container_gump', Text(Backpack, gfName));
  AssertEquals('generic_gump', Text(ServerGump, gfName));
end;

procedure TEuoGumpsTests.TestMinimizedIsTrueOrFalse;
var
  G : TGumpInfo;
begin
  AssertEquals('#false', '0', Text(Backpack, gfMin));
  G := Backpack;
  G.Minimized := True;
  AssertEquals('#true', '-1', Text(G, gfMin));
end;

procedure TEuoGumpsTests.TestAbsentValuesReadNA;
var
  G : TGumpInfo;
begin
  AssertEquals('no serial on a container', 'N/A', Text(Backpack, gfSerial));
  AssertEquals('no type ID on a container', 'N/A', Text(Backpack, gfTypeID));
  AssertEquals('no art on a server gump', 'N/A', Text(ServerGump, gfArt));
  AssertEquals('no linked object', 'N/A', Text(ServerGump, gfObjID));
  G := Backpack;
  G.MinValid := False;
  AssertEquals('minimized offset unknown on this build', 'N/A', Text(G, gfMin));
  G := ServerGump;
  G.ServerValid := False;
  AssertEquals('serial offset unknown on this build', 'N/A', Text(G, gfSerial));
  G.Name := '';
  AssertEquals('no name', 'N/A', Text(G, gfName));
end;

procedure TEuoGumpsTests.TestNoSelectionReadsNAEverywhere;
var
  F : TGumpField;
  S : String;
begin
  for F := Low(TGumpField) to High(TGumpField) do
  begin
    AssertFalse('field ' + IntToStr(Ord(F)), GumpFieldText(Backpack, False, F, S));
    AssertEquals('', S);
  end;
end;

procedure TEuoGumpsTests.TestGumpLiteralAgreesWithSys26ToCard;
const
  Samples : array[0..9] of Cardinal = (0, 1, 7, $3C, $4EC, $243A, $40000003, $9E26D92D, $7FFFFFFF, $FFFFFFFF);
var
  I    : Integer;
  V, W : Cardinal;
  C    : Boolean;
  S    : String;
begin
  for I := 0 to High(Samples) do
  begin
    S := CardToSys26(Samples[I]);
    AssertTrue(S, GumpLiteral(S, V));
    C := False;
    W := Sys26ToCard(S, C);
    AssertTrue(S, C);
    AssertEquals(S, W, V);
    AssertEquals(S, Samples[I], V);
  end;
  AssertTrue(GumpLiteral(' jheiipi ', V));
  AssertEquals('sloppy, as Sys26ToCard', $9E26D92D, V);
end;

procedure TEuoGumpsTests.TestGumpLiteralRejectsWhatSys26ToCardRejects;
const
  Bad : array[0..4] of String = ('', 'Y1', 'N/A', '12', 'ZZZZZZZZ');
var
  I : Integer;
  V : Cardinal;
  C : Boolean;
begin
  for I := 0 to High(Bad) do
  begin
    C := True;
    Sys26ToCard(Bad[I], C);
    AssertEquals(Bad[I], C, GumpLiteral(Bad[I], V));
    AssertFalse(Bad[I], GumpLiteral(Bad[I], V));
  end;
end;

procedure TEuoGumpsTests.TestFilterByType;
var
  T, A   : TGumpIDs;
  BT, BA : Boolean;
begin
  ParseGumpFilter('T_JHEIIPI', T, A, BT, BA);
  AssertTrue(BT);
  AssertFalse(BA);
  AssertEquals(1, Length(T));
  AssertEquals($9E26D92D, T[0]);
  AssertEquals(0, Length(A));
end;

procedure TEuoGumpsTests.TestFilterByArtWithSeveralValues;
var
  T, A   : TGumpIDs;
  BT, BA : Boolean;
begin
  ParseGumpFilter('a_YE_' + CardToSys26($4EC), T, A, BT, BA);
  AssertFalse(BT);
  AssertTrue(BA);
  AssertEquals(2, Length(A));
  AssertEquals($3C, A[0]);
  AssertEquals($4EC, A[1]);
end;

procedure TEuoGumpsTests.TestFilterBothWordsAndOtherWords;
var
  T, A   : TGumpIDs;
  BT, BA : Boolean;
begin
  ParseGumpFilter('  C_YE  T_JHEIIPI   A_YE x ', T, A, BT, BA);
  AssertTrue(BT);
  AssertTrue(BA);
  AssertEquals(1, Length(T));
  AssertEquals(1, Length(A));
end;

procedure TEuoGumpsTests.TestFilterWordWithoutAValidValueStillFilters;
var
  T, A   : TGumpIDs;
  BT, BA : Boolean;
begin
  ParseGumpFilter('T_ A_12_N', T, A, BT, BA);
  AssertTrue('T_ alone', BT);
  AssertTrue('A_ with only a bad value and one good', BA);
  AssertEquals(0, Length(T));
  AssertEquals(1, Length(A));
end;

procedure TEuoGumpsTests.TestNoFilter;
var
  T, A   : TGumpIDs;
  BT, BA : Boolean;
begin
  ParseGumpFilter('', T, A, BT, BA);
  AssertFalse(BT);
  AssertFalse(BA);
  ParseGumpFilter('YE 12 _A', T, A, BT, BA);
  AssertFalse(BT);
  AssertFalse(BA);
end;

initialization
  RegisterTest(TEuoGumpsTests);
end.
