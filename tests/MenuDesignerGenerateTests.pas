unit MenuDesignerGenerateTests;

{
  The MENU Designer's generator (tools/EUOMenuDesigner/mdgenerate.pas; docs/menu-designer.md,
  sections 4 and 5): the file layout, the lines of each component type and each 1.6 quirk the
  generator works around, the default tracking, and the check that a text survives tokenising.
  What the lines build is checked against TMenu16 in MenuDesignerRoundTripTests.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, mdtypes, mdmodel, mdgenerate;

type
  TMenuDesignerGenerateTests = class(TTestCase)
  private
    Doc  : TMdDocument;
    Gen  : TMdGenerator;
    Got  : TStringList;
    procedure Lines(F : TMdComponent);
    procedure AssertLines(const Msg : String; const Want : array of String);
    procedure AssertHas(const Line : String);
    procedure AssertHasNot(const Line : String);
    function  IndexOf(const Line : String) : Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFileLayout;
    procedure TestForm0Sub;
    procedure TestForm0Hidden;
    procedure TestForm0Transparency;
    procedure TestFormSub;
    procedure TestFormVisible;
    procedure TestPanelAndParents;
    procedure TestText;
    procedure TestTextRightAligned;
    procedure TestTextFixedSize;
    procedure TestTextWithLiteralDollar;
    procedure TestButton;
    procedure TestEditHasNoHeight;
    procedure TestMemo;
    procedure TestCheckAlignmentInverted;
    procedure TestRadio;
    procedure TestCombo;
    procedure TestList;
    procedure TestImageCornersAndStretch;
    procedure TestImageFileOneWord;
    procedure TestShape;
    procedure TestDefaultsOnlyWhenChanged;
    procedure TestMultiWordFontName;
    procedure TestTooltipEnabledVisible;
    procedure TestCanvasLeavesOutShowing;
    procedure TestTextOnLine;
    procedure TestUnwritableTextIsWarnedAndMadeSafe;
    procedure TestColorWord;
    procedure TestDefaultColoursByName;
  end;

implementation

const
  Resets : array[0..5] of String = (
    'menu font name Arial', 'menu setdef fontsize 10', 'menu setdef fontstyle 0',
    'menu font color Black', 'menu font bgcolor BtnFace', 'menu setdef alignment 0');

procedure TMenuDesignerGenerateTests.SetUp;
begin
  Doc:=TMdDocument.Create;
  Gen:=TMdGenerator.Create;
  Got:=TStringList.Create;
end;

procedure TMenuDesignerGenerateTests.TearDown;
begin
  Got.Free;
  Gen.Free;
  Doc.Free;
end;

procedure TMenuDesignerGenerateTests.Lines(F : TMdComponent);
begin
  Got.Clear;
  Gen.Warnings.Clear;
  Gen.FormLines(Doc,F,Got);
end;

procedure TMenuDesignerGenerateTests.AssertLines(const Msg : String; const Want : array of String);
var
  Cnt : Integer;
  W   : String;
begin
  W:='';
  for Cnt:=Low(Want) to High(Want) do
    W:=W+Want[Cnt]+LineEnding;
  AssertEquals(Msg, W, Got.Text);
end;

function TMenuDesignerGenerateTests.IndexOf(const Line : String) : Integer;
begin
  Result:=Got.IndexOf(Line);
end;

procedure TMenuDesignerGenerateTests.AssertHas(const Line : String);
begin
  AssertTrue('expected "'+Line+'" in:'+LineEnding+Got.Text, IndexOf(Line)>=0);
end;

