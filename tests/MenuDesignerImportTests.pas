unit MenuDesignerImportTests;

{
  The MENU Designer's importer (tools/EUOMenuDesigner/mdimport.pas; docs/menu-designer.md,
  section 6): every sub-command it reads, 1.6's default and parent state machine as TMenu16
  replays it (default parent, pushdef/popdef first in first out and without alignment, clear,
  delete, duplicates), what it ignores, and the report of the lines it leaves out, with their
  line numbers. These tests make real hidden windows, like EuoMenu16GoldenTests.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, fpcunit, testregistry, mdtypes, mdmodel, mdimport;

type
  TMenuDesignerImportTests = class(TTestCase)
  private
    Doc : TMdDocument;
    Imp : TMdImporter;
    procedure Load(const Script : array of String);
    function  C(const Name : String) : TMdComponent;
    function  Kinds : String;
    function  EntryLine(Kind : TMdReportKind) : Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestOnlyMenuLinesAreRead;
    procedure TestFileOrderNotControlFlow;
    procedure TestForm0Window;
    procedure TestShowHide;
    procedure TestFormsAndVisibility;
    procedure TestDefaultParent;
    procedure TestPushPopFirstInFirstOut;
    procedure TestPushDropsAlignment;
    procedure TestClear;
    procedure TestDelete;
    procedure TestTextAndFixedSize;
    procedure TestRightAlignedText;
    procedure TestCheckAndRadioAlignment;
    procedure TestRadioGroups;
    procedure TestComboAndList;
    procedure TestSetChangesState;
    procedure TestShapeSqueezed;
    procedure TestImageDrawingAndStretch;
    procedure TestConstants;
    procedure TestFontDefaults;
    procedure TestReportedLines;
    procedure TestContinuationLineNumbers;
    procedure TestDuplicateName;
    procedure TestDuplicateFormSwallowsWhatFollows;
    procedure TestLineThatDoesNothing;
    procedure TestLogic15Warning;
  end;

implementation

procedure TMenuDesignerImportTests.SetUp;
begin
  Application.Initialize;
  Doc:=TMdDocument.Create;
  Imp:=TMdImporter.Create;
end;

procedure TMenuDesignerImportTests.TearDown;
begin
  Imp.Free;
  Application.ProcessMessages;
  Doc.Free;
end;

procedure TMenuDesignerImportTests.Load(const Script : array of String);
var
  L   : TStringList;
  Cnt : Integer;
begin
  L:=TStringList.Create;
  try
    for Cnt:=Low(Script) to High(Script) do
      L.Add(Script[Cnt]);
    Imp.Free;
    Imp:=TMdImporter.Create;
    Imp.Import(L,Doc);
  finally
    L.Free;
  end;
end;

function TMenuDesignerImportTests.C(const Name : String) : TMdComponent;
begin
  Result:=Doc.FindName(Name);
  AssertTrue('"'+Name+'" was loaded', Result<>nil);
end;

// The report's kinds and line numbers, e.g. "rkVariable@3 rkRuntime@4".
function TMenuDesignerImportTests.Kinds : String;
const
  Names : array[TMdReportKind] of String = ('logic15','variable','runtime','removed','unknown',
    'noeffect','duplicate','form0deleted','noparent','badparent','badname');
var
  Cnt : Integer;
  E   : TMdReportEntry;
begin
  Result:='';
  for Cnt:=0 to Imp.Report.Count-1 do
  begin
    E:=TMdReportEntry(Imp.Report[Cnt]);
    Result:=Result+Names[E.Kind]+'@'+IntToStr(E.LineNo)+' ';
  end;
  Result:=Trim(Result);
end;

function TMenuDesignerImportTests.EntryLine(Kind : TMdReportKind) : Integer;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Imp.Report.Count-1 do
    if TMdReportEntry(Imp.Report[Cnt]).Kind=Kind then
      Exit(TMdReportEntry(Imp.Report[Cnt]).LineNo);
  Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuDesignerImportTests.TestOnlyMenuLinesAreRead;
begin
  Load(['menu reforge mode 1.6', 'set %x 5', 'gosub build', 'display ok hello', 'halt',
    'sub build', '  menu button ok 10 20 80 25 OK', '  if %x > 3', '    menu text t 5 5 Hi',
    'return']);
  AssertEquals('nothing reported', '', Kinds);
  AssertEquals(2, Doc.Form0.ChildCount);
  AssertEquals('OK', C('ok').Text);
  AssertEquals('Hi', C('t').Text);
end;

procedure TMenuDesignerImportTests.TestFileOrderNotControlFlow;
begin
  Load(['menu reforge mode 1.6', 'for %i 1 3', '{', '  menu button b 0 0 50 20 B', '}',
    'goto skip', 'menu text after 0 30 After', 'skip:']);
  AssertEquals('read once, nothing duplicated', '', Kinds);
  AssertTrue(C('after')<>nil);
  AssertEquals(2, Doc.Form0.ChildCount);
