unit MenuDesignerRoundTripTests;

{
  The MENU Designer against the 1.6 MENU logic itself (docs/menu-designer.md, section 10).

  - Parity: the generated file runs through a real TMenu16, every property of every component
    is read back with "menu getprop" and compared with the model: position, size (a form's
    client area exactly, frame growth or not), font, colour, text, parent, state.
  - Order: each form's sub builds the same form run alone, after the others in any order, and
    when run twice.
  - Load and save: load(save(model)) = model; and for every MENU example on the docs site and
    every probe in tests/fixtures/menu16, load(save(load(text))) = load(text), with every line
    the importer leaves out reported for a reason that is expected of that text.

  These tests make real (mostly hidden) windows, like EuoMenu16GoldenTests.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, fpcunit, testregistry, EuoMenu16, EuoMenuCommon,
  mdtypes, mdmodel, mdgenerate, mdscript, mdimport;

type
  TMenuDesignerRoundTripTests = class(TTestCase)
  private
    Doc  : TMdDocument;
    Menu : TMenu16;
    procedure BuildRichDocument;
    procedure Restart;
    procedure RunForm(F : TMdComponent);
    function  GetProp(const Name, Prop : String) : String;
    function  MenuGet(const Name : String) : String;
    function  ReadBack(F : TMdComponent) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestParity;
    procedure TestEveryTypeRegistersItsKind;
    procedure TestSelectionsReadBack;
    procedure TestSubsInAnyOrder;
    procedure TestSubRunTwice;
    procedure TestLoadSaveIsTheModel;
    procedure TestCorpusRoundTrip;
  end;

implementation

function B(V : Boolean) : String;
begin
  if V then Result:='-1' else Result:='0';
end;

procedure TMenuDesignerRoundTripTests.SetUp;
begin
  Application.Initialize;   // console runner never does; registers the window classes
  Doc:=TMdDocument.Create;
  Menu:=nil;
end;

procedure TMenuDesignerRoundTripTests.TearDown;
begin
  Menu.Free;
  Application.ProcessMessages;
  Doc.Free;
end;

procedure TMenuDesignerRoundTripTests.Restart;
begin
  Menu.Free;
  Menu:=TMenu16.Create;
  Menu.ScriptStart;
end;

procedure TMenuDesignerRoundTripTests.RunForm(F : TMdComponent);
var
  Gen   : TMdGenerator;
  Lines : TStringList;
begin
  Gen:=TMdGenerator.Create;
  Lines:=TStringList.Create;
  try
    Gen.FormLines(Doc,F,Lines);
    RunMenuLines(Menu,Lines);
  finally
    Lines.Free;
    Gen.Free;
  end;
end;

function TMenuDesignerRoundTripTests.GetProp(const Name, Prop : String) : String;
begin
  Menu.MenuRes:='<unchanged>';
  RunMenuLine(Menu,'menu getprop '+Name+' '+Prop);
  Result:=Menu.MenuRes;
end;

function TMenuDesignerRoundTripTests.MenuGet(const Name : String) : String;
begin
  RunMenuLine(Menu,'menu get '+Name);
  Result:=Menu.MenuRes;
end;

// Every property of F and everything in it, as getprop reads it.
function TMenuDesignerRoundTripTests.ReadBack(F : TMdComponent) : String;
var
  List : TList;
  Cnt  : Integer;
  P    : Integer;
  C    : TMdComponent;
begin
  Result:='';
  List:=TList.Create;
  try
    Doc.AllComponents(List);
    for Cnt:=0 to List.Count-1 do
    begin
      C:=TMdComponent(List[Cnt]);
      if C.FormOf<>F then Continue;
      for P:=Low(MdProps) to High(MdProps) do
        if MdTypeHasProp(C.TypeId,MdProps[P].Name) then
          Result:=Result+C.Name+'.'+MdProps[P].Name+'='+GetProp(C.Name,MdProps[P].Name)+LineEnding;
      if C.Row.Items then Result:=Result+C.Name+'.get='+MenuGet(C.Name)+LineEnding;
    end;
  finally
    List.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// form0 and two more forms, with every type and values away from the defaults.
procedure TMenuDesignerRoundTripTests.BuildRichDocument;
var
  F0, F, P, C : TMdComponent;
  Op          : TMdDrawOp;
begin
  F0:=Doc.Form0;
  F0.Text:='Loot settings';
  F0.Left:=120;
  F0.Top:=80;
  F0.Width:=280;
  F0.Height:=200;
  F0.Color:=12632256;
  F0.Tooltip:='The main window';

  C:=Doc.Add(mdtText,F0,10,10,'title');
  C.Text:='Choose what to loot';
  C.FontStyle:=1;
  C.FontSize:=12;
  C.FontColor:=128;
  C:=Doc.Add(mdtText,F0,200,10,'right');
  C.Text:='Right';
  C.Alignment:=1;
  C:=Doc.Add(mdtText,F0,10,32,'fixed');
  C.Text:='Two'#13#10'lines';
  C.Alignment:=2;
  C.FixedW:=True;
  C.Width:=100;
  C.FixedH:=True;
  C.Height:=34;
  C.Color:=65535;
  C:=Doc.Add(mdtCheck,F0,10,70,'loot');
  C.Width:=150;
  C.Text:='Loot corpses';
  C.Checked:=True;
  C.Alignment:=1;
  C:=Doc.Add(mdtCombo,F0,10,95,'bag');
  C.Width:=150;
  C.Items.Add('Backpack');
  C.Items.Add('Bank box');
  C.Selected:=2;
  C:=Doc.Add(mdtEdit,F0,10,125,'delay');
  C.Text:='250';
  C.FontName:='Courier New';
  C.FixedH:=True;
  C.Height:=30;
  C:=Doc.Add(mdtButton,F0,170,160,'ok');
  C.Text:='OK';
  C.Tooltip:='Save and close';
  C:=Doc.Add(mdtButton,F0,80,160,'cancel');
  C.Text:='Cost $5';
  C.Enabled:=False;
  C:=Doc.Add(mdtShape,F0,220,40,'dot');
  C.ShapeStyle:=1;
  C.Width:=30;
  C.Height:=30;
  C.BitmapW:=30;
  C.BitmapH:=30;
  C.FillOn:=True;
  C.FillColor:=255;
  C.LineWidth:=2;
  C:=Doc.Add(mdtImage,F0,180,95,'img');
  C.BitmapW:=20;
  C.BitmapH:=10;
  C.Stretch:=True;
  C.Width:=40;
  C.Height:=20;
  Op:=Default(TMdDrawOp);
  Op.Kind:=dkRectangle;
  Op.X2:=20;
  Op.Y2:=10;
  Op.Color:=16711680;
  Op.Fill:=True;
  Op.PenWidth:=1;
  C.AddOp(Op);

  F:=Doc.AddForm('opts');
  F.Text:='Options';
  F.Width:=220;
  F.Height:=130;
  F.Color:=32768;
  F.Visible:=True;
  P:=Doc.Add(mdtPanel,F,10,10,'speed');
  P.Width:=180;
  P.Height:=50;
  P.Color:=65535;
  C:=Doc.Add(mdtRadio,P,5,5,'fast');
  Doc.SetChecked(C,True);
  C:=Doc.Add(mdtRadio,P,5,25,'safe');
  C.Alignment:=1;
  C.FontColor:=255;
  C:=Doc.Add(mdtMemo,F,10,65,'notes');
  C.Text:='first'#13#10'second';
  C.Width:=100;
  C.Height:=50;
  C:=Doc.Add(mdtList,F,120,65,'l');
  C.Width:=90;
  C.Height:=50;
  C.Items.Add('one');
  C.Items.Add('two');
  C.Selected:=1;
  C:=Doc.Add(mdtButton,F,0,0,'hidden');
  C.Visible:=False;

  F:=Doc.AddForm('pop');
  F.Text:='Pop';
  C:=Doc.Add(mdtText,F,5,5,'msg');
  C.Text:='Done';
  C.FontName:='Times New Roman';
  Doc.Add(mdtButton,F,5,30,'close');
end;

////////////////////////////////////////////////////////////////////////////////
// What getprop must read for C's property, from the model. False: nothing to compare (a
// size the control gives itself).
function Expected(C : TMdComponent; const Prop : String; out V : String) : Boolean;
var
  R : TMdTypeRow;
begin
  Result:=True;
  R:=C.Row;
  if Prop='alignment' then
  begin
    // a radio button's getprop is not inverted, a check box's is (1.6, analysis 3.8 item 7)
    if C.TypeId=mdtRadio then V:=IntToStr(1-C.Alignment) else V:=IntToStr(C.Alignment);
  end
  else if Prop='checked' then V:=B(C.Checked)
  else if Prop='color' then V:=IntToStr(C.Color)
  else if Prop='enabled' then V:=B(C.Enabled)
  else if Prop='fontcolor' then V:=IntToStr(C.FontColor)
  else if Prop='fontname' then V:=C.FontName
  else if Prop='fontsize' then V:=IntToStr(C.FontSize)
  else if Prop='fontstyle' then V:=IntToStr(C.FontStyle)
  else if Prop='width' then
  begin
    if (R.W=szFit) or ((R.W=szAuto) and not C.FixedW) then Exit(False);
    V:=IntToStr(C.Width);
  end
  else if Prop='height' then
  begin
    if (R.H=szFit) or ((R.H=szAuto) and not C.FixedH) then Exit(False);
    V:=IntToStr(C.Height);
  end
  else if Prop='left' then V:=IntToStr(C.Left)
  else if Prop='top' then V:=IntToStr(C.Top)
  else if Prop='parent' then V:=C.Parent.Name
  else if Prop='text' then
  begin
    if C.TypeId=mdtMemo then V:=StringReplace(C.Text,#13#10,'$',[rfReplaceAll])
    else V:=C.Text;
  end
  else if Prop='tooltip' then V:=C.Tooltip
  else if Prop='visible' then V:=B(C.Visible)
  else raise Exception.Create('no expectation for '+Prop);
end;

procedure TMenuDesignerRoundTripTests.TestParity;
var
  Gen   : TMdGenerator;
  Lines : TStringList;
  List  : TList;
  Cnt   : Integer;
  P     : Integer;
  C     : TMdComponent;
  Want  : String;
  Diffs : String;
  Got   : String;
  Seen  : Integer;
begin
  BuildRichDocument;
  Gen:=TMdGenerator.Create;
  Lines:=TStringList.Create;
  List:=TList.Create;
  try
    Gen.FileLines(Doc,Lines);
    AssertEquals('no warnings: '+Gen.Warnings.Text, 0, Gen.Warnings.Count);
    Restart;
    RunMenuLines(Menu,Lines);
    Doc.AllComponents(List);
    Diffs:='';
    Seen:=0;
    for Cnt:=0 to List.Count-1 do
    begin
      C:=TMdComponent(List[Cnt]);
      for P:=Low(MdProps) to High(MdProps) do
        if MdTypeHasProp(C.TypeId,MdProps[P].Name) and Expected(C,MdProps[P].Name,Want) then
        begin
          Got:=GetProp(C.Name,MdProps[P].Name);
          Inc(Seen);
          if Got<>Want then
            Diffs:=Diffs+Format('%s.%s: want "%s", got "%s"',[C.Name,MdProps[P].Name,Want,Got])+LineEnding;
        end;
    end;
    AssertEquals('every property as designed', '', Diffs);
    AssertTrue('properties compared: '+IntToStr(Seen), Seen>200);
  finally
    List.Free;
    Lines.Free;
    Gen.Free;
  end;
end;

procedure TMenuDesignerRoundTripTests.TestEveryTypeRegistersItsKind;
var
  T     : TMdType;
  C     : TMdComponent;
  Cnt   : Integer;
  Found : Boolean;
begin
  for T:=Low(TMdType) to High(TMdType) do
  begin
    Doc.Clear;
    if T=mdtForm then C:=Doc.AddForm('x')
    else C:=Doc.Add(T,Doc.Form0,5,5,'x');
    Restart;
    RunForm(C.FormOf);
    Found:=False;
    for Cnt:=0 to Menu.RegistryCount-1 do
      if (Menu.RegistryName(Cnt)='x') and (Menu.RegistryKind(Cnt)=MdTypeRows[T].Kind) then
        Found:=True;
    AssertTrue(MdTypeRows[T].Name+' registers its kind', Found);
  end;
end;

procedure TMenuDesignerRoundTripTests.TestSelectionsReadBack;
begin
  BuildRichDocument;
  Restart;
  RunForm(Doc.Form0);
  RunForm(Doc.Form(1));
  AssertEquals('combo: menu get reads the 1-based selection', '2', MenuGet('bag'));
  AssertEquals('list', '1', MenuGet('l'));
  AssertEquals('check', '-1', MenuGet('loot'));
  AssertEquals('radio', '-1', MenuGet('fast'));
  AssertEquals('the other radio in the panel', '0', MenuGet('safe'));
  AssertEquals('edit', '250', MenuGet('delay'));
end;

procedure TMenuDesignerRoundTripTests.TestSubsInAnyOrder;
const
  Orders : array[0..5,0..2] of Integer = ((0,1,2),(0,2,1),(1,0,2),(1,2,0),(2,0,1),(2,1,0));
var
  Alone : array[0..2] of String;
  Cnt   : Integer;
  O     : Integer;
  K     : Integer;
begin
  BuildRichDocument;
  for Cnt:=0 to 2 do
  begin
    Restart;
    RunForm(Doc.Form(Cnt));
    Alone[Cnt]:=ReadBack(Doc.Form(Cnt));
  end;
  for O:=Low(Orders) to High(Orders) do
  begin
    Restart;
    for K:=0 to 2 do
      RunForm(Doc.Form(Orders[O,K]));
    for Cnt:=0 to 2 do
      AssertEquals(Format('%s after the order %d%d%d',[Doc.Form(Cnt).Name,Orders[O,0],
        Orders[O,1],Orders[O,2]]), Alone[Cnt], ReadBack(Doc.Form(Cnt)));
  end;
end;

// Calling a sub again rebuilds its form: same windows, nothing left behind unreachable.
procedure TMenuDesignerRoundTripTests.TestSubRunTwice;
var
  Cnt   : Integer;
  Once  : String;
  Count : Integer;
  Kids  : Integer;
  F0    : TEuoMenuForm;
begin
  BuildRichDocument;
  for Cnt:=0 to 1 do
  begin
    Restart;
    RunForm(Doc.Form(Cnt));
    Once:=ReadBack(Doc.Form(Cnt));
    Count:=Menu.RegistryCount;
    F0:=TEuoMenuForm(Menu.RegistryCtrl(0));
    Kids:=F0.Surface.ControlCount;
    RunForm(Doc.Form(Cnt));
    AssertEquals(Doc.Form(Cnt).Name+' twice', Once, ReadBack(Doc.Form(Cnt)));
    AssertEquals(Doc.Form(Cnt).Name+': registered controls', Count, Menu.RegistryCount);
    AssertEquals(Doc.Form(Cnt).Name+': controls on form0', Kids, F0.Surface.ControlCount);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function Saved(D : TMdDocument) : TStringList;
var
  Gen : TMdGenerator;
begin
  Result:=TStringList.Create;
  Gen:=TMdGenerator.Create;
  try
    Gen.FileLines(D,Result);
  finally
    Gen.Free;
  end;
end;

// The sizes a control gives itself, copied from Src (what 1.6 measured) into Dst.
procedure CopyAutoSizes(Src, Dst : TMdDocument);
var
  L   : TList;
  Cnt : Integer;
  C   : TMdComponent;
  S   : TMdComponent;
begin
  L:=TList.Create;
  try
    Dst.AllComponents(L);
    for Cnt:=0 to L.Count-1 do
    begin
      C:=TMdComponent(L[Cnt]);
      S:=Src.FindName(C.Name);
      if S=nil then Continue;
      if (C.Row.W=szFit) or ((C.Row.W=szAuto) and not C.FixedW) then C.Width:=S.Width;
      if (C.Row.H=szFit) or ((C.Row.H=szAuto) and not C.FixedH) then C.Height:=S.Height;
    end;
  finally
    L.Free;
  end;
end;

procedure TMenuDesignerRoundTripTests.TestLoadSaveIsTheModel;
var
  Lines  : TStringList;
  Loaded : TMdDocument;
  Again  : TMdDocument;
  Report : String;
begin
  BuildRichDocument;
  Loaded:=TMdDocument.Create;
  Again:=TMdDocument.Create;
  Lines:=Saved(Doc);
  try
    Report:=ImportText(Lines,Loaded);
    AssertEquals('nothing left out', '', Report);
    CopyAutoSizes(Loaded,Doc);
    AssertEquals('load(save(model)) = model', Doc.Dump, Loaded.Dump);
    Lines.Free;
    Lines:=Saved(Loaded);
    ImportText(Lines,Again);
    AssertEquals('and again', Loaded.Dump, Again.Dump);
  finally
    Lines.Free;
    Again.Free;
    Loaded.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function DocsDir : String;
begin
  Result:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..'+PathDelim+'website'+PathDelim+'src'+
    PathDelim+'content'+PathDelim+'docs'+PathDelim);
end;

procedure FindPages(const Dir : String; Pages : TStrings);
var
  SR : TSearchRec;
begin
  if FindFirst(Dir+'*',faAnyFile,SR)=0 then
  try
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then FindPages(Dir+SR.Name+PathDelim,Pages)
      else if (ExtractFileExt(SR.Name)='.md') or (ExtractFileExt(SR.Name)='.mdx') then
        Pages.Add(Dir+SR.Name);
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
end;

// Every ```euo block on the site with a MENU line, as "page#n" = its text (lines joined by #1).
procedure DocsExamples(Examples : TStrings);
var
  Pages  : TStringList;
  Page   : TStringList;
  Block  : TStringList;
  P      : Integer;
  Cnt    : Integer;
  N      : Integer;
  Inside : Boolean;
  Menu   : Boolean;
  Line   : String;
begin
  Pages:=TStringList.Create;
  Page:=TStringList.Create;
  Block:=TStringList.Create;
  try
    FindPages(DocsDir,Pages);
    Pages.Sort;
    for P:=0 to Pages.Count-1 do
    begin
      Page.LoadFromFile(Pages[P]);
      Inside:=False;
      N:=0;
      Menu:=False;
      for Cnt:=0 to Page.Count-1 do
      begin
        Line:=Page[Cnt];
        if not Inside and (Copy(TrimLeft(Line),1,6)='```euo') then
        begin
          Inside:=True;
          Inc(N);
          Block.Clear;
          Menu:=False;
        end
        else if Inside and (Copy(TrimLeft(Line),1,3)='```') then
        begin
          Inside:=False;
          if Menu then
            Examples.Add(StringReplace(Copy(Pages[P],Length(DocsDir)+1,MaxInt),'\','/',[rfReplaceAll])+
              '#'+IntToStr(N)+'='+StringReplace(TrimRight(Block.Text),LineEnding,#1,[rfReplaceAll]));
        end
        else if Inside then
        begin
          Block.Add(Line);
          if SameText(Copy(TrimLeft(Line),1,5),'menu ') then Menu:=True;
        end;
      end;
    end;
  finally
    Block.Free;
    Page.Free;
    Pages.Free;
  end;
end;

const
  // Report entries any text may have: nothing it builds is lost.
  Usual = [rkLogic15, rkVariable, rkRuntime, rkRemoved, rkForm0Deleted];

// The other kinds, for the texts that are meant to show them: probes and examples of what 1.6
// does with duplicate names, orphans and invalid lines.
function ExpectedKinds(const Source : String) : TMdReportKinds;
begin
  Result:=[];
  if Source='commands/menu/versions.md#4' then Result:=[rkDuplicate]   // a name used twice
  else if Source='menu16/defaults.euo' then Result:=[rkUnknown]         // menu state, alpha only
  else if Source='menu16/duplicates.euo' then Result:=[rkDuplicate]
  else if Source='menu16/names.euo' then Result:=[rkDuplicate]
  else if (Source='menu16/forms.euo') or (Source='menu16/parent.euo') or
          (Source='menu16/restart.euo') or (Source='menu16/stale.euo') then
    Result:=[rkDuplicate, rkNoParent]   // a duplicate form takes the controls that follow
  else if Source='menu16/panels_radio.euo' then Result:=[rkNoParent]   // its panel deleted
  else if Source='menu16/image.euo' then Result:=[rkNoEffect]          // a negative corner
  else if Source='menu16/validation.euo' then Result:=[rkNoEffect];    // every invalid value
end;

procedure TMenuDesignerRoundTripTests.TestCorpusRoundTrip;
var
  Sources  : TStringList;
  SR       : TSearchRec;
  Dir      : String;
  Cnt      : Integer;
  K        : Integer;
  Text     : TStringList;
  D1, D2   : TMdDocument;
  Out1     : TStringList;
  Imp      : TMdImporter;
  E        : TMdReportEntry;
  Problems : String;
  Allowed  : TMdReportKinds;
begin
  Sources:=TStringList.Create;
  Text:=TStringList.Create;
  Problems:='';
  try
    DocsExamples(Sources);
    AssertTrue('the docs examples were found in '+DocsDir, Sources.Count>40);
    Dir:=ExtractFilePath(ParamStr(0))+'fixtures'+PathDelim+'menu16'+PathDelim;
    if FindFirst(Dir+'*.euo',faAnyFile,SR)=0 then
    try
      repeat
        Text.LoadFromFile(Dir+SR.Name);
        Sources.Add('menu16/'+SR.Name+'='+StringReplace(TrimRight(Text.Text),LineEnding,#1,[rfReplaceAll]));
      until FindNext(SR)<>0;
    finally
      FindClose(SR);
    end;

    for Cnt:=0 to Sources.Count-1 do
    begin
      Text.Text:=StringReplace(Sources.ValueFromIndex[Cnt],#1,LineEnding,[rfReplaceAll]);
      D1:=TMdDocument.Create;
      D2:=TMdDocument.Create;
      Imp:=TMdImporter.Create;
      Out1:=nil;
      try
        Imp.Import(Text,D1);
        Allowed:=Usual+ExpectedKinds(Sources.Names[Cnt]);
        for K:=0 to Imp.Report.Count-1 do
        begin
          E:=TMdReportEntry(Imp.Report[K]);
          if not (E.Kind in Allowed) then
            Problems:=Problems+Sources.Names[Cnt]+': line '+IntToStr(E.LineNo)+': '+E.Message+LineEnding;
        end;
        Out1:=Saved(D1);
        ImportText(Out1,D2);
        if D1.Dump<>D2.Dump then
          Problems:=Problems+Sources.Names[Cnt]+': save and load again changes it:'+LineEnding+
            D1.Dump+'--- became ---'+LineEnding+D2.Dump;
      finally
        Out1.Free;
        Imp.Free;
        D2.Free;
        D1.Free;
      end;
    end;
    AssertEquals(IntToStr(Sources.Count)+' texts', '', Problems);
  finally
    Text.Free;
    Sources.Free;
  end;
end;

initialization
  RegisterTest(TMenuDesignerRoundTripTests);
end.