procedure TMenuDesignerGenerateTests.AssertHasNot(const Line : String);
begin
  AssertTrue('did not expect "'+Line+'" in:'+LineEnding+Got.Text, IndexOf(Line)<0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuDesignerGenerateTests.TestFileLayout;
var
  Cnt : Integer;
begin
  Doc.AddForm('opts');
  Got.Clear;
  Gen.FileLines(Doc,Got);
  AssertTrue('a comment first', Copy(Got[0],1,1)=';');
  Cnt:=0;
  while Copy(Got[Cnt],1,1)=';' do Inc(Cnt);
  AssertEquals('menu reforge mode 1.6', Got[Cnt]);
  AssertEquals('gosub menu_form0', Got[Cnt+1]);
  AssertEquals('gosub menu_opts', Got[Cnt+2]);
  AssertEquals('set #MenuButton N/A', Got[Cnt+3]);
  AssertEquals('while #MenuButton = N/A', Got[Cnt+4]);
  AssertEquals('  wait 1', Got[Cnt+5]);
  AssertEquals('halt, before any sub', 'halt', Got[Cnt+6]);
  AssertEquals('', Got[Cnt+7]);
  AssertEquals('sub menu_form0', Got[Cnt+8]);
  AssertTrue('sub bodies are indented', Copy(Got[Cnt+9],1,7)='  menu ');
  AssertTrue(IndexOf('sub menu_opts')>Cnt+8);
  AssertEquals('return', Got[Got.Count-1]);
  for Cnt:=0 to Got.Count-1 do
    AssertEquals('no trailing spaces: '+Got[Cnt], TrimRight(Got[Cnt]), Got[Cnt]);
end;

procedure TMenuDesignerGenerateTests.TestForm0Sub;
begin
  Lines(Doc.Form0);
  AssertLines('form0, nothing in it', ['menu window title EUO Menu', 'menu window size 305 180',
    'menu window color BtnFace', 'menu setdef parent form0', Resets[0], Resets[1], Resets[2],
    Resets[3], Resets[4], Resets[5], 'menu show 100 100']);
end;

procedure TMenuDesignerGenerateTests.TestForm0Hidden;
var
  F0 : TMdComponent;
begin
  F0:=Doc.Form0;
  F0.Visible:=False;
  F0.Left:=20;
  F0.Top:=30;
  Doc.Add(mdtButton,F0,0,0,'ok');
  Doc.Add(mdtText,F0,0,0,'hi');
  Lines(F0);
  AssertEquals('its children go first, so the sub can run again', 'menu delete ok', Got[0]);
  AssertEquals('menu delete hi', Got[1]);
  AssertEquals('menu setprop form0 left 20', Got[Got.Count-3]);
  AssertEquals('menu setprop form0 top 30', Got[Got.Count-2]);
  AssertEquals('menu hide', Got[Got.Count-1]);
  AssertHasNot('menu clear');
end;

procedure TMenuDesignerGenerateTests.TestForm0Transparency;
begin
  Doc.Form0.Transparency:=40;
  Doc.Form0.Color:=255;
  Lines(Doc.Form0);
  AssertHas('menu window transparent 40');
  AssertHas('menu window color Red');
end;

procedure TMenuDesignerGenerateTests.TestFormSub;
var
  F : TMdComponent;
begin
  F:=Doc.AddForm('opts');
  F.Left:=400;
  F.Top:=200;
  F.Width:=200;
  F.Height:=110;
  F.Text:='Options';
  Lines(F);
  AssertLines('a hidden form', ['menu delete opts', 'menu form opts 400 200 200 110 Options',
    'menu setprop opts width 200', 'menu setprop opts height 110', Resets[0], Resets[1],
    Resets[2], Resets[3], Resets[4], Resets[5]]);
end;

procedure TMenuDesignerGenerateTests.TestFormVisible;
var
  F : TMdComponent;
begin
  F:=Doc.AddForm('opts');
  F.Visible:=True;
  F.Color:=65280;
  F.Text:='';
  Lines(F);
  AssertEquals('an empty title', 'menu form opts 400 200 200 100', Got[1]);
  AssertHas('menu setprop opts color 65280');
  AssertEquals('menu setprop opts visible #true', Got[Got.Count-1]);
end;

procedure TMenuDesignerGenerateTests.TestPanelAndParents;
var
  P, Q : TMdComponent;
begin
  P:=Doc.Add(mdtPanel,Doc.Form0,10,10,'p');
  P.Width:=180;
  P.Height:=50;
  P.Color:=255;
  Doc.Add(mdtButton,P,5,5,'a');
  Q:=Doc.Add(mdtPanel,P,5,30,'q');
  Doc.Add(mdtButton,Q,0,0,'b');
  Doc.Add(mdtButton,P,100,5,'c');
  Doc.Add(mdtButton,Doc.Form0,10,70,'d');
  Lines(Doc.Form0);
  AssertTrue('the panel takes the default colour', IndexOf('menu font bgcolor Red')<IndexOf('menu panel p 10 10 180 50'));
  AssertTrue('a goes into p with no setdef parent',
    IndexOf('menu setdef parent p')>IndexOf('menu button a 5 5 80 25 a'));
  AssertTrue('q, a panel in a panel', IndexOf('menu panel q 5 30 120 60')>0);
  AssertTrue('back to p after q', IndexOf('menu setdef parent p')<IndexOf('menu button c 100 5 80 25 c'));
  AssertTrue(IndexOf('menu setdef parent p')>IndexOf('menu button b 0 0 80 25 b'));
  AssertTrue('back to form0 for d', IndexOf('menu setdef parent form0')<>Got.LastIndexOf('menu setdef parent form0'));
  AssertTrue(Got.LastIndexOf('menu setdef parent form0')<IndexOf('menu button d 10 70 80 25 d'));
  AssertTrue('the button after the red panel gets the default colour back',
    Got.LastIndexOf('menu font bgcolor BtnFace')<IndexOf('menu button a 5 5 80 25 a'));
  AssertHasNot('menu pushdef');
  AssertHasNot('menu popdef');
end;

procedure TMenuDesignerGenerateTests.TestText;
var
  T : TMdComponent;
begin
  T:=Doc.Add(mdtText,Doc.Form0,10,20,'t');
  T.Text:='Two'#13#10'lines';
  Lines(Doc.Form0);
  AssertHas('menu text t 10 20 Two$lines');
  AssertEquals(0, Gen.Warnings.Count);
end;

procedure TMenuDesignerGenerateTests.TestTextRightAligned;
var
  T : TMdComponent;
begin
  T:=Doc.Add(mdtText,Doc.Form0,50,20,'t');
  T.Alignment:=1;
  Lines(Doc.Form0);
  AssertTrue(IndexOf('menu setdef alignment 1')<IndexOf('menu text t 50 20 t'));
  AssertEquals('placed after 1.6 fitted it to its right edge', IndexOf('menu text t 50 20 t')+1,
    IndexOf('menu setprop t left 50'));
end;

procedure TMenuDesignerGenerateTests.TestTextFixedSize;
var
  T : TMdComponent;
begin
  T:=Doc.Add(mdtText,Doc.Form0,0,0,'t');
  Lines(Doc.Form0);
  AssertHasNot('menu setprop t width 40');
  T.FixedW:=True;
  T.Width:=90;
  T.FixedH:=True;
  T.Height:=30;
  Lines(Doc.Form0);
  AssertHas('menu setprop t width 90');
  AssertHas('menu setprop t height 30');
end;

procedure TMenuDesignerGenerateTests.TestTextWithLiteralDollar;
var
  T : TMdComponent;
begin
  T:=Doc.Add(mdtText,Doc.Form0,5,5,'t');
  T.Text:='Cost $5';
  Lines(Doc.Form0);
  AssertEquals('created empty, given its text with setprop', IndexOf('menu text t 5 5')+1,
    IndexOf('menu setprop t text Cost $5'));
  AssertEquals(0, Gen.Warnings.Count);
  T.Text:='$5'#13#10'each';
  Lines(Doc.Form0);
  AssertEquals('a $ and a line break cannot both be written', 1, Gen.Warnings.Count);
end;

procedure TMenuDesignerGenerateTests.TestButton;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,10,20,'ok');
  B.Text:='Cost $5';
  Lines(Doc.Form0);
  AssertHas('menu button ok 10 20 80 25 Cost $5');
  AssertEquals('a button''s $ is literal', 0, Gen.Warnings.Count);
