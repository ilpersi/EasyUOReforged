unit DocsExampleTests;

{
  Runs the annotated examples of the documentation site through the real interpreter.

  An euo example on a page of website\src\content\docs may say what a variable holds when
  the script has stopped, in a comment that starts with "=>":

      set %c %b+1          ; => %c = %b+1

  Every example that has such a comment is played here, line by line, like
  EuoSqlTests.PlayScript, and each "=> name = value" is compared with the variable. So what
  those examples claim is what the interpreter does, and a page that goes stale fails the
  suite. The pages the agent pack's language.md is built from (docs\agent-support.md) state
  the rules of the language this way.

  An annotated example runs with no client and nobody watching, so it may use only the
  commands in Allowed below: nothing that waits, opens a window, touches the client, the
  registry or the disk. Anything else fails the test instead of being run.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoInterpreter;

type
  TDocsExampleTests = class(TTestCase)
  private
    Problems : TStringList;
    Ran      : Integer;
    procedure CollectFiles(const Dir : String; Files : TStringList);
    procedure CheckFile(const FN, Shown : String);
    procedure RunExample(const Where : String; Lines : TStringList);
  published
    procedure TestAnnotatedExamplesGiveWhatTheySay;
  end;

implementation

const
  // First words an annotated example may use. Labels (name:), braces and '+' lines are
  // syntax and always allowed. NOSUCHCOMMAND is the word the pages use to show that an
  // unknown command is skipped: it must never become a command.
  Allowed : array[0..19] of String = (
    'SET','IF','ELSE','FOR','WHILE','REPEAT','UNTIL','BREAK','CONTINUE',
    'GOSUB','SUB','RETURN','GOTO','EXIT','HALT','STOP','STR','NAMESPACE','LINESPERCYCLE',
    'NOSUCHCOMMAND');
  MaxSteps  = 20000;   // lines played before an example counts as never stopping
  MinToFind = 10;      // fewer annotated examples than this means the pages were not found or read

////////////////////////////////////////////////////////////////////////////////
function DocsDir : String;
begin
  Result:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..\website\src\content\docs');
end;

////////////////////////////////////////////////////////////////////////////////
// The code of a line: without its comment, trimmed.
function CodeOf(const Line : String) : String;
var
  P : Integer;
begin
  Result:=Line;
  P:=Pos(';',Result);
  if P>0 then Result:=Copy(Result,1,P-1);
  Result:=Trim(Result);
end;

////////////////////////////////////////////////////////////////////////////////
// "=> name = value" in the comment of a line: True and the two parts, or False.
function Expectation(const Line : String; out Name, Value : String) : Boolean;
var
  P : Integer;
  S : String;
begin
  Result:=False;
  P:=Pos(';',Line);
  if P=0 then Exit;
  S:=Trim(Copy(Line,P+1,MaxInt));
  if Copy(S,1,2)<>'=>' then Exit;
  S:=Trim(Copy(S,3,MaxInt));
  P:=Pos('=',S);
  if P<2 then Exit;
  Name:=Trim(Copy(S,1,P-1));
  Value:=Trim(Copy(S,P+1,MaxInt));
  Result:=(Name<>'') and (Pos(' ',Name)=0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsExampleTests.CollectFiles(const Dir : String; Files : TStringList);
var
  SR : TSearchRec;
begin
  if FindFirst(Dir+PathDelim+'*',faAnyFile,SR)<>0 then Exit;
  try
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then CollectFiles(Dir+PathDelim+SR.Name,Files)
      else if SameText(ExtractFileExt(SR.Name),'.md') or SameText(ExtractFileExt(SR.Name),'.mdx') then
        Files.Add(Dir+PathDelim+SR.Name);
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsExampleTests.RunExample(const Where : String; Lines : TStringList);
var
  Interp       : TEuoInterpreter;
  i, j, Steps  : Integer;
  Code, First  : String;
  Name, Value  : String;
  Got          : String;
  Ok           : Boolean;
begin
  for i:=0 to Lines.Count-1 do
  begin
    Code:=CodeOf(Lines[i]);
    if (Code='') or (Code[1]='+') or (Code='{') or (Code='}') then Continue;
    First:=UpperCase(Code);
    j:=Pos(' ',First);
    if j>0 then First:=Copy(First,1,j-1);
    if (j=0) and (First[Length(First)]=':') then Continue;   // a label
    Ok:=False;
    for j:=Low(Allowed) to High(Allowed) do
      if First=Allowed[j] then Ok:=True;
    if not Ok then
    begin
      Problems.Add(Where+': an example with "=>" is run by the tests and may not use "'+First+'": '+Trim(Lines[i]));
      Exit;
    end;
    // A word that starts with '*' and goes on is a persistent variable: it lives in the registry.
    for j:=1 to Length(Code)-1 do
      if (Code[j]='*') and ((j=1) or (Code[j-1] in [' ',#9])) and not (Code[j+1] in [' ',#9]) then
      begin
        Problems.Add(Where+': an example with "=>" may not use a persistent (*) variable: '+Trim(Lines[i]));
        Exit;
      end;
  end;

  Inc(Ran);
  Interp:=TEuoInterpreter.Create(0);
  try
    Interp.Clear;
    Interp.ScrList.Scr.Text:=Lines.Text;
    Interp.NextLine:=0;
    Interp.ResInt:=RES_OK;
    Steps:=0;
    while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Steps<MaxSteps) do
    begin
      Interp.PlayLine;
      Inc(Steps);
    end;
    if Interp.ResInt<>RES_STOP then
    begin
      Problems.Add(Where+': the example did not stop within '+IntToStr(MaxSteps)+' lines');
      Exit;
    end;
    for i:=0 to Lines.Count-1 do
      if Expectation(Lines[i],Name,Value) then
      begin
        Got:=Interp.GetVar(Name);
        if Got<>Value then
          Problems.Add(Where+': '+Name+' is "'+Got+'", the page says "'+Value+'"');
      end;
  finally
    Interp.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsExampleTests.CheckFile(const FN, Shown : String);
var
  Text, Block  : TStringList;
  i, N         : Integer;
  InBlock      : Boolean;
  Annotated    : Boolean;
  Name, Value  : String;
  S            : String;
begin
  Text:=TStringList.Create;
  Block:=TStringList.Create;
  try
    Text.LoadFromFile(FN);
    InBlock:=False;
    Annotated:=False;
    N:=0;
    for i:=0 to Text.Count-1 do
    begin
      S:=Trim(Text[i]);
      if not InBlock then
      begin
        if Copy(S,1,6)='```euo' then
        begin
          InBlock:=True;
          Annotated:=False;
          Block.Clear;
          Inc(N);
        end;
      end
      else if Copy(S,1,3)='```' then
      begin
        InBlock:=False;
        if Annotated then RunExample(Shown+', euo example '+IntToStr(N),Block);
      end
      else begin
        Block.Add(Text[i]);
        if Expectation(Text[i],Name,Value) then Annotated:=True;
      end;
    end;
  finally
    Block.Free;
    Text.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsExampleTests.TestAnnotatedExamplesGiveWhatTheySay;
var
  Files : TStringList;
  i     : Integer;
  Root  : String;
begin
  Root:=DocsDir;
  AssertTrue('The documentation pages are not at '+Root,DirectoryExists(Root));
  Files:=TStringList.Create;
  Problems:=TStringList.Create;
  try
    Ran:=0;
    CollectFiles(Root,Files);
    Files.Sort;
    for i:=0 to Files.Count-1 do
      CheckFile(Files[i],StringReplace(Copy(Files[i],Length(Root)+2,MaxInt),'\','/',[rfReplaceAll]));
    if Problems.Count>0 then
      Fail(IntToStr(Problems.Count)+' problem(s) in the annotated examples:'+LineEnding+Problems.Text);
    AssertTrue('Only '+IntToStr(Ran)+' annotated examples were found under '+Root+'; at least '+
      IntToStr(MinToFind)+' are expected',Ran>=MinToFind);
  finally
    Problems.Free;
    Files.Free;
  end;
end;

initialization
  RegisterTest(TDocsExampleTests);

end.
