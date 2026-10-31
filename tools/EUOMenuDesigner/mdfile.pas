unit mdfile;

{
  Port addition: the MENU Designer's files (docs/menu-designer.md, section 4). There is one
  format, a plain .euo script, read and written as EasyUO Reforged's editor does so that a
  designer file opens there unchanged:
  - reading: LoadScriptFileAsUTF8 (easyuo\scriptfile.pas), the editor's own loader: valid UTF-8
    as it is, anything else read as CP1252;
  - writing: UTF-8 without a BOM, CRLF after every line including the last, no trailing spaces,
    which is what the editor's TSynEdit writes (TSynEditLines.SaveToFile).

  Saving over a file the designer did not write would lose what the designer does not read:
  its other commands (ForeignLines) and the MENU lines the importer left out.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, mdmodel;

procedure LoadScript(const FN : String; Lines : TStrings);
procedure SaveScript(const FN : String; Lines : TStrings);
procedure ForeignLines(Lines : TStrings; Doc : TMdDocument; Found : TStrings);

implementation

uses
  scriptfile, mdscript, mdgenerate;

////////////////////////////////////////////////////////////////////////////////
procedure LoadScript(const FN : String; Lines : TStrings);
begin
  Lines.Text:=LoadScriptFileAsUTF8(FN);
end;

////////////////////////////////////////////////////////////////////////////////
procedure SaveScript(const FN : String; Lines : TStrings);
var
  S   : String;
  Cnt : Integer;
  FS  : TFileStream;
begin
  S:='';
  for Cnt:=0 to Lines.Count-1 do
    S:=S+TrimRight(Lines[Cnt])+#13#10;
  FS:=TFileStream.Create(FN,fmCreate);
  try
    if S<>'' then FS.WriteBuffer(S[1],Length(S));
  finally
    FS.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function Normal(Words : TStrings) : String;
var
  Cnt : Integer;
begin
  Result:='';
  for Cnt:=0 to Words.Count-1 do
    Result:=Result+LowerCase(Words[Cnt])+' ';
  Result:=Trim(Result);
end;

// The lines of a loaded text that are neither MENU lines, nor blank or comments, nor the
// designer's own layout (header, sub, return) for the forms Doc holds: what saving over the
// file would delete. Each as "line N: text", with Objects the line number.
procedure ForeignLines(Lines : TStrings; Doc : TMdDocument; Found : TStrings);
var
  Layout : TStringList;
  Header : TStringList;
  R      : TMdLineReader;
  Cnt    : Integer;
begin
  Layout:=TStringList.Create;
  Header:=TStringList.Create;
  try
    HeaderLines(Doc,Header);
    for Cnt:=0 to Doc.FormCount-1 do
    begin
      Header.Add('sub '+SubName(Doc.Form(Cnt)));
      Header.Add('return');
    end;
    R:=TMdLineReader.Create(Header);
    try
      while R.Next do
        if (R.Words.Count>0) and not R.IsMenu then Layout.Add(Normal(R.Words));
    finally
      R.Free;
    end;

    R:=TMdLineReader.Create(Lines);
    try
      while R.Next do
      begin
        if (R.Words.Count=0) or R.IsMenu then Continue;
        if Layout.IndexOf(Normal(R.Words))>=0 then Continue;
        Found.AddObject('line '+IntToStr(R.LineNo)+': '+Trim(Lines[R.LineNo-1]),
          TObject(PtrInt(R.LineNo)));
      end;
    finally
      R.Free;
    end;
  finally
    Header.Free;
    Layout.Free;
  end;
end;

end.