end;

procedure TMenuDesignerGenerateTests.TestEditHasNoHeight;
var
  E : TMdComponent;
begin
  E:=Doc.Add(mdtEdit,Doc.Form0,10,20,'e');
  E.Text:='250';
  Lines(Doc.Form0);
  AssertHas('menu edit e 10 20 100 250');
  AssertTrue(Pos('menu setprop e height',Got.Text)=0);
  E.FixedH:=True;
  E.Height:=40;
  Lines(Doc.Form0);
  AssertHas('menu setprop e height 40');
end;

procedure TMenuDesignerGenerateTests.TestMemo;
var
  M : TMdComponent;
begin
  M:=Doc.Add(mdtMemo,Doc.Form0,0,0,'m');
  M.Text:='a'#13#10'b';
  Lines(Doc.Form0);
  AssertHas('menu memo m 0 0 150 60 a$b');
end;

procedure TMenuDesignerGenerateTests.TestCheckAlignmentInverted;
var
  C : TMdComponent;
begin
  C:=Doc.Add(mdtCheck,Doc.Form0,10,10,'loot');
  C.Checked:=True;
  C.Alignment:=1;
  C.Text:='Loot corpses';
  Lines(Doc.Form0);
  AssertTrue('text on the left: 1.6 wants default alignment 1',
    IndexOf('menu setdef alignment 1')<IndexOf('menu check loot 10 10 100 20 #true Loot corpses'));
