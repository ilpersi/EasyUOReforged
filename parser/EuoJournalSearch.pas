unit EuoJournalSearch;

{
  Port addition (FINDJOURNAL): which journal lines a search looks at and whether one matches,
  with no client and no interpreter, so all of it runs in the test suite. The interpreter
  (TEuoInterpreter.FindJournalProc) brings the lines from TUOCmd.JournalEntry and does the waiting.

  Lines are numbered as SCANJOURNAL numbers them: Index 0 is the newest line, and the line at
  Index has the running number JIndex-Index, the value #JFound reports.

  - JournalWindow: how many of the newest lines to look at. Since above 500 is a #JIndex value (the
    lines after it), 1 to 500 counts back from the newest line, SCANJOURNAL's own boundary. Since
    above JIndex means the numbering restarted (TEuoInterpreter.UpdateJournal), which happens only
    when the line it counted from has left the client's list, so every line still held is newer
    than Since. Lines DELETEJOURNAL hid (Hidden, SCANJOURNAL's "DJournal>=d" test) never count.
    At most the 100 lines SCANJOURNAL can reach.
  - JournalSearch: the oldest line in that window whose colour matches and which contains any of
    the texts, as its running number, or 0. Containing is the IN operator's test on what #Journal
    would read (spaces as '_', both sides uppercased); see EuoExpression.pas. A text of exactly
    '*' matches any line.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils;

const
  JOURNAL_MAX_LINES = 100;
  JOURNAL_ANY       = '*';

type
  // False past the last line held, so that '*' can't match a line that doesn't exist.
  TJournalEntryFunc = function(Index : Cardinal; out Txt : String; out Col : Cardinal) : Boolean of object;

function JournalWindow(Since : Int64; JIndex, Hidden : Cardinal) : Cardinal;
function JournalSearch(Since : Int64; JIndex, Hidden : Cardinal; Entry : TJournalEntryFunc;
                       ColorAny : Boolean; Color : Int64; const Texts : array of String) : Cardinal;

implementation

////////////////////////////////////////////////////////////////////////////////
function JournalWindow(Since : Int64; JIndex, Hidden : Cardinal) : Cardinal;
var
  Lines : Int64;
begin
  Result:=0;
  if (Since<=0) or (Hidden>=JIndex) then Exit;

  if Since<=500 then Lines:=Since
  else if Since>JIndex then Lines:=JOURNAL_MAX_LINES
  else Lines:=Int64(JIndex)-Since;

  if Lines>JOURNAL_MAX_LINES then Lines:=JOURNAL_MAX_LINES;
  if Lines>Int64(JIndex)-Hidden then Lines:=Int64(JIndex)-Hidden;
  Result:=Lines;
end;

////////////////////////////////////////////////////////////////////////////////
function HasAnyText(const Line : String; const Texts : array of String) : Boolean;
var
  Cnt   : Integer;
  LineU : String;
begin
  Result:=True;
  for Cnt:=0 to High(Texts) do
    if Texts[Cnt]=JOURNAL_ANY then Exit;

  LineU:=UpperCase(StringReplace(Line,' ','_',[rfReplaceAll]));
  for Cnt:=0 to High(Texts) do
    if Pos(UpperCase(Texts[Cnt]),LineU)>0 then Exit;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function JournalSearch(Since : Int64; JIndex, Hidden : Cardinal; Entry : TJournalEntryFunc;
                       ColorAny : Boolean; Color : Int64; const Texts : array of String) : Cardinal;
var
  Cnt  : Cardinal;
  Line : String;
  Col  : Cardinal;
begin
  Result:=0;
  Cnt:=JournalWindow(Since,JIndex,Hidden);
  while Cnt>0 do
  begin
    Dec(Cnt);
    if Entry(Cnt,Line,Col) then
      if ColorAny or (Color=Col) then
        if HasAnyText(Line,Texts) then
        begin
          Result:=JIndex-Cnt;
          Exit;
        end;
  end;
end;

end.