end;

procedure TMenuDesignerImportTests.TestForm0Window;
begin
  Load(['menu reforge mode 1.6', 'menu window title Loot settings', 'menu window size 260 120',
    'menu window color red', 'menu window transparent 40']);
  AssertEquals('Loot settings', Doc.Form0.Text);
  AssertEquals(260, Doc.Form0.Width);
  AssertEquals(120, Doc.Form0.Height);
  AssertEquals(255, Doc.Form0.Color);
  AssertEquals(40, Doc.Form0.Transparency);
  AssertFalse('never shown', Doc.Form0.Visible);
end;

procedure TMenuDesignerImportTests.TestShowHide;
begin
  Load(['menu reforge mode 1.6', 'menu show 300 250']);
  AssertTrue(Doc.Form0.Visible);
  AssertEquals(300, Doc.Form0.Left);
  AssertEquals(250, Doc.Form0.Top);
  Load(['menu reforge mode 1.6', 'menu show', 'menu hide']);
  AssertFalse(Doc.Form0.Visible);
  AssertEquals('the start position', 100, Doc.Form0.Left);
end;

procedure TMenuDesignerImportTests.TestFormsAndVisibility;
var
  F : TMdComponent;
begin
  Load(['menu form opts 400 200 200 100 Options', 'menu button ok 10 10 80 25 OK',
    'menu setprop opts visible #true', 'menu form pop 0 0 100 50 Pop']);
  AssertEquals(3, Doc.FormCount);
  F:=Doc.Form(1);
  AssertEquals('opts', F.Name);
  AssertEquals('Options', F.Text);
  AssertTrue(F.Visible);
  AssertEquals('1.6 makes the client area larger than asked', True, F.Width>200);
  AssertTrue(C('ok').Parent=F);
  AssertFalse(Doc.Form(2).Visible);
  AssertTrue('the order they were made', Doc.Form(2).Name='pop');
end;

procedure TMenuDesignerImportTests.TestDefaultParent;
begin
  Load(['menu form f 0 0 200 200', 'menu panel p 10 10 100 100', 'menu button a 0 0 10 10 A',
    'menu setdef parent f', 'menu button b 0 0 10 10 B', 'menu setdef parent form0',
    'menu button c 0 0 10 10 C', 'menu setdef parent p', 'menu button d 0 0 10 10 D']);
  AssertEquals('nothing reported', '', Kinds);
  AssertEquals('p', C('a').Parent.Name);
  AssertEquals('f', C('b').Parent.Name);
  AssertEquals('form0', C('c').Parent.Name);
  AssertEquals('p', C('d').Parent.Name);
  AssertEquals('z-order kept', 'a', C('p').Child(0).Name);
  AssertEquals('d', C('p').Child(1).Name);
end;

// As 1.6 does it (analysis 3.8 item 1): popdef takes the FIRST copy pushed.
procedure TMenuDesignerImportTests.TestPushPopFirstInFirstOut;
begin
  Load(['menu form f 0 0 200 200', 'menu setdef fontsize 11', 'menu pushdef',
    'menu setdef fontsize 12', 'menu pushdef', 'menu setdef fontsize 13', 'menu popdef',
    'menu button a 0 0 10 10 A', 'menu popdef', 'menu button b 0 0 10 10 B']);
  AssertEquals(11, C('a').FontSize);
  AssertEquals(12, C('b').FontSize);
end;

procedure TMenuDesignerImportTests.TestPushDropsAlignment;
begin
  Load(['menu form f 0 0 200 200', 'menu setdef alignment 2', 'menu pushdef', 'menu popdef',
    'menu text t 0 0 T', 'menu setdef alignment 2', 'menu text u 0 20 U']);
  AssertEquals('lost by pushdef', 0, C('t').Alignment);
  AssertEquals(2, C('u').Alignment);
end;

procedure TMenuDesignerImportTests.TestClear;
begin
  Load(['menu form f 0 0 200 200', 'menu button a 0 0 10 10 A', 'menu text t 0 0 T',
    'menu clear', 'menu button b 0 0 10 10 B']);
  AssertEquals(1, Doc.FormCount);
  AssertTrue(Doc.FindName('a')=nil);
  AssertEquals('after clear: form0', 'form0', C('b').Parent.Name);
end;

procedure TMenuDesignerImportTests.TestDelete;
begin
  Load(['menu reforge mode 1.6', 'menu panel p 0 0 100 100', 'menu button a 0 0 10 10 A',
    'menu setdef parent form0', 'menu button b 0 0 10 10 B', 'menu delete p',
    'menu button a 50 50 10 10 Again']);
  AssertTrue(Doc.FindName('p')=nil);
  AssertEquals('the name is free again', 'Again', C('a').Text);
  AssertEquals('form0', C('a').Parent.Name);
  AssertEquals('', Kinds);