end;

procedure TMenuDesignerGenerateTests.TestRadio;
var
  R : TMdComponent;
begin
  R:=Doc.Add(mdtRadio,Doc.Form0,5,5,'fast');
  Doc.Add(mdtRadio,Doc.Form0,5,25,'safe');
  Doc.SetChecked(R,True);
  Lines(Doc.Form0);
  AssertHas('menu radio fast 5 5 100 20 #true fast');
  AssertHas('menu radio safe 5 25 100 20 #false safe');
end;

procedure TMenuDesignerGenerateTests.TestCombo;
var
  C : TMdComponent;
begin
  C:=Doc.Add(mdtCombo,Doc.Form0,10,60,'bag');
  C.Width:=150;
  C.Items.Add('Backpack');
  C.Items.Add('Bank box');
  C.Selected:=2;
  Lines(Doc.Form0);
  AssertHas('menu combo create bag 10 60 150');
  AssertEquals(IndexOf('menu combo create bag 10 60 150')+1, IndexOf('menu combo add bag Backpack'));
  AssertHas('menu combo add bag Bank box');
  AssertEquals('select takes the 1-based index (1.6 stores i-1)',
    IndexOf('menu combo add bag Bank box')+1, IndexOf('menu combo select bag 2'));
  C.Selected:=0;
  Lines(Doc.Form0);
  AssertTrue(Pos('select',Got.Text)=0);
end;

procedure TMenuDesignerGenerateTests.TestList;
var
  L : TMdComponent;
begin
  L:=Doc.Add(mdtList,Doc.Form0,0,0,'l');
  L.Items.Add('one');
  L.Selected:=1;
  Lines(Doc.Form0);
  AssertHas('menu list create l 0 0 100 80');
  AssertHas('menu list add l one');
  AssertHas('menu list select l 1');
end;

procedure TMenuDesignerGenerateTests.TestImageCornersAndStretch;
var
  I  : TMdComponent;
  Op : TMdDrawOp;
begin
  I:=Doc.Add(mdtImage,Doc.Form0,10,10,'img');
  I.BitmapW:=40;
  I.BitmapH:=20;
  Op:=Default(TMdDrawOp);
  Op.Kind:=dkRectangle;
  Op.X1:=2; Op.Y1:=3; Op.X2:=30; Op.Y2:=15;
  Op.Color:=255;
  Op.Fill:=True;
  Op.PenWidth:=2;
  I.AddOp(Op);
  Op.Kind:=dkLine;
  Op.Color:=-16777201;
  I.AddOp(Op);
  Op.Kind:=dkPix;
  I.AddOp(Op);
  I.Stretch:=True;
  I.Width:=80;
  I.Height:=40;
  Lines(Doc.Form0);
  AssertHas('menu image create img 10 10 40 20');
  AssertHas('menu image rectangle img 2 3 30 15 Red 1 2');
  AssertHas('menu image line img 2 3 30 15 BtnFace 2');
  AssertHas('menu image pix img 2 3 BtnFace');
  AssertEquals('stretched after drawing', IndexOf('menu image pix img 2 3 BtnFace')+1,
    IndexOf('menu image pos img 10 10 80 40'));
  Op.Kind:=dkEllipse;
  Op.X2:=-1;
  I.AddOp(Op);
  Lines(Doc.Form0);
  AssertEquals('a negative corner draws nothing in 1.6', 1, Gen.Warnings.Count);
