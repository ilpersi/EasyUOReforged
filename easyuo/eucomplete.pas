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
  there (EuoSubCommands in parser\EuoVocabulary.pas), not the whole vocabulary. Only the words before
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
  SysUtils, EuoVocabulary, EuoScriptWords;

const
  VarSigils = ['#', '%', '*', '!'];
  VarNameChars = ['A'..'Z', 'a'..'z', '0'..'9', '_'];

////////////////////////////////////////////////////////////////////////////////
// Splits S into AWords as Parameterize does (EuoScriptWords.ScanLineWords),
// stopping at a word that starts with ';' (the rest is a comment). Returns
// False if it stopped there.
function SplitWords(const S : String; AWords : TStrings) : Boolean;
var
  W : TEuoWords;
  i : Integer;
begin
  Result := ScanLineWords(S, W);
  AWords.Clear;
  for i := 0 to High(W) do
    AWords.Add(W[i].Text);
end;

////////////////////////////////////////////////////////////////////////////////
function SubCommandWords(const LineBeforeCaret : String; AList : TStrings) : Boolean;
var
  Words, Parts : TStringList;
  Partial      : String;
  j            : Integer;
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

    // The row of the table that says what may follow these words, if there is one.
    if not EuoWordsAfter(Words, Parts) then Exit;
    for j := 0 to Parts.Count - 1 do
      if Copy(Parts[j], 1, Length(Partial)) = Partial then
      begin
        AList.AddStrings(Parts);
        Result := True;
        Break;
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