end;

procedure TMenuDesignerImportTests.TestTextAndFixedSize;
begin
  Load(['menu reforge mode 1.6', 'menu text t 5 5 Two$lines', 'menu text f 5 40 Fixed',
    'menu setprop f width 90', 'menu text g 5 60 G', 'menu setprop g width 90',
    'menu setprop g text Refitted']);
  AssertEquals('Two'#13#10'lines', C('t').Text);
  AssertFalse(C('t').FixedW);
  AssertTrue(C('f').FixedW);
  AssertEquals(90, C('f').Width);
  AssertFalse('a text change fits it again', C('g').FixedW);
end;

procedure TMenuDesignerImportTests.TestRightAlignedText;
var
  T : TMdComponent;
begin
  Load(['menu reforge mode 1.6', 'menu font align right', 'menu text t 200 5 Right']);
  T:=C('t');
  AssertEquals(1, T.Alignment);
  AssertEquals('200 is its right edge', 200, T.Left+T.Width);
end;

procedure TMenuDesignerImportTests.TestCheckAndRadioAlignment;
begin
  Load(['menu reforge mode 1.6', 'menu check c1 0 0 80 20 0 A', 'menu radio r1 0 20 80 20 0 B',
    'menu font align right', 'menu check c2 0 40 80 20 0 C', 'menu radio r2 0 60 80 20 0 D']);
  AssertEquals('text on the right', 0, C('c1').Alignment);
  AssertEquals(0, C('r1').Alignment);
  AssertEquals('text on the left', 1, C('c2').Alignment);
  AssertEquals(1, C('r2').Alignment);
end;

procedure TMenuDesignerImportTests.TestRadioGroups;
begin
  Load(['menu reforge mode 1.6', 'menu radio a 0 0 80 20 1 A', 'menu radio b 0 20 80 20 1 B',
    'menu panel p 0 50 100 50', 'menu radio c 0 0 80 20 1 C']);
  AssertFalse('b unchecked a', C('a').Checked);
  AssertTrue(C('b').Checked);
  AssertTrue('another parent', C('c').Checked);
end;

procedure TMenuDesignerImportTests.TestComboAndList;
begin
  Load(['menu reforge mode 1.6', 'menu combo create bag 0 0 100', 'menu combo add bag Backpack',
    'menu combo add bag Bank box', 'menu combo select bag 2', 'menu list create l 0 30 100 50',
    'menu list add l one', 'menu list add l two', 'menu list select l 1', 'menu list clear l',
    'menu list add l three']);
  AssertEquals(2, C('bag').Items.Count);
  AssertEquals('Bank box', C('bag').Items[1]);
  AssertEquals(2, C('bag').Selected);
  AssertEquals(1, C('l').Items.Count);
  AssertEquals('three', C('l').Items[0]);
  AssertEquals('clear dropped the selection', 0, C('l').Selected);
end;

procedure TMenuDesignerImportTests.TestSetChangesState;
begin
  Load(['menu reforge mode 1.6', 'menu edit e 0 0 100 old', 'menu set e new value',
    'menu check k 0 30 50 20 0 K', 'menu set k 1', 'menu button b 0 60 50 20 B',
    'menu set b Pressed']);
  AssertEquals('new value', C('e').Text);
  AssertTrue(C('k').Checked);
  AssertEquals('Pressed', C('b').Text);
end;

procedure TMenuDesignerImportTests.TestShapeSqueezed;
var
  S : TMdComponent;
begin
  Load(['menu reforge mode 1.6', 'menu shape s 0 0 60 30 1 0 2 red 7 blue']);
  S:=C('s');
  AssertTrue(S.TypeId=mdtShape);
  AssertEquals('1.6 centres the square', 15, S.Left);
  AssertEquals(30, S.Width);
  AssertEquals(30, S.BitmapW);
  AssertEquals(1, S.ShapeStyle);
  AssertTrue(S.LineOn);
  AssertEquals(2, S.LineWidth);
  AssertEquals(255, S.LineColor);
  AssertTrue(S.FillOn);
  AssertEquals(16711680, S.FillColor);
end;

procedure TMenuDesignerImportTests.TestImageDrawingAndStretch;
var
  I : TMdComponent;
begin
  Load(['menu reforge mode 1.6', 'menu image create img 5 5 40 20',
    'menu image rectangle img 0 0 40 20 red 1', 'menu image line img 0 0 39 19 blue 3',
    'menu image line img 0 0 -5 19 blue 3', 'menu image pix img 1 1 btnface',
    'menu image pos img 10 10 80 40']);
  I:=C('img');
  AssertTrue(I.TypeId=mdtImage);
  AssertEquals(3, Length(I.Ops));
  AssertTrue(I.Ops[0].Kind=dkRectangle);
  AssertTrue(I.Ops[0].Fill);
  AssertEquals(40, I.Ops[0].X2);
  AssertEquals(3, I.Ops[1].PenWidth);
  AssertEquals(-16777201, I.Ops[2].Color);
  AssertTrue(I.Stretch);
  AssertEquals(80, I.Width);
  AssertEquals(40, I.BitmapW);
  AssertEquals(10, I.Left);
  AssertEquals('the negative corner draws nothing', 5, EntryLine(rkNoEffect));
end;

procedure TMenuDesignerImportTests.TestConstants;
begin
  Load(['menu form f 0 0 100 100', 'menu check c 0 0 50 20 #true Yes',
    'menu setprop f visible #true', 'menu button b 0 30 50 20 a , #spc , b']);
  AssertEquals('', Kinds);
  AssertTrue(C('c').Checked);
  AssertTrue(Doc.Form(1).Visible);
  AssertEquals('a b', C('b').Text);
end;

procedure TMenuDesignerImportTests.TestFontDefaults;
var
  B : TMdComponent;
begin
  Load(['menu reforge mode 1.6', 'menu font name Courier New', 'menu font size 12',
    'menu font style bi', 'menu font color red', 'menu font bgcolor blue',
    'menu button b 0 0 50 20 B']);
  B:=C('b');
  AssertEquals('Courier New', B.FontName);
  AssertEquals(12, B.FontSize);
  AssertEquals(3, B.FontStyle);
  AssertEquals(255, B.FontColor);
  AssertEquals(16711680, B.Color);
end;

procedure TMenuDesignerImportTests.TestReportedLines;
begin
  Load(['menu reforge mode 1.6',      // 1
    'menu text t 0 0 %name',          // 2 variable
    'menu get t',                     // 3 runtime
    'menu getprop t text',            // 4 runtime
    'menu activate t',                // 5 runtime
    'menu hideeuo',                   // 6 removed
    'menu font transparent',          // 7 removed
    'menu image pixline img 0 0 1',   // 8 removed
    'menu frobnicate',                // 9 unknown
    'menu delete form0',              // 10
    '; menu get t',                   // a comment
    'menu button ok 0 0 50 20 OK']);  // 12
  AssertEquals('variable@2 runtime@3 runtime@4 runtime@5 removed@6 removed@7 removed@8 '+
    'unknown@9 form0deleted@10', Kinds);
  AssertTrue('form0 is kept', C('ok').Parent.IsForm0);
  AssertTrue('the variable line is not loaded', Doc.FindName('t')=nil);
end;

procedure TMenuDesignerImportTests.TestContinuationLineNumbers;
begin
  Load(['menu reforge mode 1.6',           // 1
    'menu text a 0 0 one',                 // 2
    '+ two',                               // 3
    'menu text b 0 20 %x',                 // 4
    '+ more']);                            // 5
  AssertEquals('variable@4', Kinds);
  AssertEquals('one two', C('a').Text);
end;

procedure TMenuDesignerImportTests.TestDuplicateName;
begin
  Load(['menu reforge mode 1.6', 'menu button ok 0 0 50 20 First', 'menu button ok 0 30 50 20 Second']);
  AssertEquals('duplicate@3', Kinds);
  AssertEquals('the first one is the one that works', 'First', C('ok').Text);
end;

procedure TMenuDesignerImportTests.TestDuplicateFormSwallowsWhatFollows;
begin
  Load(['menu form f 0 0 100 100', 'menu form f 0 0 100 100', 'menu button b 0 0 50 20 B']);
  AssertEquals('duplicate@2 noparent@3', Kinds);
  AssertEquals(2, Doc.FormCount);
end;

procedure TMenuDesignerImportTests.TestLineThatDoesNothing;
begin
  Load(['menu reforge mode 1.6', 'menu button b 0 0 -5 20 B', 'menu text t x 0 T']);
  AssertEquals('noeffect@2 noeffect@3', Kinds);
end;

procedure TMenuDesignerImportTests.TestLogic15Warning;
begin
  Load(['menu text t 0 0 Old', 'menu button b 0 20 50 20 OK']);
  AssertEquals('logic15@0', Kinds);
  AssertEquals('still read', 'Old', C('t').Text);
  Load(['menu reforge mode 1.6', 'menu text t 0 0 New']);
  AssertEquals('', Kinds);
  Load(['menu form f 0 0 10 10']);
  AssertEquals('a 1.6-only sub-command chooses 1.6', '', Kinds);
end;

initialization
  RegisterTest(TMenuDesignerImportTests);
end.
