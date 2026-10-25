unit eucomplete;

{
  Builds the candidate word list for the script editor's autocomplete
  (TSynCompletion, wired up in main.pas): every registered command keyword
  and built-in #variable (reusing eusyntax.pas's CommandKeywords/
  SystemKeywords -- the same source the syntax highlighter uses, so the two
  can never drift apart from each other), plus every user-defined %/*!
  variable name found by scanning the current script's own text.

  User-defined variables are NOT tracked via a persistent symbol table --
  just a plain scan over TSynEdit.Lines each time completion is triggered.
  EasyUO variables are flat and dynamically named (no scoping, no types),
  so this is genuinely sufficient; a real symbol table would be solving a
  problem this language doesn't have. Rescanning on every trigger (rather
  than caching and invalidating on edit) is deliberate too -- scripts this
  editor handles are small enough that a full rescan is unmeasurable, and
  it sidesteps any risk of a stale cache showing a variable that was since
  deleted or renamed.

  One real subtlety, confirmed by reading TSynCompletion's own source
  (syncompletion.pas) rather than assumed: EasyUO's variable sigils (#, %,
  *, !) are NOT standard identifier characters as far as TSynCompletion's
  default *replacement-span* detection is concerned (TSynCompletion.Validate
  uses IsIdentifierChar/HighlighterIdentChars, both of which exclude these --
  they're deliberately TermSymbols in eusyntax.pas, which is what makes them
  work correctly as range-opening/token-ending punctuation for highlighting
  in the first place). Left alone, accepting a completion for "#FINDCNT"
  while "#FIN" is already typed would replace only "FIN" and insert
  "#FINDCNT", leaving "##FINDCNT" behind. GetPreviousToken (the OTHER half --
  what seeds the popup's initial search string) uses a completely different,
  simpler rule (EndOfTokenChr, defaulting to '()[].') that DOES include the
  sigil, so the mismatch is one-sided: the popup finds/positions on the
  right item correctly (provided the list is already populated when that
  search runs -- hence main.pas builds it in OnBeforeExecute, not
  OnExecute; see CompletionBeforeExecute there), but naive acceptance would
  insert it wrong. Fixed
  in main.pas via TSynCompletion.OnCodeCompletion (a supported extension
  point precisely for this kind of adjustment, not a workaround) -- widen
  the replacement span left by one character when the character immediately
  before it is a sigil that the chosen value also starts with. See
  AdjustCompletionSpan below.

  Sub-commands: where the caret sits on the word after a command that takes
  a sub-command (MENU, SQL, EVENT, STR, ...) -- or deeper, after MENU FONT,
  NAMESPACE COPY <pattern> FROM, ... -- the list holds only the words allowed
  there (SubCommands below), not the whole vocabulary. Only the words before
  the caret on the caret's own line are looked at, split the way the
  interpreter's Parameterize splits them (spaces/tabs; a ';' word starts a
  comment). When nothing in that short list starts with what is already
  typed (a %variable holding the sub-command, say), the usual full list is
  shown instead. TSynCompletion's AutoUseSingleIdent (on by default) inserts
  a one-word list without opening the popup -- TILE INIT's NOOVERRIDES,
  IGNOREITEM's RESET -- which is what Ctrl+Space should do there.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SynEdit, Types, eusyntax;

// Populates AList with every completion candidate for the script currently
// open in AEditor -- command keywords, built-in #variables, and every user-
// defined %/*!variable name found in AEditor's text. Rebuilt from scratch on
// every call; see header comment for why that's the right tradeoff here.
procedure BuildCompletionList(AList : TStrings; AEditor : TSynEdit);

// Adds to AList the sub-commands allowed at the end of LineBeforeCaret (the
// caret line's text up to the caret) and returns True -- or adds nothing and
// returns False when that spot takes no sub-command, or when none of them
// starts with the word already typed there. See the header comment.
function SubCommandWords(const LineBeforeCaret : String; AList : TStrings) : Boolean;

// Widens [SourceStart,SourceEnd) left by one character when the character
// immediately before SourceStart is one of EasyUO's variable sigils (#, %,
// *, !) and Value (the completion about to be inserted) starts with that
// same character -- avoiding a duplicated sigil on insertion. Intended to
// be called directly from a TSynCompletion.OnCodeCompletion handler; see
// this unit's header comment for why this is needed at all.
procedure AdjustCompletionSpan(Editor : TSynEdit; const Value : String;
  var SourceStart : TPoint);

implementation

uses
  SysUtils;

const
  VarSigils = ['#', '%', '*', '!'];
  VarNameChars = ['A'..'Z', 'a'..'z', '0'..'9', '_'];

  // 'KEY=WORDS': the words that may follow KEY, the words before them on the
  // line ('MENU FONT=...' is what may follow "menu font"). A '*' in KEY
  // stands for any one word (a skill name, a namespace pattern). Transcribed
  // from the ParList[n].StrU tests in EuoInterpreter.pas (MenuProcSync,
  // EventProc, ...; STATLOCK's stats from uoevents.pas's ExEv_StatLock).
  // Left out on purpose: menu Test (an empty debug hook) and event Sleep (not
  // implemented). tests\tools\CheckDocsCoverage.ps1 warns when the first-level
  // words here and the interpreter's drift apart.
  SubCommands : array[0..24] of String = (
    'DISPLAY=OK OKCANCEL YESNO YESNOCANCEL',
    'EVENT=CONTTOP DRAG EXMSG MACRO PATHFIND PROPERTY SKILLLOCK STATBAR SYSMESSAGE',
    'EVENT SKILLLOCK *=DOWN LOCKED UP',
    'EXEVENT=DRAG DROPC DROPG DROPPD EQUIP POPUP RENAMEPET SKILLLOCK STATLOCK',
    'EXEVENT SKILLLOCK *=DOWN LOCKED UP',
    'EXEVENT STATLOCK=DEX INT STR',
    'EXEVENT STATLOCK *=DOWN LOCKED UP',
    'IGNORECONT=RESET',
    'IGNOREITEM=RESET',
    'MENU=ACTIVATE BUTTON CHECK CLEAR COMBO DELETE EDIT FONT GET GETNUM HIDE ' +
      'HIDEEUO IMAGE LIST MEMO SET SHAPE SHOW TEXT WINDOW',
    'MENU COMBO=ADD CLEAR CREATE SELECT',
    'MENU FONT=ALIGN BGCOLOR COLOR NAME SIZE STYLE TRANSPARENT',
    'MENU FONT ALIGN=CENTER LEFT RIGHT',
    'MENU IMAGE=CREATE ELLIPSE FILE FLOODFILL LINE PIX PIXLINE POS RECTANGLE',
    'MENU LIST=ADD CLEAR CREATE SELECT',
    'MENU WINDOW=COLOR SIZE TITLE TRANSPARENT',
    'NAMESPACE=CLEAR COPY GLOBAL LOCAL POP PUSH',
    'NAMESPACE COPY *=FROM TO',
    'NAMESPACE COPY * FROM=GLOBAL LOCAL',
    'NAMESPACE COPY * TO=GLOBAL LOCAL',
    'SQL=CLOSE DELETE EXEC LOAD OPEN QUERY ROW SAVE',
    'STR=COUNT DEL INS LEFT LEN LOWER MID POS RIGHT UPPER',
    'TILE=CNT GET INIT',
    'TILE INIT=NOOVERRIDES',
    'UOXL=NEW SWAP'
  );

////////////////////////////////////////////////////////////////////////////////
// Splits S into AWords at spaces and tabs, as Parameterize does, stopping at
// a word that starts with ';' (the rest is a comment). Returns False if it
// stopped there.
function SplitWords(const S : String; AWords : TStrings) : Boolean;
var
  i, Start : Integer;
begin
  Result := True;
  AWords.Clear;
  i := 1;
  while i <= Length(S) do
  begin
    while (i <= Length(S)) and (S[i] in [#9, #32]) do
      Inc(i);
    Start := i;
    while (i <= Length(S)) and not (S[i] in [#9, #32]) do
      Inc(i);
    if i > Start then
    begin
      if S[Start] = ';' then
      begin
        Result := False;
        Exit;
      end;
      AWords.Add(Copy(S, Start, i - Start));
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function SubCommandWords(const LineBeforeCaret : String; AList : TStrings) : Boolean;
var
  Words, Parts : TStringList;
  Partial      : String;
  i, j, Eq     : Integer;
  Match        : Boolean;
begin
  Result := False;
  Words := TStringList.Create;
  Parts := TStringList.Create;
  try
    if not SplitWords(UpperCase(LineBeforeCaret), Words) then Exit;

    // The word being typed is the last one, unless the caret is past a space.
    Partial := '';
    if (Words.Count > 0) and not (LineBeforeCaret[Length(LineBeforeCaret)] in [#9, #32]) then
    begin
      Partial := Words[Words.Count - 1];
      Words.Delete(Words.Count - 1);
    end;
    if Words.Count = 0 then Exit; // still on the command itself

    for i := Low(SubCommands) to High(SubCommands) do
    begin
      Eq := Pos('=', SubCommands[i]);
      SplitWords(Copy(SubCommands[i], 1, Eq - 1), Parts);
      if Parts.Count <> Words.Count then Continue;
      Match := True;
      for j := 0 to Parts.Count - 1 do
        if (Parts[j] <> '*') and (Parts[j] <> Words[j]) then
        begin
          Match := False;
          Break;
        end;
      if not Match then Continue;

      SplitWords(Copy(SubCommands[i], Eq + 1, MaxInt), Parts);
      for j := 0 to Parts.Count - 1 do
        if Copy(Parts[j], 1, Length(Partial)) = Partial then
        begin
          AList.AddStrings(Parts);
          Result := True;
          Break;
        end;
      Exit;
    end;
  finally
    Words.Free;
    Parts.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure ScanUserVariables(AList : TStrings; AEditor : TSynEdit);
var
  LineIdx, i, Start : Integer;
  Line : String;
  Name : String;
begin
  for LineIdx := 0 to AEditor.Lines.Count - 1 do
  begin
    Line := AEditor.Lines[LineIdx];
    i := 1;
    while i <= Length(Line) do
    begin
      if Line[i] in VarSigils then
      begin
        Start := i;
        i := Start + 1;
        while (i <= Length(Line)) and (Line[i] in VarNameChars) do
          Inc(i);
        if i > Start + 1 then // at least one name character after the sigil
        begin
          Name := Copy(Line, Start, i - Start);
          if AList.IndexOf(Name) < 0 then
            AList.Add(Name);
        end;
      end
      else
        Inc(i);
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure BuildCompletionList(AList : TStrings; AEditor : TSynEdit);
var
  i      : Integer;
  Temp   : TStringList;
  Before : String;
begin
  Temp := TStringList.Create;
  try
    Temp.Sorted := True;
    Temp.Duplicates := dupIgnore;

    Before := '';
    if AEditor <> nil then
    begin
      i := AEditor.LogicalCaretXY.X - 1;
      Before := Copy(AEditor.LineText, 1, i);
      if i > Length(Before) then
        Before := Before + ' '; // caret past the end of the line
    end;

    if not SubCommandWords(Before, Temp) then
    begin
      for i := Low(CommandKeywords) to High(CommandKeywords) do
        Temp.Add(CommandKeywords[i]);
      for i := Low(SystemKeywords) to High(SystemKeywords) do
        Temp.Add(SystemKeywords[i]);
      if AEditor <> nil then
        ScanUserVariables(Temp, AEditor);
    end;

    AList.BeginUpdate;
    try
      AList.Assign(Temp);
    finally
      AList.EndUpdate;
    end;
  finally
    Temp.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure AdjustCompletionSpan(Editor : TSynEdit; const Value : String;
  var SourceStart : TPoint);
var
  Line   : String;
  PrevCh : Char;
begin
  if (Editor = nil) or (Value = '') then Exit;
  if (SourceStart.Y < 1) or (SourceStart.Y > Editor.Lines.Count) then Exit;

  Line := Editor.Lines[SourceStart.Y - 1];
  if (SourceStart.X <= 1) or (SourceStart.X - 1 > Length(Line)) then Exit;

  PrevCh := Line[SourceStart.X - 1];
  if (PrevCh in VarSigils) and (Value[1] = PrevCh) then
    Dec(SourceStart.X);
end;

end.
