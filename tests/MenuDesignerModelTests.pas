unit MenuDesignerModelTests;

{
  The MENU Designer's type table and document model (tools/EUOMenuDesigner/mdtypes.pas,
  mdmodel.pas; docs/menu-designer.md, sections 3.3 and 3.4): names, containment, radio
  groups, deep copies, and which properties each type has according to EuoMenu16's own table.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoMenu16, mdtypes, mdmodel;

type
  TMenuDesignerModelTests = class(TTestCase)
  private
    Doc : TMdDocument;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNewDocumentHasForm0;
    procedure TestUniqueNames;
    procedure TestNameRules;
    procedure TestNamesUniqueAcrossForms;
    procedure TestForm0StaysFirst;
    procedure TestForm0CannotBeRemoved;
    procedure TestRemoveFreesChildren;
    procedure TestContainment;
    procedure TestRadioGroupsByParent;
    procedure TestMovingACheckedRadio;
    procedure TestCloneIsDeepAndEqual;
    procedure TestPropertiesFromEuoMenu16;
    procedure TestEveryKindHasARow;
    procedure TestTypeByName;
  end;

implementation

procedure TMenuDesignerModelTests.SetUp;
begin
  Doc:=TMdDocument.Create;
end;

procedure TMenuDesignerModelTests.TearDown;
begin
  Doc.Free;
end;

procedure TMenuDesignerModelTests.TestNewDocumentHasForm0;
var
  F0 : TMdComponent;
begin
  AssertEquals(1, Doc.FormCount);
  F0:=Doc.Form0;
  AssertEquals('form0', F0.Name);
  AssertTrue(F0.IsForm0);
  AssertEquals('EUO Menu', F0.Text);
  AssertEquals(100, F0.Left);
  AssertEquals(305, F0.Width);
  AssertEquals(180, F0.Height);
  AssertEquals(-1, F0.Transparency);
  AssertTrue('form0 is shown', F0.Visible);
end;

procedure TMenuDesignerModelTests.TestUniqueNames;
var
  B1, B2 : TMdComponent;
begin
  B1:=Doc.Add(mdtButton,Doc.Form0,10,10);
  B2:=Doc.Add(mdtButton,Doc.Form0,10,40);
  AssertEquals('button1', B1.Name);
  AssertEquals('button2', B2.Name);
  AssertEquals('a new button shows its name', 'button1', B1.Text);
  AssertEquals('form1', Doc.AddForm('').Name);
end;

procedure TMenuDesignerModelTests.TestNameRules;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'ok');
  AssertEquals('', Doc.NameProblem('cancel',nil));
  AssertEquals('its own name is fine', '', Doc.NameProblem('OK',B));
  AssertTrue('empty', Doc.NameProblem('',nil)<>'');
  AssertTrue('two words', Doc.NameProblem('my button',nil)<>'');
  AssertTrue('a comment', Doc.NameProblem(';x',nil)<>'');
  AssertTrue('a variable', Doc.NameProblem('%x',nil)<>'');
  AssertTrue('a system variable', Doc.NameProblem('#true',nil)<>'');
  AssertTrue('a glue operator', Doc.NameProblem('.',nil)<>'');
  AssertTrue('form0 is reserved', Doc.NameProblem('form0',nil)<>'');
  AssertEquals('form0 may keep its name', '', Doc.NameProblem('form0',Doc.Form0));
  AssertEquals('"%" alone is not a variable', '', Doc.NameProblem('%',nil));
end;

procedure TMenuDesignerModelTests.TestNamesUniqueAcrossForms;
var
  F : TMdComponent;
begin
  Doc.Add(mdtButton,Doc.Form0,0,0,'ok');
  F:=Doc.AddForm('opts');
  AssertTrue('a name of another form''s control', Doc.NameProblem('ok',nil)<>'');
  AssertTrue('case does not matter', Doc.NameProblem('OK',nil)<>'');
  AssertTrue('a form''s name', Doc.NameProblem('opts',nil)<>'');
  AssertEquals('button1 is free', 'button1', Doc.Add(mdtButton,F,0,0).Name);
  AssertTrue('names are found in every form', Doc.FindName('button1')<>nil);
end;

procedure TMenuDesignerModelTests.TestForm0StaysFirst;
var
  A, B : TMdComponent;
begin
  A:=Doc.AddForm('a');
  B:=Doc.AddForm('b');
  Doc.MoveForm(B,0);
  AssertTrue(Doc.Form(0).IsForm0);
  AssertTrue(Doc.Form(1)=B);
  AssertTrue(Doc.Form(2)=A);
  Doc.MoveForm(Doc.Form0,2);
  AssertTrue(Doc.Form(0).IsForm0);
  AssertFalse('a new form starts hidden, as in 1.6', A.Visible);
end;

procedure TMenuDesignerModelTests.TestForm0CannotBeRemoved;
begin
  Doc.Remove(Doc.Form0);
  AssertEquals(1, Doc.FormCount);
  AssertEquals('form0', Doc.Form0.Name);
end;

procedure TMenuDesignerModelTests.TestRemoveFreesChildren;
var
  F, P : TMdComponent;
begin
  F:=Doc.AddForm('opts');
  P:=Doc.Add(mdtPanel,F,0,0,'box');
  Doc.Add(mdtCheck,P,5,5,'loot');
  Doc.Remove(F);
  AssertEquals(1, Doc.FormCount);
  AssertTrue(Doc.FindName('loot')=nil);
  AssertTrue(Doc.FindName('box')=nil);
end;

procedure TMenuDesignerModelTests.TestContainment;
var
  P1, P2, B : TMdComponent;
