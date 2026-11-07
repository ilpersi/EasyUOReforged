unit EuoJournalSearchTests;

{
  EuoJournalSearch: which journal lines FINDJOURNAL looks at and whether one matches. The lines come
  from a list here instead of a client. Index 0 is the newest line, as in TUOCmd.JournalEntry, and the
  fixture numbers lines so that the newest is #JIndex.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoJournalSearch;

type
  TEuoJournalSearchTests = class(TTestCase)
  private
    Lines : TStringList;
    function  Entry(Index : Cardinal; out Txt : String; out Col : Cardinal) : Boolean;
    procedure Say(const Line : String; Col : Cardinal = 0);
    function  Find(Since : Int64; JIndex : Cardinal; const Texts : array of String) : Cardinal;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWindowSinceTheNewestLineIsEmpty;
    procedure TestWindowCountsTheNewLines;
    procedure TestWindowCountsBackUpTo500;
    procedure TestWindowIsCappedAt100;
    procedure TestWindowAfterANumberingRestartTakesAllHeld;
    procedure TestWindowZeroAndNegativeAreEmpty;
    procedure TestWindowLeavesOutHiddenLines;
    procedure TestWindowAllHiddenIsEmpty;
    procedure TestAskingForMoreThanIsHeld;
    procedure TestOldestMatchFirst;
    procedure TestTextOrderDoesNotMatter;
    procedure TestSecondTextOnAnOlderLineWins;
    procedure TestNothingMatches;
    procedure TestLinesBeforeTheBookmarkAreNotSearched;
    procedure TestCaseIsIgnored;
    procedure TestSpacesReadAsUnderscores;
    procedure TestARealSpaceNeverMatches;
    procedure TestEmptyTextNeverMatches;
    procedure TestNoTextsMatchNothing;
    procedure TestWalkingFindsEachMatchOnce;
    procedure TestHiddenLinesAreNotFound;
    procedure TestColorAlone;
    procedure TestTextAndColorMustHoldOnTheSameLine;
    procedure TestRightTextWrongColor;
    procedure TestColorZeroIsARealValue;
    procedure TestUnreadableColorMatchesNothing;
    procedure TestStarTextMatchesAnyLine;
    procedure TestStarAmongOtherTextsMatchesAnyLine;
    procedure TestStarMatchesAHeldEmptyLine;
    procedure TestStarNeverMatchesPastTheLastLine;
    procedure TestStarInsideATextIsLiteral;
  end;

implementation

const
  ANY = True;
  ONE = False;

procedure TEuoJournalSearchTests.SetUp;
begin
  Lines:=TStringList.Create;
end;

procedure TEuoJournalSearchTests.TearDown;
begin
  Lines.Free;
end;

function TEuoJournalSearchTests.Entry(Index : Cardinal; out Txt : String; out Col : Cardinal) : Boolean;
begin
  Txt:='';
  Col:=0;
  Result:=Index<Cardinal(Lines.Count);
  if not Result then Exit;
  Txt:=Lines[Index];
  Col:=PtrUInt(Lines.Objects[Index]);
end;

// The newest line goes first, as ScanJournal fills its list.
procedure TEuoJournalSearchTests.Say(const Line : String; Col : Cardinal);
begin
  Lines.InsertObject(0,Line,TObject(PtrUInt(Col)));
end;

function TEuoJournalSearchTests.Find(Since : Int64; JIndex : Cardinal; const Texts : array of String) : Cardinal;
begin
  Result:=JournalSearch(Since,JIndex,0,Entry,ANY,0,Texts);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJournalSearchTests.TestWindowSinceTheNewestLineIsEmpty;
begin
  AssertEquals(0,JournalWindow(1000,1000,0));
end;

procedure TEuoJournalSearchTests.TestWindowCountsTheNewLines;
begin
  AssertEquals(3,JournalWindow(1000,1003,0));
end;

procedure TEuoJournalSearchTests.TestWindowCountsBackUpTo500;
begin
  AssertEquals(1,JournalWindow(1,1003,0));
  AssertEquals(100,JournalWindow(100,1003,0));
  AssertEquals('500 still counts back, capped',100,JournalWindow(500,1003,0));
  AssertEquals('501 is a running number',100,JournalWindow(501,1003,0));
  AssertEquals('501 is a running number',2,JournalWindow(501,503,0));
end;

procedure TEuoJournalSearchTests.TestWindowIsCappedAt100;
begin
  AssertEquals(100,JournalWindow(1000,1500,0));
  AssertEquals(100,JournalWindow(1000,1100,0));
  AssertEquals(99,JournalWindow(1000,1099,0));
end;

procedure TEuoJournalSearchTests.TestWindowAfterANumberingRestartTakesAllHeld;
begin
  AssertEquals(100,JournalWindow(1300,1000,0));
end;

procedure TEuoJournalSearchTests.TestWindowZeroAndNegativeAreEmpty;
begin
  AssertEquals(0,JournalWindow(0,1003,0));
  AssertEquals(0,JournalWindow(-5,1003,0));
end;

procedure TEuoJournalSearchTests.TestWindowLeavesOutHiddenLines;
begin
  AssertEquals(2,JournalWindow(1000,1003,1001));
  AssertEquals(3,JournalWindow(1000,1003,1000));
  AssertEquals('count-back too',2,JournalWindow(100,1003,1001));
end;

procedure TEuoJournalSearchTests.TestWindowAllHiddenIsEmpty;
begin
  AssertEquals(0,JournalWindow(1000,1003,1003));
  AssertEquals('as SCANJOURNAL, after a restart',0,JournalWindow(1300,1000,1300));
end;

procedure TEuoJournalSearchTests.TestAskingForMoreThanIsHeld;
begin
  Say('fizzles');
  AssertEquals(1000,Find(100,1000,['fizzles']));
  AssertEquals('a restart with few lines held',1000,Find(1300,1000,['fizzles']));
  AssertEquals(0,Find(100,1000,['other']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJournalSearchTests.TestOldestMatchFirst;
begin
  Say('fizzles one');   // 1001
  Say('other');         // 1002
  Say('fizzles two');   // 1003
  AssertEquals(1001,Find(1000,1003,['fizzles']));
end;

procedure TEuoJournalSearchTests.TestTextOrderDoesNotMatter;
begin
  Say('You must wait');       // 1001
  Say('The spell fizzles');   // 1002
  AssertEquals(1001,Find(1000,1002,['fizzles','you_must_wait']));
  AssertEquals(1001,Find(1000,1002,['you_must_wait','fizzles']));
end;

procedure TEuoJournalSearchTests.TestSecondTextOnAnOlderLineWins;
begin
  Say('beta');    // 1001
  Say('alpha');   // 1002
  AssertEquals(1001,Find(1000,1002,['alpha','beta']));
end;

procedure TEuoJournalSearchTests.TestNothingMatches;
begin
  Say('other');
  AssertEquals(0,Find(999,1000,['fizzles','you_must_wait']));
end;

procedure TEuoJournalSearchTests.TestLinesBeforeTheBookmarkAreNotSearched;
begin
  Say('fizzles');   // 1001
  Say('other');     // 1002
  AssertEquals(0,Find(1001,1002,['fizzles']));
  AssertEquals(1001,Find(1000,1002,['fizzles']));
end;

procedure TEuoJournalSearchTests.TestCaseIsIgnored;
begin
  Say('The Spell Fizzles');
  AssertEquals(1000,Find(999,1000,['FIZZLES']));
  AssertEquals(1000,Find(999,1000,['fizzles']));
end;

procedure TEuoJournalSearchTests.TestSpacesReadAsUnderscores;
begin
  Say('You must wait');
  AssertEquals(1000,Find(999,1000,['you_must_wait']));
end;

procedure TEuoJournalSearchTests.TestARealSpaceNeverMatches;
begin
  Say('You must wait');
  AssertEquals(0,Find(999,1000,['you must']));
end;

procedure TEuoJournalSearchTests.TestEmptyTextNeverMatches;
begin
  Say('anything');
  AssertEquals(0,Find(999,1000,['']));
end;

procedure TEuoJournalSearchTests.TestNoTextsMatchNothing;
begin
  Say('anything');
  AssertEquals(0,JournalSearch(999,1000,0,Entry,ANY,0,[]));
end;

procedure TEuoJournalSearchTests.TestWalkingFindsEachMatchOnce;
var
  Mark : Int64;
  Hit  : Cardinal;
  Got  : String;
begin
  Say('fizzles a');   // 1001
  Say('other');       // 1002
  Say('fizzles b');   // 1003
  Say('fizzles c');   // 1004
  Mark:=1000;
  Got:='';
  repeat
    Hit:=Find(Mark,1004,['fizzles']);
    if Hit>0 then
    begin
      Got:=Got+IntToStr(Hit)+' ';
      Mark:=Hit;
    end;
  until Hit=0;
  AssertEquals('1001 1003 1004 ',Got);
end;

procedure TEuoJournalSearchTests.TestHiddenLinesAreNotFound;
begin
  Say('fizzles a');   // 1001
  Say('fizzles b');   // 1002
  AssertEquals(1002,JournalSearch(1000,1002,1001,Entry,ANY,0,['fizzles']));
  AssertEquals(0,JournalSearch(1000,1002,1002,Entry,ANY,0,['fizzles']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoJournalSearchTests.TestColorAlone;
begin
  Say('first',33);    // 1001
  Say('second',946);  // 1002
  AssertEquals(1002,JournalSearch(1000,1002,0,Entry,ONE,946,['*']));
  AssertEquals(1001,JournalSearch(1000,1002,0,Entry,ONE,33,['*']));
  AssertEquals(0,JournalSearch(1000,1002,0,Entry,ONE,5,['*']));
end;

procedure TEuoJournalSearchTests.TestTextAndColorMustHoldOnTheSameLine;
begin
  Say('fizzles',33);  // 1001
  Say('other',946);   // 1002
  Say('fizzles',946); // 1003
  AssertEquals(1003,JournalSearch(1000,1003,0,Entry,ONE,946,['fizzles']));
end;

procedure TEuoJournalSearchTests.TestRightTextWrongColor;
begin
  Say('fizzles',33);
  AssertEquals(0,JournalSearch(999,1000,0,Entry,ONE,946,['fizzles']));
end;

procedure TEuoJournalSearchTests.TestColorZeroIsARealValue;
begin
  Say('first',33);   // 1001
  Say('second',0);   // 1002
  AssertEquals(1002,JournalSearch(1000,1002,0,Entry,ONE,0,['*']));
end;

procedure TEuoJournalSearchTests.TestUnreadableColorMatchesNothing;
begin
  Say('fizzles',0);
  // The interpreter hands -1 for a colour it can't read.
  AssertEquals(0,JournalSearch(999,1000,0,Entry,ONE,-1,['fizzles']));
  AssertEquals(0,JournalSearch(999,1000,0,Entry,ONE,-1,['*']));
end;

procedure TEuoJournalSearchTests.TestStarTextMatchesAnyLine;
begin
  Say('first');    // 1001
  Say('second');   // 1002
  AssertEquals(1001,Find(1000,1002,['*']));
  AssertEquals(1002,Find(1001,1002,['*']));
  AssertEquals(0,Find(1002,1002,['*']));
end;

procedure TEuoJournalSearchTests.TestStarAmongOtherTextsMatchesAnyLine;
begin
  Say('first');
  AssertEquals(1000,Find(999,1000,['fizzles','*']));
  AssertEquals(1000,Find(999,1000,['*','fizzles']));
end;

procedure TEuoJournalSearchTests.TestStarMatchesAHeldEmptyLine;
begin
  Say('');
  AssertEquals(1000,Find(999,1000,['*']));
end;

procedure TEuoJournalSearchTests.TestStarNeverMatchesPastTheLastLine;
begin
  AssertEquals('nothing held',0,Find(100,1000,['*']));
  Say('only');   // 1000, the one line held
  AssertEquals(1000,Find(100,1000,['*']));
  AssertEquals(0,Find(1000,1000,['*']));
end;

procedure TEuoJournalSearchTests.TestStarInsideATextIsLiteral;
begin
  Say('You must wait');   // 1001
  Say('*sighs*');         // 1002
  AssertEquals(0,Find(1000,1002,['you_*_wait']));
  AssertEquals(1002,Find(1000,1002,['*sighs*']));
  AssertEquals('those characters, anywhere in the line',1002,Find(1000,1002,['*sigh']));
  AssertEquals(0,Find(1000,1002,['*yawns*']));
end;

initialization
  RegisterTest(TEuoJournalSearchTests);
end.
