unit EuoVocabulary;

{
  Port addition: the sub-commands of the commands that take one (MENU, EVENT, SQL, STR, ...),
  as one table for every tool that needs them. It was a private constant of the editor's
  autocomplete (easyuo\eucomplete.pas, which now reads it from here, unchanged) and moved here
  when the script checker (EuoLint.pas, docs\agent-support.md phase 2) needed the same words:
  what autocomplete offers and what the checker accepts cannot differ.

  A pure unit, at parser's lowest layer. EuoInterpreter.pas is NOT touched: the words are
  transcribed from the ParList[n].StrU tests of its handlers (MenuProcSync, EventProc, ...;
  STATLOCK's stats from uoevents.pas's ExEv_StatLock), plus the MENU words only the 1.6 logic
  has (TMenu16.Run and its property table in EuoMenu16.pas) and MENU REFORGE's settings.
  tests\tools\CheckDocsCoverage.ps1 fails when the first-level words here (what may follow
  EVENT, EXEVENT, MENU, NAMESPACE, STR, SQL, PATH) and the interpreter's drift apart; the
  deeper rows are not read off the source, so nothing checks them.

  Left out on purpose: menu Test (an empty debug hook) and event Sleep (not implemented).
}

{$mode delphi}{$H+}

interface

uses
  Classes;

const
  // 'KEY=WORDS': the words that may follow KEY, the words before them on the line
  // ('MENU FONT=...' is what may follow "menu font"). A '*' in KEY stands for any one word
  // (a skill name, a namespace pattern).
  EuoSubCommands : array[0..37] of String = (
    'DISPLAY=OK OKCANCEL YESNO YESNOCANCEL',
    'EVENT=CONTTOP DRAG EXMSG MACRO PATHFIND PROPERTY SKILLLOCK STATBAR SYSMESSAGE',
    'EVENT SKILLLOCK *=DOWN LOCKED UP',
    'EXEVENT=DRAG DROPC DROPG DROPPD EQUIP POPUP RENAMEPET SKILLLOCK STATLOCK',
    'EXEVENT SKILLLOCK *=DOWN LOCKED UP',
    'EXEVENT STATLOCK=DEX INT STR',
    'EXEVENT STATLOCK *=DOWN LOCKED UP',
    'IGNORECONT=RESET',
    'IGNOREITEM=RESET',
    'MENU=ACTIVATE BUTTON CHECK CLEAR COMBO DELETE EDIT FONT FORM GET GETDEF GETNUM ' +
      'GETPROP HIDE HIDEEUO IMAGE LIST MEMO PANEL POPDEF PUSHDEF RADIO REFORGE SET ' +
      'SETDEF SETPROP SHAPE SHOW TEXT WINDOW',
    'MENU COMBO=ADD CLEAR CREATE SELECT',
    'MENU FONT=ALIGN BGCOLOR COLOR NAME SIZE STYLE TRANSPARENT',
    'MENU FONT ALIGN=CENTER LEFT RIGHT',
    'MENU GETDEF=ALIGNMENT COLOR FONTCOLOR FONTNAME FONTSIZE FONTSTYLE PARENT',
    'MENU GETPROP *=ALIGNMENT CHECKED COLOR ENABLED FONTCOLOR FONTNAME FONTSIZE FONTSTYLE HEIGHT LEFT PARENT TEXT TOOLTIP TOP VISIBLE WIDTH',
    'MENU IMAGE=CREATE ELLIPSE FILE FLOODFILL LINE PIX PIXLINE POS RECTANGLE',
    'MENU LIST=ADD CLEAR CREATE SELECT',
    'MENU REFORGE=INCLUDECALL MODE',
    'MENU SETDEF=ALIGNMENT COLOR FONTCOLOR FONTNAME FONTSIZE FONTSTYLE PARENT',
    'MENU SETPROP *=ALIGNMENT CHECKED COLOR ENABLED FONTCOLOR FONTNAME FONTSIZE FONTSTYLE HEIGHT LEFT PARENT TEXT TOOLTIP TOP VISIBLE WIDTH',
    'MENU WINDOW=COLOR SIZE TITLE TRANSPARENT',
    'NAMESPACE=CLEAR COPY GLOBAL LOCAL POP PUSH',
    'NAMESPACE COPY *=FROM TO',
    'NAMESPACE COPY * FROM=GLOBAL LOCAL',
    'NAMESPACE COPY * TO=GLOBAL LOCAL',
    'PATH=AVOID BLOCK CAN CHECK CLEAR FIND FROM GET GO LINK SET STEP STOP UNBLOCK WALK',
    'PATH CLEAR=ALL AVOID BLOCKS LEARNED LINKS',
    'PATH SET=ACCURACY ACCURACYZ BLOCKTIME CHECK DIFS DOORCOST DOORS HEURISTIC LEAD LOG MARGIN MAXNODES ' +
      'MOBILES MODE TIMEOUT TURNCOST',
    'PATH SET DIFS=OFF ON',
    'PATH SET DOORS=ALL OFF ON',
    'PATH SET LOG=OFF',
    'PATH SET MOBILES=BLOCK IGNORE',
    'PATH SET MODE=AUTO CLIENT STEPS',
    'SQL=CLOSE DELETE EXEC LOAD OPEN QUERY ROW SAVE',
    'STR=CONCAT COUNT DEL INS JOIN LEFT LEN LOWER MID PART POS REPLACE RIGHT TRIM UPPER',
    'TILE=CNT GET INIT',
    'TILE INIT=NOOVERRIDES',
    'UOXL=NEW SWAP'
  );

  // The commands that work out an expression: their handlers call Eval. SET's expression
  // starts at its second parameter, the others' at their first. Every other command takes its
  // words as they are. tests\tools\CheckDocsCoverage.ps1 compares this with the handlers.
  EuoCalculating : array[0..5] of String = ('SET','IF','WHILE','UNTIL','RETURN','WAITFOR');