begin
  P1:=Doc.Add(mdtPanel,Doc.Form0,0,0,'p1');
  P2:=Doc.Add(mdtPanel,P1,0,0,'p2');
  B:=Doc.Add(mdtButton,Doc.Form0,0,0,'b');
  AssertTrue('into a panel', Doc.CanMoveTo(B,P2));
  AssertFalse('into a button', Doc.CanMoveTo(P2,B));
  AssertFalse('into itself', Doc.CanMoveTo(P1,P1));
  AssertFalse('into its own child', Doc.CanMoveTo(P1,P2));
  AssertFalse('a form goes nowhere', Doc.CanMoveTo(Doc.Form0,P1));
  Doc.MoveTo(B,P2);
  AssertTrue(B.Parent=P2);
  AssertEquals(0, Doc.Form0.Children.IndexOf(P1));
  AssertEquals(1, Doc.Form0.ChildCount);
  AssertTrue(B.FormOf=Doc.Form0);
end;

procedure TMenuDesignerModelTests.TestRadioGroupsByParent;
var
  P, R1, R2, R3 : TMdComponent;
begin
  R1:=Doc.Add(mdtRadio,Doc.Form0,0,0,'r1');
  R2:=Doc.Add(mdtRadio,Doc.Form0,0,20,'r2');
  P:=Doc.Add(mdtPanel,Doc.Form0,0,50,'p');
  R3:=Doc.Add(mdtRadio,P,0,0,'r3');
  Doc.SetChecked(R1,True);
  Doc.SetChecked(R3,True);
  Doc.SetChecked(R2,True);
  AssertFalse('same parent: unchecked', R1.Checked);
  AssertTrue(R2.Checked);
  AssertTrue('another parent: kept', R3.Checked);
end;

procedure TMenuDesignerModelTests.TestMovingACheckedRadio;
var
  P, R1, R2 : TMdComponent;
begin
  R1:=Doc.Add(mdtRadio,Doc.Form0,0,0,'r1');
  P:=Doc.Add(mdtPanel,Doc.Form0,0,50,'p');
  R2:=Doc.Add(mdtRadio,P,0,0,'r2');
  Doc.SetChecked(R1,True);
  Doc.SetChecked(R2,True);
  Doc.MoveTo(R1,P);
  AssertTrue(R1.Checked);
  AssertFalse(R2.Checked);
end;

procedure TMenuDesignerModelTests.TestCloneIsDeepAndEqual;
var
  Dup  : TMdDocument;
  C    : TMdComponent;
  Op   : TMdDrawOp;
begin
  C:=Doc.Add(mdtCombo,Doc.Form0,5,5,'bag');
  C.Items.Add('Backpack');
  C.Selected:=1;
  C:=Doc.Add(mdtImage,Doc.AddForm('pic'),0,0,'img');
  Op:=Default(TMdDrawOp);
  Op.Kind:=dkLine;
  Op.X2:=10;
  Op.PenWidth:=1;
  C.AddOp(Op);
  Dup:=Doc.Clone;
  try
    AssertEquals(Doc.Dump, Dup.Dump);
    Dup.FindName('bag').Items.Add('Bank');
    Dup.FindName('img').Ops[0].X2:=20;
    AssertEquals('the copy owns its items', 1, Doc.FindName('bag').Items.Count);
    AssertEquals('the copy owns its drawing', 10, Doc.FindName('img').Ops[0].X2);
    AssertTrue(Dup.FindName('img').Parent=Dup.Form(1));
  finally
    Dup.Free;
  end;
end;

procedure TMenuDesignerModelTests.TestPropertiesFromEuoMenu16;
begin
  AssertTrue(MdTypeHasProp(mdtEdit,'text'));
  AssertTrue(MdTypeHasProp(mdtMemo,'fontname'));
  AssertTrue(MdTypeHasProp(mdtForm,'text'));
  AssertTrue(MdTypeHasProp(mdtForm,'width'));
  AssertFalse('forms have no parent', MdTypeHasProp(mdtForm,'parent'));
  AssertFalse('images have no colour', MdTypeHasProp(mdtImage,'color'));
  AssertFalse('shapes are images', MdTypeHasProp(mdtShape,'color'));
  AssertFalse(MdTypeHasProp(mdtPanel,'fontname'));
  AssertTrue(MdTypeHasProp(mdtRadio,'checked'));
  AssertFalse(MdTypeHasProp(mdtButton,'checked'));
  AssertFalse(MdTypeHasProp(mdtCombo,'text'));
end;

// Every property in EuoMenu16's table has a row in the designer's, and every MT_* kind but
// the defaults object has a type row.
procedure TMenuDesignerModelTests.TestEveryKindHasARow;
var
  Cnt   : Integer;
  Name  : String;
  PType : Integer;
  Mask  : Integer;
  Kinds : Integer;
  T     : TMdType;
begin
  for Cnt:=0 to Menu16PropCount-1 do
  begin
    Menu16PropRow(Cnt,Name,PType,Mask);
    AssertTrue(Name+' has a row', MdPropIndex(Name)>=0);
  end;
  Kinds:=0;
  for T:=Low(TMdType) to High(TMdType) do
    Kinds:=Kinds or MdTypeRows[T].Kind;
  AssertEquals('every control kind', MT_FORM or MT_PANEL or MT_TEXT or MT_BUTTON or MT_EDIT or
    MT_CHECK or MT_RADIO or MT_COMBO or MT_LIST or MT_IMAGE or MT_MEMO, Kinds);
end;

procedure TMenuDesignerModelTests.TestTypeByName;
var
  T : TMdType;
begin
  AssertTrue(MdTypeByName('Shape',T));
  AssertTrue(T=mdtShape);
  AssertFalse(MdTypeByName('slider',T));
end;

initialization
  RegisterTest(TMenuDesignerModelTests);
end.
