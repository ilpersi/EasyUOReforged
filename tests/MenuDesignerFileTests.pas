unit MenuDesignerFileTests;

{
  The MENU Designer's files (tools/EUOMenuDesigner/mdfile.pas; docs/menu-designer.md, section
  4): a saved file loads back as the same model; it is byte for byte what the editor writes
  when it opens the file and saves it again (LoadScriptFileAsUTF8 into a TSynEdit,
  TSynEditLines.SaveToFile); encodings are read as the editor reads them; and the lines saving
  over a loaded file would delete are found.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, fpcunit, testregistry, SynEdit, scriptfile, mdtypes, mdmodel,
  mdgenerate, mdimport, mdfile;

type
  TMenuDesignerFileTests = class(TTestCase)
  private
    Dir : String;
    function  FileBytes(const FN : String) : String;
    procedure WriteBytes(const FN, Bytes : String);
    function  SampleDocument : TMdDocument;
    function  Foreign(const Script : array of String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSaveLoadIsTheModel;
    procedure TestTheEditorSavesItUnchanged;
    procedure TestBytesOnDisk;
    procedure TestCp1252IsRead;
    procedure TestUtf8StaysUtf8;
    procedure TestADesignerFileHasNoForeignLines;
    procedure TestForeignLinesAreFound;
  end;

implementation

procedure TMenuDesignerFileTests.SetUp;
begin
  Application.Initialize;
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'MenuDesignerFileTests'+PathDelim;
  ForceDirectories(Dir);
end;

procedure TMenuDesignerFileTests.TearDown;
var
  SR : TSearchRec;
begin
  if FindFirst(Dir+'*.euo',faAnyFile,SR)=0 then
  try
    repeat
      DeleteFile(Dir+SR.Name);
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
  RemoveDir(Dir);
  Application.ProcessMessages;
end;

function TMenuDesignerFileTests.FileBytes(const FN : String) : String;
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result,FS.Size);
    if FS.Size>0 then FS.ReadBuffer(Result[1],FS.Size);
  finally
    FS.Free;
  end;
end;

procedure TMenuDesignerFileTests.WriteBytes(const FN, Bytes : String);
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmCreate);
  try
    if Bytes<>'' then FS.WriteBuffer(Bytes[1],Length(Bytes));
  finally
    FS.Free;
  end;
end;

function TMenuDesignerFileTests.SampleDocument : TMdDocument;
var
  C : TMdComponent;
  F : TMdComponent;
begin
  Result:=TMdDocument.Create;
  Result.Form0.Text:='Réglages';   // not ASCII
  C:=Result.Add(mdtButton,Result.Form0,10,10,'ok');
  C.Text:='Prêt';
  C:=Result.Add(mdtCheck,Result.Form0,10,40,'loot');
  C.Text:='Loot corpses';
  C.Checked:=True;
  F:=Result.AddForm('opts');
  C:=Result.Add(mdtCombo,F,5,5,'bag');
  C.Items.Add('Backpack');
  C.Selected:=1;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuDesignerFileTests.TestSaveLoadIsTheModel;
var
  D1, D2 : TMdDocument;
  Lines  : TStringList;
  Gen    : TMdGenerator;
begin
  D1:=SampleDocument;
  D2:=TMdDocument.Create;
  Lines:=TStringList.Create;
  Gen:=TMdGenerator.Create;
  try
    Gen.FileLines(D1,Lines);
    SaveScript(Dir+'a.euo',Lines);
    Lines.Clear;
    LoadScript(Dir+'a.euo',Lines);
    AssertEquals('', ImportText(Lines,D2));
    AssertEquals('Réglages', D2.Form0.Text);
    AssertEquals('Prêt', D2.FindName('ok').Text);
    AssertEquals('opts', D2.Form(1).Name);
    AssertEquals(1, D2.FindName('bag').Selected);
    AssertTrue(D2.FindName('loot').Checked);
  finally
    Gen.Free;
    Lines.Free;
    D2.Free;
    D1.Free;
  end;
end;

// Opening the file in EasyUO Reforged and saving it again changes nothing.
procedure TMenuDesignerFileTests.TestTheEditorSavesItUnchanged;
var
  D     : TMdDocument;
  Lines : TStringList;
  Gen   : TMdGenerator;
  Ed    : TSynEdit;