// The words that may follow Before, the upper-case words already on the line ('MENU', 'FONT'):
// True and the words in After when a row of the table has exactly those words as its key
// ('*' in the key matches any word), False and After untouched when none does. The first
// matching row wins.
function EuoWordsAfter(Before, After : TStrings) : Boolean;

implementation

////////////////////////////////////////////////////////////////////////////////
// Splits a row's key or its words, which are separated by single spaces.
procedure SplitRow(const S : String; Words : TStrings);
var
  i, Start : Integer;
begin
  Words.Clear;
  i:=1;
  while i<=Length(S) do
  begin
    while (i<=Length(S)) and (S[i]=' ') do Inc(i);
    Start:=i;
    while (i<=Length(S)) and (S[i]<>' ') do Inc(i);
    if i>Start then Words.Add(Copy(S,Start,i-Start));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoWordsAfter(Before, After : TStrings) : Boolean;
var
  Parts    : TStringList;
  i, j, Eq : Integer;
  Match    : Boolean;
begin
  Result:=False;
  Parts:=TStringList.Create;
  try
    for i:=Low(EuoSubCommands) to High(EuoSubCommands) do
    begin
      Eq:=Pos('=',EuoSubCommands[i]);
      SplitRow(Copy(EuoSubCommands[i],1,Eq-1),Parts);
      if Parts.Count<>Before.Count then Continue;
      Match:=True;
      for j:=0 to Parts.Count-1 do
        if (Parts[j]<>'*') and (Parts[j]<>Before[j]) then
        begin
          Match:=False;
          Break;
        end;
      if not Match then Continue;

      SplitRow(Copy(EuoSubCommands[i],Eq+1,MaxInt),After);
      Result:=True;
      Exit;
    end;
  finally
    Parts.Free;
  end;
end;

end.
