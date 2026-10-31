unit EuoScriptWords;

{
  Port addition: how one script line becomes words, moved verbatim out of
  TEuoInterpreter.ParseLine (and IsVar out of EuoInterpreter.pas) so that the MENU designer
  (tools/EUOMenuDesigner) reads a line exactly as the interpreter does, from the same code
  rather than a copy (docs/menu-designer.md, section 3.2). ParseLine calls these; what it does
  is unchanged. Splitting a line into words stays in TEuoInterpreter.Parameterize and its twin
  EuoMenuSelect.SplitScriptLine.

  - JoinContinuation: a line with the '+' continuation lines that follow it, each trimmed and
    appended without its '+' (and without a space).
  - GlueWords: ParseLine's two operator passes. The '.' glue runs right to left in the same
    loop as variable substitution, and the two cannot be separated: "%list . %i" substitutes
    %i, glues it onto "%list", and only then substitutes the glued "%list3". So substitution is
    a hook, called for each word IsVar accepts at the moment ParseLine substituted it; with
    Subst=nil nothing is substituted. KeepFirstArg leaves word 1 alone, as SET and FOR need for
    the variable they assign. The ',' glue runs after, on the substituted words.
  - WordsToParList: appends the words to a TParList as ParseLine fills it.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, EuoTokens, EuoConversion;

type
  TWordSubst = function(Str : String) : String of object;

function  IsVar(Str : String) : Boolean;
function  JoinContinuation(Lines : TStrings; var Index : Integer) : String;
procedure GlueWords(Par : TStrings; Subst : TWordSubst; KeepFirstArg : Boolean);
procedure WordsToParList(Par : TStrings; PList : TParList);

implementation

////////////////////////////////////////////////////////////////////////////////
function IsVar(Str : String) : Boolean;
var
  Cnt1 : Integer;
begin
  Result:=False;

  if Length(Str)<2 then Exit;
  if not(Str[1] in ['!','%','*','#']) then Exit;

  for Cnt1:=2 to Length(Str) do
    if not(Str[Cnt1] in ['0'..'9','A'..'Z','a'..'z','_']) then Exit;

  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// Index is the line on entry and the first line not joined on exit (ParseLine's NextLine).
function JoinContinuation(Lines : TStrings; var Index : Integer) : String;
var
  sBuf2 : String;
begin
  Result:=Trim(Lines[Index]);
  repeat
    Inc(Index);
    if Index>=Lines.Count then Break;
    sBuf2:=Trim(Lines[Index]);
    if Copy(sBuf2,1,1)<>'+' then Break;
    Delete(sBuf2,1,1);
    Result:=Result+sBuf2;
  until False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure GlueWords(Par : TStrings; Subst : TWordSubst; KeepFirstArg : Boolean);
var
  Cnt1 : Integer;
begin
  for Cnt1:=Par.Count-1 downto 0 do
  begin
    if Par[Cnt1]='.' then
      if (Cnt1<Par.Count-1)and(Cnt1>0) then
    begin
      Par[Cnt1-1]:=Par[Cnt1-1]+Par[Cnt1+1];
      Par.Delete(Cnt1);
      Par.Delete(Cnt1);
      Continue;
    end;

    if IsVar(Par[Cnt1]) then
    repeat
      if Cnt1=1 then
        if KeepFirstArg then Break;

      if Assigned(Subst) then Par[Cnt1]:=Subst(Par[Cnt1]);

    until True;
  end;

  for Cnt1:=Par.Count-2 downto 1 do
    if Par[Cnt1]=',' then
  begin
    Par[Cnt1-1]:=Par[Cnt1-1]+Par[Cnt1+1];
    Par.Delete(Cnt1);
    Par.Delete(Cnt1);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure WordsToParList(Par : TStrings; PList : TParList);
var
  Cnt1    : Integer;
  ConvRes : Boolean;
begin
  for Cnt1:=0 to Par.Count-1 do
  with PList do
  begin
    AddNew;
    Last.Str:=Par[Cnt1];
    Last.StrU:=UpperCase(Par[Cnt1]);
    Last.Int:=SToI64Def(Par[Cnt1],0,ConvRes);
    Last.IntValid:=ConvRes;
    Last.CardValid:=ConvRes and (Last.Int>=0);
  end;
end;

end.
