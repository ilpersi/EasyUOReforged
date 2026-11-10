unit EuoLint;

{
  Port addition (docs\agent-support.md, phase 2): the script checker. It reports what the
  interpreter would silently ignore or misread. EasyUO gives no errors -- a line it cannot
  understand is skipped -- so a script that "runs but does nothing" has no other signal.

  It never runs anything and touches no client. A pure unit like EuoBlocks.pas and
  EuoJumpTarget.pas: text in, findings out, so it is unit-testable and any tool can use it
  (EUOCli.exe's "check" does; the editor could). EuoInterpreter.pas is NOT touched by it. The
  script is read with the interpreter's own code wherever that code exists apart from it:

  - lines: EuoScriptWords.JoinContinuation ('+' lines) and EuoMenuSelect.SplitScriptLine
    (Parameterize's twin: spaces and tabs separate words, a word starting with ';' ends the line);
  - what is a variable: EuoScriptWords.IsVar, the exact test ParseLine substitutes on;
  - blocks: EuoBlocks.EuoBlockStep, which the editor's folding and Format Script run;
  - where GOSUB and GOTO lead: EuoJumpTarget.EuoFindSub / EuoFindLabel;
  - which MENU logic a run uses: EuoMenuSelect.ReadMenuSettings / UsesMenu16 / IsMenu16Only;
  - sub-commands: EuoVocabulary.EuoSubCommands, the table autocomplete offers.

  The command and variable names are given to the constructor. A caller takes them from the
  interpreter (TEuoInterpreter.GetCommandNames / GetVariableNames), so there is no copy here.

  What cannot be known before the run is never reported: a command or name held in a variable,
  a word glued to the next with ',' or '.'. Every finding is a warning or a note, never an
  error: old scripts rely on odd behaviour, and what looks wrong may be meant.

  The rules, by id (TEuoFinding.Rule):
    unknown-command       the first word is not a command, a label, a brace or a '+' line
    unknown-variable      a #name the interpreter does not have (it reads N/A)
    unknown-subcommand    EVENT/EXEVENT/MENU/NAMESPACE/STR/SQL/PATH and a word that is not one
                          of its sub-commands (first level only: the level
                          tests\tools\CheckDocsCoverage.ps1 verifies against the interpreter)
    glued-words           in the expression of a command that calculates: (%a  1)  %a=1  !%a
    brace-on-header-line  an opening brace at the end of an IF, FOR, ... line: it is a parameter
                          there, not a block
    stray-brace           an opening-brace line that does not directly follow its command
    unbalanced-braces     a closing brace without an opening one, or a block still open at the end
  (No brace is written out in this comment: it would end it.)
    repeat-until          UNTIL without REPEAT, or REPEAT without UNTIL
    missing-sub           GOSUB to a sub the file does not have
    missing-label         GOTO to a label the file does not have
    missing-call-file     CALL of a file that is not found (only when CurPath is set)
    restarts-at-end       the main flow can reach the last line, which restarts the script
    menu-logic            a MENU sub-command of the logic the run does not use
    needs-client   (note) which client commands the script uses; they are skipped without one
    menu-logic-chosen (note) which MENU logic the run will use
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Contnrs;

type
  TEuoLintSeverity = (lsWarning, lsNote);
  TEuoColumns      = array of Integer;

  TEuoFinding = class(TObject)
  public
    Rule     : String;
    Severity : TEuoLintSeverity;
    Line     : Integer;   // 1-based; 0 when the finding is about the whole script
    Column   : Integer;   // 1-based byte column of Word in that line; 0 when there is none
    Word     : String;    // the word the finding is about, or ''
    Message  : String;
    Hint     : String;    // what to do about it, or ''
    Seq      : Integer;   // the order the findings were made in
  end;

  TEuoLintResult = class(TObject)
  private
    FItems : TObjectList;
    function GetItem(Index : Integer) : TEuoFinding;
  public
    LineCount      : Integer;
    MenuLogic      : String;        // '1.5' or '1.6' when the script has MENU lines, else ''
    ClientCommands : TStringList;   // the client-dependent commands used, lower-case, sorted
    constructor Create;
    destructor  Destroy; override;
    function    Count : Integer;
    function    Warnings : Integer;
    function    Notes : Integer;
    // How many findings have this rule id.
    function    CountOf(const Rule : String) : Integer;
    property    Items[Index : Integer] : TEuoFinding read GetItem; default;
  end;

  TEuoLinter = class(TObject)
  private
    FCommands  : TStringList;   // upper-case, sorted; Objects[i]<>nil = needs a client
    FVariables : TStringList;   // upper-case, without '#', sorted
    FRes       : TEuoLintResult;
    procedure Add(const Rule : String; Severity : TEuoLintSeverity; Line, Column : Integer;
      const AWord, Message, Hint : String);
    function  IsCommand(const NameU : String; out NeedsClient : Boolean) : Boolean;
    function  IsVariable(const NameU : String) : Boolean;
    function  CallFileExists(const Name : String) : Boolean;
    procedure CheckWords(Lines : TStrings; LineIdx : Integer; Words : TStrings;
      const Columns : array of Integer; ClientUsed : TStrings);
    procedure CheckMenu(Lines : TStrings);
  public
    // The folder CALL resolves a relative name from: #CurPath, the folder of
    // EasyUOReforged.exe. '' (the default) leaves CALL lines unchecked.
    CurPath : String;
    // Commands: Objects[i] non-nil for a client-dependent one. Variables: without the '#'.
    // Case does not matter. Both are copied.
    constructor Create(Commands, Variables : TStrings);
    destructor  Destroy; override;
    procedure   Check(Lines : TStrings; Res : TEuoLintResult);
  end;

const
  EuoSeverityName : array[TEuoLintSeverity] of String = ('warning', 'note');

implementation

uses
  EuoBlocks, EuoScriptWords, EuoJumpTarget, EuoMenuSelect, EuoVocabulary;

const
  NameChars = ['0'..'9','A'..'Z','a'..'z','_'];

  // Words in the command position that are part of the language without being registered
  // commands: REPEAT only marks where UNTIL jumps back to (UntilProc looks for it).
  SyntaxWords : array[0..0] of String = ('REPEAT');
  // Old scripts carry these lines; the interpreter ignores them and nothing is lost.
  HarmlessWords : array[0..0] of String = ('INITEVENTS');
  // The commands whose sub-commands are checked: the families whose first level
  // tests\tools\CheckDocsCoverage.ps1 compares with the interpreter.
  Families : array[0..6] of String = ('EVENT','EXEVENT','MENU','NAMESPACE','STR','SQL','PATH');
  // The commands that open a block or govern the next line (EuoBlocks.EuoBlockStep), and SUB.
  Headers : array[0..6] of String = ('IF','ELSE','FOR','WHILE','ONHOTKEY','CMPPIX','SUB');
  // What ends the main part of a script on purpose. EXIT restarts a main script, but who
  // writes it means it (and in a called file it is the proper ending).
  Endings : array[0..3] of String = ('HALT','STOP','GOTO','EXIT');

type
  TStatement = record
    Cmd    : String;
    Line   : Integer;   // 0-based
    IsBody : Boolean;   // the one line an IF, FOR, ... governs
    Depth  : Integer;   // blocks open when the line runs
  end;

////////////////////////////////////////////////////////////////////////////////
function InList(const S : String; const List : array of String) : Boolean;
var
  i : Integer;
begin
  Result:=True;
  for i:=Low(List) to High(List) do
    if S=List[i] then Exit;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
// Where each word of a line starts (1-based byte columns), by Parameterize's rules: the
// same words SplitScriptLine gives for that line alone.
procedure WordColumns(const Line : String; out Columns : TEuoColumns);
var
  Cnt, First, N : Integer;
begin
  Columns:=nil;
  N:=0;
  Cnt:=1;
  while Cnt<=Length(Line) do
  begin
    if Line[Cnt] in [#9,#32] then
    begin
      Inc(Cnt);
      Continue;
    end;
    First:=Cnt;
    while (Cnt<=Length(Line)) and not (Line[Cnt] in [#9,#32]) do Inc(Cnt);
    if Line[First]=';' then Break;
    SetLength(Columns,N+1);
    Columns[N]:=First;
    Inc(N);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// A word whose value or name only exists at run time: a variable, or a word the ',' or '.'
// operator glues to its neighbour.
function IsDynamic(Words : TStrings; Index : Integer) : Boolean;
begin
  Result:=True;
  if IsVar(Words[Index]) then Exit;
  if Index+1<Words.Count then
    if (Words[Index+1]=',') or (Words[Index+1]='.') then Exit;
  if Index>0 then
    if (Words[Index-1]=',') or (Words[Index-1]='.') then Exit;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
// A word of an expression that holds more than one thing, because a space is missing. Every
// operator and parenthesis is a word of its own to the interpreter; glued to an operand it
// is neither, so nothing is replaced and nothing is worked out.
//
// Scripts keep a lot of plain text in SET and IF lines, and text may hold any character:
// "(none)", "===$", "<empty>", "Did_it_work_(journal)?". So a word counts as glued only when
// what is stuck together looks like operands and operators, and such text is left alone.
function IsGlued(const W : String) : Boolean;
var
  L, i, Open : Integer;
  Rest       : String;

  // A variable or a whole number.
  function IsOperand(const S : String) : Boolean;
  var
    j : Integer;
  begin
    Result:=IsVar(S);
    if Result or (S='') then Exit;
    Result:=True;
    for j:=1 to Length(S) do
      if not (S[j] in ['0'..'9']) then
        if not ((j=1) and (S[j]='-') and (Length(S)>1)) then Exit(False);
  end;

  // A variable, a whole number or one plain word of letters, digits and _.
  function IsOperandOrName(const S : String) : Boolean;
  var
    j : Integer;
  begin
    Result:=IsOperand(S);
    if Result or (S='') then Exit;
    Result:=True;
    for j:=1 to Length(S) do
      if not (S[j] in NameChars) then Exit(False);
  end;

begin
  Result:=False;
  L:=Length(W);
  if L<2 then Exit;
  if IsVar(W) then Exit;
  Result:=True;

  // (%a   1)   ((%a   %b))   : a parenthesis with no partner inside the word.
  // (%a)   (5)                : a pair around a single operand.
  // Text with its own pair inside is left alone: (none)  f(x)  Did_it_(journal)?
  Open:=0;
  for i:=1 to L do
    if W[i]='(' then Inc(Open)
    else if W[i]=')' then Dec(Open);
  if Open<>0 then Exit;
  if (W[1]='(') and (W[L]=')') and IsOperand(Copy(W,2,L-2)) then Exit;
  // !%a   !(
  if (W[1]='!') and (W[2] in ['%','#','*','!','(']) then Exit;
  // =1   >%a   <=5   =yes   (but not the operators themselves: <> <= >= =< =>, nor ===$)
  i:=1;
  while (i<=L) and (W[i] in ['=','<','>']) do Inc(i);
  if (i>1) and (i<=L) then
  begin
    Rest:=Copy(W,i,MaxInt);
    if IsOperandOrName(Rest) then Exit;
  end;
  // %a=1   %b+1   #hits<50
  if W[1] in ['%','#','*','!'] then
  begin
    i:=2;
    while (i<=L) and (W[i] in NameChars) do Inc(i);
    if (i>2) and (i<=L) and (W[i] in ['=','<','>','+','-','*','/']) then Exit;
  end;
  // 1+%a   5*2   10/%n   (but not 120/125 or 12/25/2020: a slash between numbers is how
  // scripts write a durability or a date they look for with IN)
  if W[1] in ['0'..'9'] then
  begin
    i:=1;
    while (i<=L) and (W[i] in ['0'..'9']) do Inc(i);
    if (i<L) and (W[i] in ['=','<','>','+','*']) then Exit;
    if (i<L) and (W[i]='/') and IsVar(Copy(W,i+1,MaxInt)) then Exit;
  end;

  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoLintResult /////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoLintResult.Create;
begin
  inherited Create;
  FItems:=TObjectList.Create(True);
  ClientCommands:=TStringList.Create;
  ClientCommands.Sorted:=True;
  ClientCommands.Duplicates:=dupIgnore;
  LineCount:=0;
  MenuLogic:='';
end;

////////////////////////////////////////////////////////////////////////////////
destructor TEuoLintResult.Destroy;
begin
  ClientCommands.Free;
  FItems.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintResult.GetItem(Index : Integer) : TEuoFinding;
begin
  Result:=TEuoFinding(FItems[Index]);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintResult.Count : Integer;
begin
  Result:=FItems.Count;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintResult.Warnings : Integer;
var
  i : Integer;
begin
  Result:=0;
  for i:=0 to FItems.Count-1 do
    if Items[i].Severity=lsWarning then Inc(Result);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintResult.Notes : Integer;
begin
  Result:=Count-Warnings;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintResult.CountOf(const Rule : String) : Integer;
var
  i : Integer;
begin
  Result:=0;
  for i:=0 to FItems.Count-1 do
    if Items[i].Rule=Rule then Inc(Result);
end;

////////////////////////////////////////////////////////////////////////////////
// By line, then by column, then as found. What is about a whole line (column 0) comes after
// what is about a word of it, and what is about the whole script (line 0) comes last.
function CompareFindings(A, B : Pointer) : Integer;

  function Key(Value : Integer) : Integer;
  begin
    if Value=0 then Result:=MaxInt else Result:=Value;
  end;

begin
  Result:=Ord(Key(TEuoFinding(A).Line)>Key(TEuoFinding(B).Line))-Ord(Key(TEuoFinding(A).Line)<Key(TEuoFinding(B).Line));
  if Result=0 then
    Result:=Ord(Key(TEuoFinding(A).Column)>Key(TEuoFinding(B).Column))-Ord(Key(TEuoFinding(A).Column)<Key(TEuoFinding(B).Column));
  if Result=0 then Result:=TEuoFinding(A).Seq-TEuoFinding(B).Seq;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoLinter /////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoLinter.Create(Commands, Variables : TStrings);
var
  i : Integer;

  function NewList : TStringList;
  begin
    Result:=TStringList.Create;
    // Every key and every probe is upper-case, so a plain ordinal compare is enough (see
    // EuoCommandRegistry.Create for why the default locale-aware one is not wanted).
    Result.CaseSensitive:=True;
    Result.UseLocale:=False;
    Result.Sorted:=True;
    Result.Duplicates:=dupIgnore;
  end;

begin
  inherited Create;
  CurPath:='';
  FCommands:=NewList;
  for i:=0 to Commands.Count-1 do
    FCommands.AddObject(UpperCase(Commands[i]),Commands.Objects[i]);
  FVariables:=NewList;
  for i:=0 to Variables.Count-1 do
    FVariables.Add(UpperCase(Variables[i]));
end;

////////////////////////////////////////////////////////////////////////////////
destructor TEuoLinter.Destroy;
begin
  FVariables.Free;
  FCommands.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLinter.Add(const Rule : String; Severity : TEuoLintSeverity; Line, Column : Integer;
  const AWord, Message, Hint : String);
var
  F : TEuoFinding;
begin
  F:=TEuoFinding.Create;
  F.Rule:=Rule;
  F.Severity:=Severity;
  F.Line:=Line;
  F.Column:=Column;
  F.Word:=AWord;
  F.Message:=Message;
  F.Hint:=Hint;
  F.Seq:=FRes.FItems.Count;
  FRes.FItems.Add(F);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLinter.IsCommand(const NameU : String; out NeedsClient : Boolean) : Boolean;
var
  i : Integer;
begin
  NeedsClient:=False;
  Result:=FCommands.Find(NameU,i);
  if Result then NeedsClient:=FCommands.Objects[i]<>nil;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLinter.IsVariable(const NameU : String) : Boolean;
var
  i : Integer;
begin
  Result:=FVariables.Find(NameU,i);
end;

////////////////////////////////////////////////////////////////////////////////
// TEuoInterpreter.ResolveCallFile's lookup: the name as written, from CurPath when it is
// not absolute, then with .txt, then with .euo.
function TEuoLinter.CallFileExists(const Name : String) : Boolean;
var
  S : String;
begin
  S:=Name;
  if not ((Copy(S,2,2)=':\') or (Copy(S,1,1)='\')) then
    S:=IncludeTrailingPathDelimiter(CurPath)+S;
  Result:=FileExists(S) or FileExists(S+'.txt') or FileExists(S+'.euo');
end;

////////////////////////////////////////////////////////////////////////////////
// The rules about the words of one logical line. Columns holds where the words of its
// first physical line start; a word that came from a '+' line has no column.
procedure TEuoLinter.CheckWords(Lines : TStrings; LineIdx : Integer; Words : TStrings;
  const Columns : array of Integer; ClientUsed : TStrings);
var
  First, Sub, Hint : String;
  NeedsClient      : Boolean;
  Known            : Boolean;
  k, ExprFrom      : Integer;
  After, Before    : TStringList;

  function Col(Index : Integer) : Integer;
  begin
    if Index<=High(Columns) then Result:=Columns[Index] else Result:=0;
  end;

begin
  First:=UpperCase(Words[0]);
  if (First='{') or (First='}') then Exit;
  if First[Length(First)]=':' then Exit;   // a label: the rest of the line is never read

  // ---- every #word is a variable the interpreter has -------------------------------------
  for k:=0 to Words.Count-1 do
    if (Words[k][1]='#') and IsVar(Words[k]) then
    begin
      // "#find . %x" builds the name at run time
      if (k+1<Words.Count) and (Words[k+1]='.') then Continue;
      if not IsVariable(UpperCase(Copy(Words[k],2,MaxInt))) then
        Add('unknown-variable',lsWarning,LineIdx+1,Col(k),Words[k],
          Words[k]+' is not a variable of EasyUO: it reads N/A.',
          'Take the name from the variable list.');
    end;

  if IsDynamic(Words,0) then Exit;   // the command itself is only known at run time

  // ---- the command -------------------------------------------------------------------------
  Known:=IsCommand(First,NeedsClient) or InList(First,SyntaxWords);
  if not Known then
  begin
    if InList(First,HarmlessWords) then Exit;
    if Pos('(',First)>1 then Hint:='Put a space before the parenthesis: every word needs spaces around it.'
    else if Pos(';',First)>1 then Hint:='Put a space before the ; that starts the comment.'
    else Hint:='Take the command from the command list. If this was meant as a label, it needs a : at the end.';
    Add('unknown-command',lsWarning,LineIdx+1,Col(0),Words[0],
      '"'+Words[0]+'" is not a command: the interpreter skips this line without an error.',Hint);
    Exit;
  end;
  if NeedsClient then ClientUsed.Add(LowerCase(First));

  // ---- its sub-command ---------------------------------------------------------------------
  if InList(First,Families) and (Words.Count>1) and not IsDynamic(Words,1) then
  begin
    After:=TStringList.Create;
    Before:=TStringList.Create;
    try
      Before.Add(First);
      Sub:=UpperCase(Words[1]);
      if EuoWordsAfter(Before,After) and (After.IndexOf(Sub)<0) then
        Add('unknown-subcommand',lsWarning,LineIdx+1,Col(1),Words[1],
          '"'+LowerCase(First)+' '+Words[1]+'" is not a sub-command of '+LowerCase(First)+': the line does nothing.',
          'One of: '+LowerCase(StringReplace(Trim(After.Text),LineEnding,' ',[rfReplaceAll]))+'.');
    finally
      Before.Free;
      After.Free;
    end;
  end;

  // ---- a brace at the end of its command's line ----------------------------------------------
  if InList(First,Headers) and (Words.Count>1) and (Words[Words.Count-1]='{') then
    Add('brace-on-header-line',lsWarning,LineIdx+1,Col(Words.Count-1),'{',
      'The { at the end of this '+LowerCase(First)+' line is read as a parameter, not as the start of a block.',
      'Put the { alone on the next line.');

  // ---- words glued together in an expression ---------------------------------------------------
  ExprFrom:=-1;
  if First='SET' then ExprFrom:=2
  else if InList(First,EuoCalculating) then ExprFrom:=1;
  if ExprFrom>=0 then
    for k:=ExprFrom to Words.Count-1 do
    begin
      // A word the ',' or '.' operator joins to its neighbour is a piece of text being put
      // together, not an operand: set %log %log , (none) , $
      if (k+1<Words.Count) and ((Words[k+1]=',') or (Words[k+1]='.')) then Continue;
      if (k>0) and ((Words[k-1]=',') or (Words[k-1]='.')) then Continue;
      if IsGlued(Words[k]) then
        Add('glued-words',lsWarning,LineIdx+1,Col(k),Words[k],
          '"'+Words[k]+'" is one word to the interpreter: nothing in it is replaced or worked out.',
          'Put a space around every operator and parenthesis: ( %a > 1 ), %b + 1.');
    end;

  // ---- where it jumps ----------------------------------------------------------------------------
  if (Words.Count>1) and not IsDynamic(Words,1) then
  begin
    if (First='GOSUB') and (EuoFindSub(Lines,Words[1])<0) then
      Add('missing-sub',lsWarning,LineIdx+1,Col(1),Words[1],
        'There is no "sub '+Words[1]+'" in this script: the gosub does nothing.',
        'A sub has to be in the same file as its gosub.');
    if (First='GOTO') and (EuoFindLabel(Lines,LineIdx,Words[1])<0) then
      Add('missing-label',lsWarning,LineIdx+1,Col(1),Words[1],
        'There is no label "'+Words[1]+':" in this script: the goto does nothing.',
        'A label is its name followed by : on a line of its own.');
    if (First='CALL') and (CurPath<>'') and not CallFileExists(Words[1]) then
      Add('missing-call-file',lsWarning,LineIdx+1,Col(1),Words[1],
        'The file "'+Words[1]+'" was not found: the call does nothing.',
        'A relative name starts from the folder of EasyUOReforged.exe (#CurPath); .txt and .euo are tried too.');
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Which MENU logic the run will use, and the MENU lines the other one would have run.
procedure TEuoLinter.CheckMenu(Lines : TStrings);
var
  Settings : TMenuSettings;
  Words    : TStringList;
  Logic    : TMenuLogic;
  Uses16   : Boolean;
  HasMenu  : Boolean;
  Cnt      : Integer;
  Sub, Why : String;
begin
  Words:=TStringList.Create;
  try
    HasMenu:=False;
    for Cnt:=0 to Lines.Count-1 do
      if EuoLineCmd(Lines[Cnt])='MENU' then
      begin
        HasMenu:=True;
        Break;
      end;
    if not HasMenu then Exit;

    ReadMenuSettings(Lines,Settings);
    Uses16:=UsesMenu16(Lines);
    if Settings.ModeSet then
    begin
      Logic:=Settings.Mode;
      Why:='the script sets "menu reforge mode '+MenuLogicName[Logic]+'"';
    end
    else if Uses16 then
    begin
      Logic:=mlMenu16;
      Why:='it uses a sub-command only EasyUO 1.6 has';
    end
    else begin
      Logic:=mlMenu15;
      Why:='it uses no sub-command only EasyUO 1.6 has';
      if Settings.IncludeCall then Why:=Why+' (the files it calls were not read)';
    end;
    FRes.MenuLogic:=MenuLogicName[Logic];
    Add('menu-logic-chosen',lsNote,0,0,'',
      'The menu lines run under the EasyUO '+MenuLogicName[Logic]+' MENU logic: '+Why+'.','');

    for Cnt:=0 to Lines.Count-1 do
    begin
      SplitScriptLine(Lines[Cnt],Words);
      if Words.Count<2 then Continue;
      if UpperCase(Words[0])<>'MENU' then Continue;
      if IsDynamic(Words,1) then Continue;
      Sub:=UpperCase(Words[1]);
      if (Logic=mlMenu15) and IsMenu16Only(Sub) then
        Add('menu-logic',lsWarning,Cnt+1,0,Words[1],
          '"menu '+Words[1]+'" exists only in the EasyUO 1.6 MENU logic, and this script runs under 1.5: the line does nothing.',
          'Remove "menu reforge mode 1.5", or use the 1.5 sub-commands only.');
      if (Logic=mlMenu16) and (Sub='HIDEEUO') then
        Add('menu-logic',lsWarning,Cnt+1,0,Words[1],
          '"menu hideeuo" exists only in the EasyUO 1.5 MENU logic, and this script runs under 1.6: the line does nothing.',
          'Remove it, or keep to the 1.5 sub-commands.');
    end;
  finally
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLinter.Check(Lines : TStrings; Res : TEuoLintResult);
var
  Stack      : array of TEuoBlockKind;
  OpenLine   : array of Integer;
  Pending    : TEuoBodyPending;
  Step       : TEuoLineStep;
  Stmts      : array of TStatement;
  Words      : TStringList;
  ClientUsed : TStringList;
  Columns    : TEuoColumns;
  i, j, N    : Integer;
  Next       : Integer;
  Joined     : String;
  Ok         : Boolean;
  LastMain   : Integer;

  function IsEnding(const S : TStatement) : Boolean;
  begin
    Result:=InList(S.Cmd,Endings) and not S.IsBody and (S.Depth=0);
  end;

begin
  FRes:=Res;
  Res.LineCount:=Lines.Count;
  Stack:=nil;
  OpenLine:=nil;
  Stmts:=nil;
  Pending:=ebpNone;
  Words:=TStringList.Create;
  ClientUsed:=TStringList.Create;
  ClientUsed.Sorted:=True;
  ClientUsed.Duplicates:=dupIgnore;
  try
    for i:=0 to Lines.Count-1 do
    begin
      Step:=EuoBlockStep(Lines[i],Pending,Stack);
      if Step.IsContinuation then Continue;

      // ---- blocks ------------------------------------------------------------------------------
      if (Step.Cmd='}') and (Step.Closes=0) then
        Add('unbalanced-braces',lsWarning,i+1,Pos('}',Lines[i]),'}',
          'This } closes nothing: there is no { open here.','Remove it, or add the { it belongs to.');
      if (Step.Cmd='UNTIL') and (Step.Closes=0) then
        Add('repeat-until',lsWarning,i+1,0,'until',
          'This until has no repeat before it: it has nowhere to jump back to.','Put a repeat line where the loop starts.');
      // "repeat { ... } until" is a common way to write the loop. The braces do nothing
      // there, and nothing is skipped by mistake, so that pair is left alone.
      if (Step.Cmd='{') and (Pending=ebpNone) and
         not ((Length(Stmts)>0) and (Stmts[High(Stmts)].Cmd='REPEAT')) then
        Add('stray-brace',lsWarning,i+1,Pos('{',Lines[i]),'{',
          'This { does not directly follow an if, else, for, while or sub line, so its block always runs.',
          'The { has to be the very next line after its command: no blank line or comment between them.');

      // The words of the logical line: this line and the '+' lines after it.
      Next:=i;
      Joined:=JoinContinuation(Lines,Next);
      SplitScriptLine(Joined,Words);

      // A statement is what the interpreter looks up, the first word, not EuoLineCmd's token
      // (which stops at a ';': "halt;x" is the word "halt;x" to the interpreter, no command).
      // REPEAT is no block to it: what stands between REPEAT and UNTIL runs like any line.
      if Words.Count>0 then
      begin
        N:=Length(Stmts);
        SetLength(Stmts,N+1);
        Stmts[N].Cmd:=UpperCase(Words[0]);
        Stmts[N].Line:=i;
        Stmts[N].IsBody:=Step.IsBody;
        Stmts[N].Depth:=0;
        for j:=0 to High(Stack) do
          if Stack[j]<>ebkRepeat then Inc(Stmts[N].Depth);
      end;

      for j:=1 to Step.Closes do
        if Length(Stack)>0 then
        begin
          SetLength(Stack,Length(Stack)-1);
          SetLength(OpenLine,Length(OpenLine)-1);
        end;
      if Step.Opens<>ebkNone then
      begin
        SetLength(Stack,Length(Stack)+1);
        Stack[High(Stack)]:=Step.Opens;
        SetLength(OpenLine,Length(OpenLine)+1);
        OpenLine[High(OpenLine)]:=i;
      end;
      Pending:=Step.Pending;

      // ---- the words of the logical line -----------------------------------------------------------
      if Words.Count=0 then Continue;
      WordColumns(Lines[i],Columns);
      CheckWords(Lines,i,Words,Columns,ClientUsed);
    end;

    // ---- what is still open at the end ---------------------------------------------------------------
    for i:=0 to High(Stack) do
      case Stack[i] of
        ebkBrace, ebkSubBrace:
          Add('unbalanced-braces',lsWarning,OpenLine[i]+1,Pos('{',Lines[OpenLine[i]]),'{',
            'This { is never closed.','Add the } that ends the block, alone on its line.');
        ebkRepeat:
          Add('repeat-until',lsWarning,OpenLine[i]+1,0,'repeat',
            'This repeat has no until after it.','End the loop with an until line and its condition.');
      end;

    // ---- can the main flow run off the end? ------------------------------------------------------------
    // The main part ends with halt, stop, a goto back into its loop (or exit), and the subs
    // come after it. A file that starts with a sub is a library for CALL and has no main part.
    if (Length(Stmts)>0) and (Stmts[0].Cmd<>'SUB') then
    begin
      Ok:=IsEnding(Stmts[High(Stmts)]);
      LastMain:=High(Stmts);
      for i:=High(Stmts) downto 1 do
        if Stmts[i].Cmd='SUB' then
        begin
          if IsEnding(Stmts[i-1]) then Ok:=True;
          if Stmts[i].Depth=0 then LastMain:=i-1;
        end;
      if not Ok then
        Add('restarts-at-end',lsWarning,Stmts[LastMain].Line+1,0,'',
          'After this line the script can reach its end, which starts it again from the first line (in a called file: returns to the caller).',
          'End the main part with halt, and put the subs after it. A called file ends with exit.');
    end;

    CheckMenu(Lines);

    if ClientUsed.Count>0 then
    begin
      Res.ClientCommands.AddStrings(ClientUsed);
      Add('needs-client',lsNote,0,0,'',
        'These commands act on the UO client and are skipped when none is attached: '+
        StringReplace(Trim(ClientUsed.Text),LineEnding,', ',[rfReplaceAll])+'.','');
    end;

    Res.FItems.Sort(@CompareFindings);
  finally
    ClientUsed.Free;
    Words.Free;
    FRes:=nil;
  end;
end;

end.