end;

procedure TMenuDesignerGenerateTests.TestImageFileOneWord;
var
  I  : TMdComponent;
  Op : TMdDrawOp;
begin
  I:=Doc.Add(mdtImage,Doc.Form0,0,0,'img');
  Op:=Default(TMdDrawOp);
  Op.Kind:=dkFile;
  Op.FileName:='C:\pics\logo.bmp';
  I.AddOp(Op);
  Op.FileName:='C:\my pics\logo.bmp';
  I.AddOp(Op);
  Lines(Doc.Form0);
  AssertHas('menu image file img 0 0 C:\pics\logo.bmp');
  AssertTrue('the name with a space is left out', Pos('my pics',Got.Text)=0);
  AssertEquals(1, Gen.Warnings.Count);
end;

procedure TMenuDesignerGenerateTests.TestShape;
var
  S : TMdComponent;
begin
  S:=Doc.Add(mdtShape,Doc.Form0,10,10,'s');
  S.ShapeStyle:=2;
  S.LineOn:=True;
  S.LineWidth:=3;
  S.LineColor:=-16777201;
  S.FillOn:=True;
  S.FillColor:=255;
  Lines(Doc.Form0);
  AssertHas('menu shape s 10 10 50 50 2 0 3 BtnFace 7 Red');
  S.LineOn:=False;
  S.FillOn:=False;
  Lines(Doc.Form0);
  AssertHas('menu shape s 10 10 50 50 2 1 3 BtnFace 0 Red');
end;

procedure TMenuDesignerGenerateTests.TestDefaultsOnlyWhenChanged;
var
  B : TMdComponent;
begin
  Doc.Add(mdtButton,Doc.Form0,0,0,'a');
  B:=Doc.Add(mdtButton,Doc.Form0,0,30,'b');
  B.FontStyle:=1;
  B.FontSize:=12;
  Doc.Add(mdtButton,Doc.Form0,0,60,'c');
  Lines(Doc.Form0);
  AssertEquals('the font name is set once', IndexOf('menu font name Arial'),
    Got.LastIndexOf('menu font name Arial'));
  AssertTrue(IndexOf('menu setdef fontstyle 1')<IndexOf('menu button b 0 30 80 25 b'));
  AssertTrue(IndexOf('menu setdef fontsize 12')<IndexOf('menu button b 0 30 80 25 b'));
  AssertTrue('back to plain for c', Got.LastIndexOf('menu setdef fontstyle 0')>IndexOf('menu button b 0 30 80 25 b'));
  AssertTrue(Got.LastIndexOf('menu setdef fontsize 10')<IndexOf('menu button c 0 60 80 25 c'));
  AssertEquals('a needs no setdef of its own', IndexOf(Resets[5])+1, IndexOf('menu button a 0 0 80 25 a'));
end;

procedure TMenuDesignerGenerateTests.TestMultiWordFontName;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'a');
  B.FontName:='Courier New';
  Lines(Doc.Form0);
  AssertHas('menu font name Courier New');
end;

procedure TMenuDesignerGenerateTests.TestTooltipEnabledVisible;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'ok');
  B.Tooltip:='Save and close';
  B.Enabled:=False;
  B.Visible:=False;
  Lines(Doc.Form0);
  AssertHas('menu setprop ok tooltip Save and close');
  AssertHas('menu setprop ok enabled #false');
  AssertHas('menu setprop ok visible #false');
end;

procedure TMenuDesignerGenerateTests.TestCanvasLeavesOutShowing;
var
  F : TMdComponent;
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'ok');
  B.Visible:=False;
  Got.Clear;
  Gen.FormLines(Doc,Doc.Form0,Got,True);
  AssertHasNot('menu show 100 100');
  AssertHasNot('menu setprop ok visible #false');
  F:=Doc.AddForm('opts');
  F.Visible:=True;
  Got.Clear;
  Gen.FormLines(Doc,F,Got,True);
  AssertHasNot('menu setprop opts visible #true');
end;

procedure TMenuDesignerGenerateTests.TestTextOnLine;
var
  W, S : String;
