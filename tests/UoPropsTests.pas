unit UoPropsTests;

{ Tests for uo\uoprops.pas (scanprops): the port of the client's tooltip formatter on a fake cliloc
  table, GetFormStr's rules, #Property's joining, and PropScan's ask-wait-fall-back logic against a fake
  source with its own clock (no sleeping). The cases come from what the client was seen to do on
  client.exe 7.0.118.46, the beta 7.0.119.0 and a live shard's 7.0.108.0 (docs\property-cache-analysis.md). }

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Generics.Collections, uoprops;

type
  TFakeCliloc = class
  public
    Texts : TDictionary<Integer,RawByteString>;
    Nulls : TList<Integer>;
    Calls : Integer;
    constructor Create;
    destructor Destroy; override;
    function Lookup(ID : Integer; out Text : RawByteString) : Integer;
  end;

  TFakeEntry = record
    State    : TPropEntryState;
    Lines    : TPropLines;
    ArriveAt : QWord;          // >0: becomes fetched with Arrive once the clock reaches it
    Arrive   : TPropLines;
  end;

  TFakePropSource = class(TPropSource)
  public
    Cliloc     : TFakeCliloc;
    Entries    : TDictionary<Cardinal,TFakeEntry>;
    IsSupported: Boolean;
    RequestOK  : Boolean;
    Requested  : TList<Cardinal>;
    Requests   : Integer;
    Fallbacks  : TList<Cardinal>;
    FallbackOK : Boolean;
    Clock      : QWord;
    Pauses     : Integer;
    StopAfter  : Integer;      // Pause answers False after this many (-1: never)
    Coins      : Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Put(ID : Cardinal; St : TPropEntryState; const L : TPropLines; ArriveAt : QWord = 0);
    procedure PutLater(ID : Cardinal; St : TPropEntryState; ArriveAt : QWord; const L : TPropLines);
    function  Supported : Boolean; override;
    function  ReadEntry(ID : Cardinal; out Lines : TPropLines) : TPropEntryState; override;
    function  Request(const IDs : TPropIDs) : Boolean; override;
    function  Fallback(ID : Cardinal; out Text : String) : Boolean; override;
    function  Lookup(ID : Integer; out Text : RawByteString) : Integer; override;
    function  CoinPlural : Boolean; override;
    function  NowMs : QWord; override;
    function  Pause(Ms : Cardinal) : Boolean; override;
  end;

  TUoPropsTests = class(TTestCase)
  private
    Cl  : TFakeCliloc;
    Fmt : TPropFormatter;
    function Line(C : Integer; const A : UnicodeString = '') : TPropLine;
    function Lines(const A : array of TPropLine) : TPropLines;
    function Text(const A : array of TPropLine) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // the formatter
    procedure TestNameIsTheFirstLineFilledAndTitleCased;
    procedure TestPropertiesAreTheOtherLinesJoined;
    procedure TestMissingAndNullClilocsGiveTheClientsErrorTextWithDecimalIds;
    procedure TestEscapedTildeAppends126;
    procedure TestTokenOutOfRangeReplacesTheLine;
    procedure TestHashArgumentsLookUpOnlyTheClilocRange;
    procedure TestNoLookupClilocsKeepHashArgumentsLiteral;
    procedure TestDirectClilocTokens;
    procedure TestLine1076226UsesTheClilocItNames;
    procedure TestLine1062613KeepsItsCasingAndLosesItsColour;
    procedure TestTitleCaseIsAsciiOnlyAfterTheClientsSeparators;
    procedure TestSplitArgsTrailingTab;
    procedure TestWToI;
    procedure TestClientUtf8;
    procedure TestCoinPluralOnTheBetasOnly;
    procedure TestTemplatesAreLookedUpOncePerScan;
    // GetFormStr and #Property
    procedure TestFormStrCutsAt4000AndAtAZeroLowByte;
    procedure TestFormStrBreaksAndTags;
    procedure TestEmptyNameDropsTheProperties;
    procedure TestJoinMatchesPropertyComposition;
    // PropScan
    procedure TestScanFormatsFetchedEntriesWithoutRequests;
    procedure TestScanWaitsForAnnouncedEntries;
    procedure TestScanStopsAfterAnIdleSecond;
    procedure TestScanWaitsLessWhenOnlyMissingEntriesAreLeft;
    procedure TestScanKeepsWaitingWhileAnswersArriveUpToTheCap;
    procedure TestScanAnnouncedLeftoversUseTheirOldLines;
    procedure TestScanMissingEntriesAreRequestedThenFallBack;
    procedure TestScanWithoutRequestFallsBackAtOnce;
    procedure TestScanStopsWhenTheScriptStops;
    procedure TestScanUnsupportedSourceUsesTheFallbackForAll;
    procedure TestScanReadsEachIdOnceAndClearsTheStore;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TFakeCliloc.Create;
begin
  inherited Create;
  Texts:=TDictionary<Integer,RawByteString>.Create;
  Nulls:=TList<Integer>.Create;
end;

destructor TFakeCliloc.Destroy;
begin
  Texts.Free;
  Nulls.Free;
  inherited Destroy;
end;

function TFakeCliloc.Lookup(ID : Integer; out Text : RawByteString) : Integer;
begin
  Inc(Calls);
  Text:='';
  if Nulls.Contains(ID) then Exit(1);
  if Texts.TryGetValue(ID,Text) then Exit(2);
  Result:=0;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TFakePropSource.Create;
begin
  inherited Create;
  Cliloc:=TFakeCliloc.Create;
  Entries:=TDictionary<Cardinal,TFakeEntry>.Create;
  Requested:=TList<Cardinal>.Create;
  Fallbacks:=TList<Cardinal>.Create;
  IsSupported:=True;
  RequestOK:=True;
  FallbackOK:=True;
  StopAfter:=-1;
  Clock:=1000;
end;

destructor TFakePropSource.Destroy;
begin
  Cliloc.Free;
  Entries.Free;
  Requested.Free;
  Fallbacks.Free;
  inherited Destroy;
end;

procedure TFakePropSource.Put(ID : Cardinal; St : TPropEntryState; const L : TPropLines; ArriveAt : QWord);
var
  E : TFakeEntry;
begin
  E.State:=St;
  E.Lines:=L;
  E.ArriveAt:=ArriveAt;
  SetLength(E.Arrive,0);
  Entries.AddOrSetValue(ID,E);
end;

procedure TFakePropSource.PutLater(ID : Cardinal; St : TPropEntryState; ArriveAt : QWord; const L : TPropLines);
var
  E : TFakeEntry;
begin
  E.State:=St;
  SetLength(E.Lines,0);
  E.ArriveAt:=ArriveAt;
  E.Arrive:=L;
  Entries.AddOrSetValue(ID,E);
end;

function TFakePropSource.Supported : Boolean;
begin
  Result:=IsSupported;
end;

function TFakePropSource.ReadEntry(ID : Cardinal; out Lines : TPropLines) : TPropEntryState;
var
  E : TFakeEntry;
begin
  SetLength(Lines,0);
  if not Entries.TryGetValue(ID,E) then Exit(pesNone);
  if (E.ArriveAt>0) and (Clock>=E.ArriveAt) then
  begin
    Lines:=E.Arrive;
    Exit(pesFetched);
  end;
  Lines:=E.Lines;
  Result:=E.State;
end;

function TFakePropSource.Request(const IDs : TPropIDs) : Boolean;
var
  I : Integer;
begin
  Inc(Requests);
  for I:=0 to High(IDs) do Requested.Add(IDs[I]);
  Result:=RequestOK;
end;

function TFakePropSource.Fallback(ID : Cardinal; out Text : String) : Boolean;
begin
  Fallbacks.Add(ID);
  Text:='Fallback '+IntToHex(ID,8)+'$';
  Result:=FallbackOK;
end;

function TFakePropSource.Lookup(ID : Integer; out Text : RawByteString) : Integer;
begin
  Result:=Cliloc.Lookup(ID,Text);
end;

function TFakePropSource.CoinPlural : Boolean;
begin
  Result:=Coins;
end;

function TFakePropSource.NowMs : QWord;
begin
  Result:=Clock;
end;

function TFakePropSource.Pause(Ms : Cardinal) : Boolean;
begin
  Inc(Pauses);
  Inc(Clock,Ms);
  Result:=(StopAfter<0) or (Pauses<=StopAfter);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoPropsTests.SetUp;
begin
  Cl:=TFakeCliloc.Create;
  Cl.Texts.Add(1050045,'~1_PREFIX~~2_NAME~~3_SUFFIX~');
  Cl.Texts.Add(1000006,'~1_PREFIX~~2_NAME~~3_SUFFIX~');
  Cl.Texts.Add(1020000,'ewer');
  Cl.Texts.Add(1060636,'exceptional');
  Cl.Texts.Add(1072789,'weight: ~1_WEIGHT~ stones');
  Cl.Texts.Add(1061837,'durability ~1_val~ / ~2_val~');
  Cl.Texts.Add(1042971,'~1_NOTHING~');
  Cl.Texts.Add(1062613,'~1_NAME~');
  Cl.Texts.Add(1060450,'mage weapon -~2_val~ skill');
  Cl.Texts.Add(1050039,'~1_NUMBER~ ~2_ITEMNAME~');
  Cl.Texts.Add(1020654,'gold coin');
  Cl.Texts.Add(1020655,'gold coins (2-5)');
  Cl.Texts.Add(1020656,'gold coins (6+)');
  Cl.Texts.Add(1041473,'~1_VALUE~');      // $FE441: one of the no-lookup ids
  Cl.Texts.Add(1000001,'a ~#1020000~ of ~1_X~');
  Cl.Texts.Add(1000002,'a\~b');
  Cl.Nulls.Add(1000004);
  Fmt:=TPropFormatter.Create(Cl.Lookup,False);
end;

procedure TUoPropsTests.TearDown;
begin
  Fmt.Free;
  Cl.Free;
end;

function TUoPropsTests.Line(C : Integer; const A : UnicodeString) : TPropLine;
begin
  Result.Cl:=C;
  Result.Args:=A;
end;

function TUoPropsTests.Lines(const A : array of TPropLine) : TPropLines;
var
  I : Integer;
begin
  SetLength(Result,Length(A));
  for I:=0 to High(A) do Result[I]:=A[I];
end;

function TUoPropsTests.Text(const A : array of TPropLine) : String;
begin
  Result:=Fmt.PropertyText(Lines(A));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoPropsTests.TestNameIsTheFirstLineFilledAndTitleCased;
begin
  AssertEquals('Ewer$', Text([Line(1000006,#9'#1020000'#9#9)]));
  // 1050045 ($1005BD) is one of the clilocs whose '#' arguments the client keeps literal
  AssertEquals('#1020000$', Text([Line(1050045,#9'#1020000'#9#9)]));
  AssertEquals('Ewer$', Text([Line(1020000)]));
end;

procedure TUoPropsTests.TestPropertiesAreTheOtherLinesJoined;
begin
  AssertEquals('Ewer$Exceptional$Weight: 6 Stones$Durability 20 / 20$',
    Text([Line(1020000),Line(1060636),Line(1072789,'6'),Line(1061837,'20'#9'20')]));
end;

procedure TUoPropsTests.TestMissingAndNullClilocsGiveTheClientsErrorTextWithDecimalIds;
begin
  AssertEquals('Ewer$Error (MegaCliloc) : StringId Not Found : 1164872$',
    Text([Line(1020000),Line(1164872)]));
  AssertEquals('Ewer$Error (MegaCliloc) : Null String : 1000004$',
    Text([Line(1020000),Line(1000004)]));
end;

procedure TUoPropsTests.TestEscapedTildeAppends126;
begin
  AssertEquals('Ewer$A\126b$', Text([Line(1020000),Line(1000002,'x')]));
  AssertEquals('without arguments the template is not filled', 'Ewer$A\~b$', Text([Line(1020000),Line(1000002)]));
end;

procedure TUoPropsTests.TestTokenOutOfRangeReplacesTheLine;
begin
  AssertEquals('Ewer$Error (TID): Token Out Of Range : 2 : 1061837$',
    Text([Line(1020000),Line(1061837,'20')]));
  AssertEquals('Ewer$Error (TID): Provided Token Out Of Range : 5 : 1072789$',
    Text([Line(1020000),Line(1072789,'#5')]));
end;

procedure TUoPropsTests.TestHashArgumentsLookUpOnlyTheClilocRange;
begin
  AssertEquals('Ewer$Weight: Ewer Stones$', Text([Line(1020000),Line(1072789,'#1020000')]));
  AssertEquals('Ewer$Error (TID): Provided Token Out Of Range : 2000000 : 1072789$',
    Text([Line(1020000),Line(1072789,'#2000000')]));
end;

procedure TUoPropsTests.TestNoLookupClilocsKeepHashArgumentsLiteral;
begin
  AssertTrue(PropNoLookup($FE441));
  AssertFalse(PropNoLookup(1072789));
  AssertEquals('Ewer$#1020000$', Text([Line(1020000),Line(1041473,'#1020000')]));
end;

procedure TUoPropsTests.TestDirectClilocTokens;
begin
  AssertEquals('Ewer$A Ewer Of Gold$', Text([Line(1020000),Line(1000001,'gold')]));
end;

procedure TUoPropsTests.TestLine1076226UsesTheClilocItNames;
begin
  AssertEquals('Ewer$Mage Weapon -25 Skill$', Text([Line(1020000),Line(1076226,'1060450'#9'25')]));
end;

procedure TUoPropsTests.TestLine1062613KeepsItsCasingAndLosesItsColour;
begin
  AssertEquals('Ewer$crafted by bob$', Text([Line(1020000),Line(1062613,'crafted by bob')]));
end;

procedure TUoPropsTests.TestTitleCaseIsAsciiOnlyAfterTheClientsSeparators;
var
  W : UnicodeString;
begin
  W:=PropTitleCase(UnicodeString('x[y>z-w a'#10'b')+WideChar($E8)+UnicodeString('c (d'));
  AssertTrue(W=UnicodeString('X[Y>Z-W A'#10'B')+WideChar($E8)+UnicodeString('c (d'));
  W:=PropTitleCase(WideChar($E8)+UnicodeString('a'));
  AssertTrue('non-ASCII stays', W=WideChar($E8)+UnicodeString('a'));
end;

procedure TUoPropsTests.TestSplitArgsTrailingTab;
var
  A : TPropArgs;
begin
  PropSplitArgs('a'#9'b'#9,A);
  AssertEquals(2, Length(A));
  PropSplitArgs('',A);
  AssertEquals('an empty text is one empty argument', 1, Length(A));
  PropSplitArgs(#9'x',A);
  AssertEquals(2, Length(A));
  AssertTrue(A[0]='');
end;

procedure TUoPropsTests.TestWToI;
begin
  AssertEquals(1020000, PropWToI('#1020000',2));
  AssertEquals(-12, PropWToI('-12x',1));
  AssertEquals(7, PropWToI('+7',1));
  AssertEquals(0, PropWToI('abc',1));
end;

procedure TUoPropsTests.TestClientUtf8;
var
  W : UnicodeString;
begin
  W:=PropClientUtf8('a'#$C3#$A8#$E2#$80#$99'b');
  AssertTrue(W=UnicodeString('a')+WideChar($E8)+WideChar($2019)+UnicodeString('b'));
end;

procedure TUoPropsTests.TestCoinPluralOnTheBetasOnly;
begin
  AssertTrue(PropCoinPlural(1050039,'3'#9'#1020654')='3'#9'#1020655');
  AssertTrue(PropCoinPlural(1050039,'7'#9'#1020654')='7'#9'#1020656');
  AssertTrue(PropCoinPlural(1050039,'1'#9'#1020654')='1'#9'#1020654');
  AssertTrue('not a coin', PropCoinPlural(1050039,'3'#9'#1020000')='3'#9'#1020000');
  AssertTrue('not 1050039', PropCoinPlural(1050045,'3'#9'#1020654')='3'#9'#1020654');
  AssertEquals('fixed-base: no step', '3 Gold Coin$', Text([Line(1050039,'3'#9'#1020654')]));
  Fmt.CoinPlural:=True;
  AssertEquals('beta', '3 Gold Coins (2-5)$', Text([Line(1050039,'3'#9'#1020654')]));
end;

procedure TUoPropsTests.TestTemplatesAreLookedUpOncePerScan;
var
  N : Integer;
begin
  Text([Line(1020000),Line(1060636)]);
  N:=Cl.Calls;
  Text([Line(1020000),Line(1060636)]);
  AssertEquals('cached', N, Cl.Calls);
  Fmt.ClearTemplates;
  Text([Line(1020000)]);
  AssertEquals('looked up again', N+1, Cl.Calls);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoPropsTests.TestFormStrCutsAt4000AndAtAZeroLowByte;
var
  W : UnicodeString;
  S : String;
begin
  W:=StringOfChar(WideChar('a'),4100);
  S:=PropFormStr(W);
  AssertEquals('GetFormStr reads 4000 characters', 4000, Length(S));
  AssertEquals('ab', PropFormStr(UnicodeString('ab')+WideChar($0100)+UnicodeString('cd')));
  AssertEquals('a low byte below 32 becomes a space', 'a ', PropFormStr(UnicodeString('a')+WideChar($2019)));
  AssertEquals('one byte per letter', 'a'#$E8, PropFormStr(UnicodeString('a')+WideChar($E8)));
end;

procedure TUoPropsTests.TestFormStrBreaksAndTags;
begin
  AssertEquals('a b'#13#10'c', PropFormStr('a'#9'b<BR>c'));
  AssertEquals('only <BR> breaks', 'ac', PropFormStr('a<br>c'));
  AssertEquals('tags removed', 'Gold', PropFormStr('<BASEFONT COLOR=#FFCC33>Gold<BASEFONT COLOR=#FFFFFF>'));
  AssertEquals('a > before the first < stops the removal', 'a>b<c', PropFormStr('a>b<c'));
end;

procedure TUoPropsTests.TestEmptyNameDropsTheProperties;
begin
  Cl.Texts.Add(1000005,'');
  AssertEquals('$', Text([Line(1000005),Line(1060636)]));
end;

procedure TUoPropsTests.TestJoinMatchesPropertyComposition;
begin
  AssertEquals('n$', PropJoin('n',''));
  AssertEquals('n$a$b$', PropJoin('n','a'#13#10'b'));
  AssertEquals('$', PropJoin('',''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoPropsTests.TestScanFormatsFetchedEntriesWithoutRequests;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.Cliloc.Texts.Add(1020000,'ewer');
    Src.Put($40000001,pesFetched,Lines([Line(1020000)]));
    PropScan(Src,[$40000001],Store);
    AssertEquals('Ewer$', Store[$40000001]);
    AssertEquals('no request', 0, Src.Requests);
    AssertEquals('no wait', 0, Src.Pauses);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanWaitsForAnnouncedEntries;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.Cliloc.Texts.Add(1020000,'ewer');
    Src.Put($40000001,pesFetched,Lines([Line(1020000)]));
    Src.PutLater($40000002,pesAnnounced,Src.Clock+120,Lines([Line(1020000),Line(1020000)]));
    PropScan(Src,[$40000001,$40000002],Store);
    AssertEquals('one request', 1, Src.Requests);
    AssertEquals('...for the announced one only', 1, Src.Requested.Count);
    AssertTrue(Src.Requested[0]=$40000002);
    AssertEquals('Ewer$Ewer$', Store[$40000002]);
    AssertEquals('three polls of 50 ms', 3, Src.Pauses);
    AssertEquals('no fallback', 0, Src.Fallbacks.Count);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanStopsAfterAnIdleSecond;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.Put($40000002,pesAnnounced,nil);
    PropScan(Src,[$40000002],Store);
    AssertEquals('$', Store[$40000002]);
    AssertEquals('1 s of 50 ms polls', PROP_IDLE_MS div PROP_POLL_MS, Src.Pauses);
  finally
    Store.Free;
    Src.Free;
  end;
end;

// The shard never answers for an object without properties: with only such items left, half a second.
procedure TUoPropsTests.TestScanWaitsLessWhenOnlyMissingEntriesAreLeft;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    PropScan(Src,[$40000004],Store);
    AssertEquals('half a second of 50 ms polls', PROP_IDLE_NONE_MS div PROP_POLL_MS, Src.Pauses);
    AssertEquals('then the fallback', 1, Src.Fallbacks.Count);
    Src.Pauses:=0;
    Src.Put($40000002,pesAnnounced,nil);
    PropScan(Src,[$40000002,$40000004],Store);
    AssertEquals('an announced item keeps the full second', PROP_IDLE_MS div PROP_POLL_MS, Src.Pauses);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanKeepsWaitingWhileAnswersArriveUpToTheCap;
var
  Src   : TFakePropSource;
  Store : TPropStore;
  IDs   : TPropIDs;
  I     : Integer;
  T0    : QWord;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.Cliloc.Texts.Add(1020000,'ewer');
    T0:=Src.Clock;
    SetLength(IDs,400);
    for I:=0 to High(IDs) do
    begin
      IDs[I]:=$40001000+Cardinal(I);
      // one answer every 100 ms: never a second without one, so only the cap ends the wait
      Src.PutLater(IDs[I],pesAnnounced,T0+100*QWord(I+1),Lines([Line(1020000)]));
    end;
    PropScan(Src,IDs,Store);
    AssertEquals('the cap', T0+PROP_CAP_MS, Src.Clock);
    AssertEquals('answers within the cap', 'Ewer$', Store[IDs[(PROP_CAP_MS div 100)-2]]);
    AssertEquals('after the cap', '$', Store[IDs[High(IDs)]]);
    AssertEquals('everything stored', 400, Store.Count);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanAnnouncedLeftoversUseTheirOldLines;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.Cliloc.Texts.Add(1020000,'ewer');
    Src.Put($40000002,pesAnnounced,Lines([Line(1020000)]));      // the betas keep the old tooltip
    PropScan(Src,[$40000002],Store);
    AssertEquals('Ewer$', Store[$40000002]);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanMissingEntriesAreRequestedThenFallBack;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.Cliloc.Texts.Add(1020000,'ewer');
    Src.PutLater($40000003,pesNone,Src.Clock+50,Lines([Line(1020000)]));   // the server answers
    PropScan(Src,[$40000003,$40000004],Store);                              // ...and this one not
    AssertEquals('both requested', 2, Src.Requested.Count);
    AssertEquals('Ewer$', Store[$40000003]);
    AssertEquals('fallback for the one never answered', 1, Src.Fallbacks.Count);
    AssertTrue(Src.Fallbacks[0]=$40000004);
    AssertEquals('Fallback 40000004$', Store[$40000004]);
    Src.FallbackOK:=False;
    PropScan(Src,[$40000004],Store);
    AssertEquals('no fallback: $', '$', Store[$40000004]);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanWithoutRequestFallsBackAtOnce;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.RequestOK:=False;
    Src.Put($40000002,pesAnnounced,nil);
    PropScan(Src,[$40000002,$40000004],Store);
    AssertEquals('no wait', 0, Src.Pauses);
    AssertEquals('$', Store[$40000002]);
    AssertEquals('Fallback 40000004$', Store[$40000004]);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanStopsWhenTheScriptStops;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.StopAfter:=2;
    Src.Put($40000002,pesAnnounced,nil);
    PropScan(Src,[$40000002],Store);
    AssertEquals('stopped at the third pause', 3, Src.Pauses);
    AssertEquals('$', Store[$40000002]);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanUnsupportedSourceUsesTheFallbackForAll;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Src.IsSupported:=False;
    Src.Put($40000001,pesFetched,Lines([Line(1020000)]));
    PropScan(Src,[$40000001,$40000002],Store);
    AssertEquals(2, Src.Fallbacks.Count);
    AssertEquals('no request', 0, Src.Requests);
    AssertEquals('Fallback 40000001$', Store[$40000001]);
  finally
    Store.Free;
    Src.Free;
  end;
end;

procedure TUoPropsTests.TestScanReadsEachIdOnceAndClearsTheStore;
var
  Src   : TFakePropSource;
  Store : TPropStore;
begin
  Src:=TFakePropSource.Create;
  Store:=TPropStore.Create;
  try
    Store.Add($12345678,'old$');
    Src.Put($40000002,pesAnnounced,nil);
    PropScan(Src,[$40000002,$40000002],Store);
    AssertEquals('requested once', 1, Src.Requested.Count);
    AssertFalse('the previous scan is gone', Store.ContainsKey($12345678));
    AssertEquals(1, Store.Count);
    PropScan(Src,[],Store);
    AssertEquals('an empty finditem empties it', 0, Store.Count);
  finally
    Store.Free;
    Src.Free;
  end;
end;

initialization
  RegisterTest(TUoPropsTests);
end.