begin
  D:=SampleDocument;
  Lines:=TStringList.Create;
  Gen:=TMdGenerator.Create;
  Ed:=TSynEdit.Create(nil);
  try
    Gen.FileLines(D,Lines);
    SaveScript(Dir+'designer.euo',Lines);
    Ed.Lines.Text:=LoadScriptFileAsUTF8(Dir+'designer.euo');   // as TInstHandler.Reopen does
    Ed.Lines.SaveToFile(Dir+'editor.euo');                       // as TInstHandler.Save does
    AssertEquals(FileBytes(Dir+'designer.euo'), FileBytes(Dir+'editor.euo'));
  finally
    Ed.Free;
    Gen.Free;
    Lines.Free;
    D.Free;
  end;
end;

procedure TMenuDesignerFileTests.TestBytesOnDisk;
var
  Lines : TStringList;
  B     : String;
begin
  Lines:=TStringList.Create;
  try
    Lines.Add('menu text t 0 0 é');
    Lines.Add('halt  ');
    SaveScript(Dir+'b.euo',Lines);
    B:=FileBytes(Dir+'b.euo');
    AssertEquals('UTF-8, no BOM, CRLF after every line, no trailing spaces',
      'menu text t 0 0 '#$C3#$A9#13#10'halt'#13#10, B);
  finally
    Lines.Free;
  end;
end;

procedure TMenuDesignerFileTests.TestCp1252IsRead;
var
  Lines : TStringList;
begin
  Lines:=TStringList.Create;
  try
    WriteBytes(Dir+'c.euo','menu text t 0 0 caf'#$E9#10'halt');
    LoadScript(Dir+'c.euo',Lines);
    AssertEquals(2, Lines.Count);
    AssertEquals('menu text t 0 0 café', Lines[0]);
  finally
    Lines.Free;
  end;
end;

procedure TMenuDesignerFileTests.TestUtf8StaysUtf8;
var
  Lines : TStringList;
begin
  Lines:=TStringList.Create;
  try
    WriteBytes(Dir+'d.euo','menu text t 0 0 caf'#$C3#$A9#13#10);
    LoadScript(Dir+'d.euo',Lines);
    AssertEquals('menu text t 0 0 café', Lines[0]);
  finally
    Lines.Free;
  end;
end;

function TMenuDesignerFileTests.Foreign(const Script : array of String) : String;
var
  L     : TStringList;
  Found : TStringList;
  D     : TMdDocument;
  Cnt   : Integer;
begin
  L:=TStringList.Create;
  Found:=TStringList.Create;
  D:=TMdDocument.Create;
  try
    for Cnt:=Low(Script) to High(Script) do
      L.Add(Script[Cnt]);
    ImportText(L,D);
    ForeignLines(L,D,Found);
    Result:=StringReplace(Trim(Found.Text),LineEnding,'|',[rfReplaceAll]);
  finally
    D.Free;
    Found.Free;
    L.Free;
  end;
end;

procedure TMenuDesignerFileTests.TestADesignerFileHasNoForeignLines;
var
  D     : TMdDocument;
  Lines : TStringList;
  Gen   : TMdGenerator;
  Found : TStringList;
  D2    : TMdDocument;
begin
  D:=SampleDocument;
  D2:=TMdDocument.Create;
  Lines:=TStringList.Create;
  Gen:=TMdGenerator.Create;
  Found:=TStringList.Create;
  try
    Gen.FileLines(D,Lines);
    ImportText(Lines,D2);
    ForeignLines(Lines,D2,Found);
    AssertEquals('', Found.Text);
  finally
    Found.Free;
    Gen.Free;
    Lines.Free;
    D2.Free;
    D.Free;
  end;
end;

procedure TMenuDesignerFileTests.TestForeignLinesAreFound;
begin
  AssertEquals('line 2: display ok hi|line 4: gosub other',
    Foreign(['menu reforge mode 1.6', 'display ok hi', '; a comment', 'gosub other', '',
      'menu button b 0 0 50 20 B', 'halt']));
  AssertEquals('a sub of a form that is not there', 'line 1: sub menu_gone',
    Foreign(['sub menu_gone', 'return']));
  AssertEquals('the layout for the forms read', '',
    Foreign(['gosub menu_form0', 'halt', 'sub menu_form0', '  menu text t 0 0 T', 'return']));
end;

initialization
  RegisterTest(TMenuDesignerFileTests);
end.
