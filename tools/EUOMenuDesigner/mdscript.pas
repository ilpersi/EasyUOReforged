unit mdscript;

{
  Port addition: how the MENU Designer reads script lines and runs MENU lines
  (docs/menu-designer.md, sections 3.2 and 6). A line becomes words exactly as the interpreter
  makes them, with the interpreter's own code: the '+' continuation join and the '.'/',' glue
  from EuoScriptWords, the split from EuoMenuSelect.SplitScriptLine (Parameterize's twin), the
  TParList from EuoScriptWords.WordsToParList.

  Variables cannot be known before a script runs, with five exceptions whose value never
  changes: #true (-1), #false (0), #spc (a space), #smc (;) and #dot (.), as
  TEuoInterpreter.GetVar returns them. Those are substituted where ParseLine substitutes; any
  other variable is reported and the line is not used.

  RunMenuLines runs every usable MENU line of a text through a TMenu16, in file order: the
  canvas engine, the Preview and the tests build windows with it.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, EuoTokens, EuoScriptWords, EuoMenuSelect, EuoMenu16;

type
  TMdLineReader = class
  private
    FLines    : TStrings;
    FIndex    : Integer;
    FVariable : String;
    function  Subst(Str : String) : String;
  public
    LineNo    : Integer;     // 1-based number of the line just read (its first line)
    Words     : TStringList; // its words, glued, constants substituted
    Variable  : String;      // the first other variable on it, '' if none
    constructor Create(ALines : TStrings);
    destructor  Destroy; override;
    function    Next : Boolean;
    function    IsMenu : Boolean;
    function    Sub : String;        // the MENU sub-command, upper-case
    function    Word(Index : Integer) : String;
    procedure   ToParList(P : TParList);
  end;

function  ConstantValue(const Name : String; out Value : String) : Boolean;
procedure RunWords(Menu : TMenu16; Words : TStrings);
procedure RunMenuLines(Menu : TMenu16; Lines : TStrings);
procedure RunMenuLine(Menu : TMenu16; const Line : String);

implementation

////////////////////////////////////////////////////////////////////////////////
function ConstantValue(const Name : String; out Value : String) : Boolean;
var
  U : String;
begin
  Result:=True;
  U:=UpperCase(Name);
  if U='#TRUE' then Value:='-1'
  else if U='#FALSE' then Value:='0'
  else if U='#SPC' then Value:=' '
  else if U='#SMC' then Value:=';'
  else if U='#DOT' then Value:='.'
  else Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TMdLineReader.Create(ALines : TStrings);
begin
  inherited Create;
  FLines:=ALines;
  Words:=TStringList.Create;
end;

destructor TMdLineReader.Destroy;
begin
  Words.Free;
  inherited Destroy;
end;

function TMdLineReader.Subst(Str : String) : String;
begin
  if ConstantValue(Str,Result) then Exit;
  if FVariable='' then FVariable:=Str;
  Result:=Str;
end;

// The next line, with its continuation lines; False at the end of the text.
function TMdLineReader.Next : Boolean;
var
  Line : String;
  U    : String;
begin
  Result:=FIndex<FLines.Count;
  if not Result then Exit;
  LineNo:=FIndex+1;
  Line:=JoinContinuation(FLines,FIndex);
  SplitScriptLine(Line,Words);
  FVariable:='';
  if Words.Count>0 then
  begin
    U:=UpperCase(Words[0]);
    GlueWords(Words,Subst,(U='SET') or (U='FOR'));
  end;
  Variable:=FVariable;
end;

function TMdLineReader.IsMenu : Boolean;
begin
  Result:=(Words.Count>0) and SameText(Words[0],'menu');
end;

function TMdLineReader.Sub : String;
begin
  Result:=UpperCase(Word(1));
end;

function TMdLineReader.Word(Index : Integer) : String;
begin
  if (Index>=0) and (Index<Words.Count) then Result:=Words[Index]
  else Result:='';
end;

procedure TMdLineReader.ToParList(P : TParList);
begin
  P.Clear;
  WordsToParList(Words,P);
end;

////////////////////////////////////////////////////////////////////////////////
procedure RunWords(Menu : TMenu16; Words : TStrings);
var
  P : TParList;
begin
  P:=TParList.Create;
  try
    WordsToParList(Words,P);
    Menu.Run(P);
  finally
    P.Free;
  end;
end;

// Every MENU line without an unknown variable, in file order.
procedure RunMenuLines(Menu : TMenu16; Lines : TStrings);
var
  R : TMdLineReader;
begin
  R:=TMdLineReader.Create(Lines);
  try
    while R.Next do
      if R.IsMenu and (R.Variable='') then RunWords(Menu,R.Words);
  finally
    R.Free;
  end;
end;

procedure RunMenuLine(Menu : TMenu16; const Line : String);
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Add(Line);
    RunMenuLines(Menu,L);
  finally
    L.Free;
  end;
end;

end.