begin
  AssertTrue(TextOnLine('Hello world',False,W,S));
  AssertTrue('a comma inside a word', TextOnLine('Hello, world',False,W,S));
  AssertTrue('a last comma', TextOnLine('Hello ,',False,W,S));
  AssertTrue('50%', TextOnLine('50% done',False,W,S));
  AssertTrue('a lone %', TextOnLine('% done',False,W,S));
  AssertFalse('two spaces', TextOnLine('a  b',False,W,S));
  AssertEquals('a b', S);
  AssertFalse('a leading space', TextOnLine(' a',False,W,S));
  AssertFalse('a variable', TextOnLine('Hi %name',False,W,S));
  AssertFalse('a system variable', TextOnLine('Gold: #gold',False,W,S));
  AssertFalse('a comment', TextOnLine('a ;b c',False,W,S));
  AssertEquals('a', S);
  AssertFalse('a lone dot glues', TextOnLine('a . b',False,W,S));
  AssertEquals('ab', S);
  AssertFalse('a lone comma glues', TextOnLine('a , b',False,W,S));
  AssertFalse('a tab', TextOnLine('a'#9'b',False,W,S));
  AssertTrue('a line break as $', TextOnLine('a'#13#10'b',True,W,S));
  AssertEquals('a$b', W);
  AssertFalse('a $ that should stay', TextOnLine('$5',True,W,S));
  AssertFalse('a line break where $ is literal', TextOnLine('a'#13#10'b',False,W,S));
  AssertEquals('a b', W);
  AssertTrue('an empty text', TextOnLine('',False,W,S));
end;

procedure TMenuDesignerGenerateTests.TestUnwritableTextIsWarnedAndMadeSafe;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'ok');
  B.Text:='. Hi %name ;)';
  Lines(Doc.Form0);
  AssertHas('menu button ok 0 0 80 25 Hi');
  AssertEquals(1, Gen.Warnings.Count);
  AssertTrue(Gen.Warnings.Objects[0]=B);
  AssertTrue(Pos('ok: text:',Gen.Warnings[0])=1);
  AssertEquals('a b', SafeText('a  , b'));
end;

procedure TMenuDesignerGenerateTests.TestColorWord;
begin
  AssertEquals('BtnFace', ColorWord(-16777201));
  AssertEquals('Window', ColorWord(-16777211));
  AssertEquals('MenuBar, the last system colour Delphi 7 has', 'MenuBar', ColorWord(-16777186));
  AssertEquals('Red', ColorWord(255));
  AssertEquals('Black', ColorWord(0));
  AssertEquals('Silver', ColorWord(12632256));
  AssertEquals('MoneyGreen', ColorWord(12639424));
  AssertEquals('a colour with no name', '12345', ColorWord(12345));
  AssertEquals('a system colour past Delphi 7''s', '-16777185', ColorWord(-16777185));
end;

// The defaults' colours by name with menu font color / bgcolor; setdef takes numbers only, and
// keeps a system colour no name is shared for.
procedure TMenuDesignerGenerateTests.TestDefaultColoursByName;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'a');
  B.FontColor:=255;
  B.Color:=65535;
  B:=Doc.Add(mdtButton,Doc.Form0,0,30,'b');
  B.FontColor:=255;
  B.Color:=12345;
  B:=Doc.Add(mdtButton,Doc.Form0,0,60,'c');
  B.FontColor:=255;
  B.Color:=-16777185;
  Lines(Doc.Form0);
  AssertTrue(IndexOf('menu font color Red')<IndexOf('menu button a 0 0 80 25 a'));
  AssertTrue(IndexOf('menu font bgcolor Yellow')<IndexOf('menu button a 0 0 80 25 a'));
  AssertTrue('a number where there is no name', IndexOf('menu font bgcolor 12345')<IndexOf('menu button b 0 30 80 25 b'));
  AssertTrue(IndexOf('menu font bgcolor 12345')>IndexOf('menu button a 0 0 80 25 a'));
  AssertTrue('setdef for a system colour without a name',
    IndexOf('menu setdef color -16777185')<IndexOf('menu button c 0 60 80 25 c'));
  AssertTrue(Pos('menu setdef fontcolor',Got.Text)=0);
end;

initialization
  RegisterTest(TMenuDesignerGenerateTests);
end.
