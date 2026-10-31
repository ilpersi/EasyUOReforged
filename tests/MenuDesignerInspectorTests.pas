unit MenuDesignerInspectorTests;

{
  The MENU Designer's inspector (tools/EUOMenuDesigner/mdinspector.pas) in a real window: a value
  typed into a cell reaches the model on Enter, and before the inspector shows another
  component; rebuilding the rows does not turn the cell editor's leftover text into an edit.
  (This LCL never calls TValueListEditor.OnValidate, which the first version relied on: typed
  values were lost.)
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Grids, fpcunit, testregistry, mdtypes, mdmodel,
  mdinspector;

type
  TMenuDesignerInspectorTests = class(TTestCase)
  private
    Win      : TForm;
    Insp     : TMdInspector;
    Doc      : TMdDocument;
    Current  : TMdComponent;
    Befores  : Integer;
    Problems : TStringList;
    procedure BeforeChange(Sender : TObject);
    procedure AfterChange(F : TMdComponent);
    procedure Problem(const S : String);
    procedure Settle;
    procedure TypeInto(ARow : Integer; const Text : String);
    procedure PressEnter;
    function  RowOf(const Caption : String) : Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEnterApplies;
    procedure TestOneUndoStepPerEdit;
    procedure TestSwitchingComponentsKeepsTheEdit;
    procedure TestRebuildingTheRowsChangesNothing;
    procedure TestARefusedValueIsShownAsItWas;
    procedure TestTheLinesDialogShowsItsButtons;
    procedure TestRowsAreInAlphabeticalOrder;
  end;

implementation

procedure TMenuDesignerInspectorTests.SetUp;
begin
  Application.Initialize;
  Problems:=TStringList.Create;
  Doc:=TMdDocument.Create;
  Win:=TForm.CreateNew(nil);
  Win.SetBounds(50,50,320,420);
  Insp:=TMdInspector.Create(Win);
  Insp.Parent:=Win;
  Insp.Align:=alClient;
  Insp.OnBeforeChange:=BeforeChange;
  Insp.OnAfterChange:=AfterChange;
  Insp.OnMessage:=Problem;
  Win.Show;
  Current:=Doc.Form0;
  Insp.ShowComponent(Doc,Current);
  Settle;
end;

procedure TMenuDesignerInspectorTests.TearDown;
begin
  Win.Free;
  Settle;
  Doc.Free;
  Problems.Free;
end;

procedure TMenuDesignerInspectorTests.BeforeChange(Sender : TObject);
begin
  Inc(Befores);
end;

// As the main window does: the model changed, the inspector shows the selection again.
procedure TMenuDesignerInspectorTests.AfterChange(F : TMdComponent);
begin
  Insp.ShowComponent(Doc,Current);
end;

procedure TMenuDesignerInspectorTests.Problem(const S : String);
begin
  Problems.Add(S);
end;

procedure TMenuDesignerInspectorTests.Settle;
var
  Cnt : Integer;
begin
  for Cnt:=1 to 5 do
    Application.ProcessMessages;
end;

function TMenuDesignerInspectorTests.RowOf(const Caption : String) : Integer;
begin
  Result:=Insp.Strings.IndexOfName(Caption)+Insp.FixedRows;
  AssertTrue(Caption+' is a row', Result>=Insp.FixedRows);
end;

// What the user does: the cell gets the editor, and the text is typed into it.
procedure TMenuDesignerInspectorTests.TypeInto(ARow : Integer; const Text : String);
begin
  Insp.Col:=1;
  Insp.Row:=ARow;
  Insp.EditorMode:=True;
  AssertTrue('the cell has an editor', Insp.Editor is TCustomEdit);
  TCustomEdit(Insp.Editor).Text:=Text;
end;

procedure TMenuDesignerInspectorTests.PressEnter;
var
  Key : Char;
begin
  Key:=#13;
  Insp.EditorKeyPress(Insp.Editor,Key);
  Settle;
end;

procedure TMenuDesignerInspectorTests.TestEnterApplies;
begin
  TypeInto(RowOf('Title'),'Hello');
  PressEnter;
  AssertEquals('Hello', Doc.Form0.Text);
  AssertEquals('the row shows it', 'Hello', Insp.Values['Title']);
end;

procedure TMenuDesignerInspectorTests.TestOneUndoStepPerEdit;
begin
  TypeInto(RowOf('Width (inside)'),'250');
  PressEnter;
  AssertEquals(250, Doc.Form0.Width);
  AssertEquals('one change, one undo step', 1, Befores);
end;

procedure TMenuDesignerInspectorTests.TestSwitchingComponentsKeepsTheEdit;
var
  B : TMdComponent;
begin
  B:=Doc.Add(mdtButton,Doc.Form0,10,10,'ok');
  TypeInto(RowOf('Tooltip'),'The main window');
  // no Enter: another component is selected (a click on the canvas)
  Current:=B;
  Insp.ShowComponent(Doc,B);
  Settle;
  AssertEquals('The main window', Doc.Form0.Tooltip);
  AssertEquals('the button is untouched', '', B.Tooltip);
  AssertEquals('ok', Insp.Values['Name']);
end;

procedure TMenuDesignerInspectorTests.TestRebuildingTheRowsChangesNothing;
begin
  TypeInto(RowOf('Title'),'Main');
  PressEnter;
  Insp.ShowComponent(Doc,Current);
  Settle;
  Insp.ShowComponent(Doc,Current);
  Settle;
  AssertEquals('form0', Doc.Form0.Name);
  AssertEquals('Main', Doc.Form0.Text);
  AssertEquals('no complaint: '+Problems.Text, 0, Problems.Count);
  AssertEquals(1, Befores);
end;

procedure TMenuDesignerInspectorTests.TestARefusedValueIsShownAsItWas;
begin
  TypeInto(RowOf('Width (inside)'),'wide');
  PressEnter;
  AssertEquals(305, Doc.Form0.Width);
  AssertEquals(1, Problems.Count);
  AssertEquals('305', Insp.Values['Width (inside)']);
end;

// The dialog behind a cell's '...' button (text, items, drawing), shown: OK and Cancel lie
// inside every parent up to the window, so neither is cut off. (They were placed from sizes the
// window did not have yet and ended past its right edge: what was typed could not be kept.)
procedure TMenuDesignerInspectorTests.TestTheLinesDialogShowsItsButtons;
var
  L      : TStringList;
  F      : TForm;
  M      : TMemo;
  Cnt    : Integer;
  B      : TButton;
  OK     : TButton;
  Cancel : TButton;
  C      : TControl;
begin
  L:=TStringList.Create;
  F:=nil;
  try
    L.Add('one');
    F:=LinesDialog('Text of text1','One line per line of text.',L,M);
    F.Show;
    Settle;
    AssertEquals('the memo has the lines', 'one', Trim(M.Lines.Text));
    OK:=nil;
    Cancel:=nil;
    for Cnt:=0 to F.ComponentCount-1 do
      if F.Components[Cnt] is TButton then
      begin
        B:=TButton(F.Components[Cnt]);
        if B.Caption='OK' then OK:=B else if B.Caption='Cancel' then Cancel:=B;
        AssertTrue(B.Caption+' is visible', B.IsVisible);
        C:=B;
        while C<>F do
        begin
          AssertTrue(Format('%s is inside %s: %d,%d-%d,%d in %dx%d',[B.Caption,C.Parent.ClassName,
            C.Left,C.Top,C.Left+C.Width,C.Top+C.Height,C.Parent.ClientWidth,C.Parent.ClientHeight]),
            (C.Left>=0) and (C.Top>=0) and (C.Left+C.Width<=C.Parent.ClientWidth) and
            (C.Top+C.Height<=C.Parent.ClientHeight));
          C:=C.Parent;
        end;
      end;
    AssertTrue('there is an OK and a Cancel', (OK<>nil) and (Cancel<>nil));
    AssertTrue('OK keeps the lines', OK.ModalResult=mrOK);
    AssertTrue('Cancel drops them', Cancel.ModalResult=mrCancel);
    AssertTrue('OK is left of Cancel', OK.Left+OK.Width<=Cancel.Left);
  finally
    F.Free;
    L.Free;
  end;
end;

// Every kind of component, form0 and another form among them, lists its rows by caption.
procedure TMenuDesignerInspectorTests.TestRowsAreInAlphabeticalOrder;
var
  T   : TMdType;
  C   : TMdComponent;
  Cnt : Integer;

  procedure Check(Comp : TMdComponent);
  var
    I : Integer;
  begin
    Current:=Comp;
    Insp.ShowComponent(Doc,Comp);
    Settle;
    AssertTrue(Comp.Name+' has rows', Insp.Strings.Count>2);
    for I:=1 to Insp.Strings.Count-1 do
      AssertTrue(Format('%s: "%s" before "%s"',[Comp.Name,Insp.Strings.Names[I-1],Insp.Strings.Names[I]]),
        CompareText(Insp.Strings.Names[I-1],Insp.Strings.Names[I])<=0);
  end;

begin
  Check(Doc.Form0);
  Check(Doc.AddForm('opts'));
  Cnt:=0;
  for T:=Low(TMdType) to High(TMdType) do
    if T<>mdtForm then
    begin
      C:=Doc.Add(T,Doc.Form0,10,10+20*Cnt,'');
      Inc(Cnt);
      Check(C);
    end;
end;

initialization
  RegisterTest(TMenuDesignerInspectorTests);
end.
