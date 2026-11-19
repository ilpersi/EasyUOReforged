unit EuoOutlineViewTests;

{
  Tests for easyuo\euoutline.pas -- the outline panel left of the editor: the tree it fills
  from an editor's text, its filter and A-Z order, following the caret, the jump, keeping the
  open subs per editor, waiting for typing to stop before a rebuild, and an editor freed under
  it. On a form that is never shown and editors without a window, as EuoFindTests does.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, ComCtrls, Graphics, fpcunit, testregistry,
  SynEdit, euoutline;

type
  TEuoOutlineViewTests = class(TTestCase)
  private
    FForm   : TForm;
    FPanel  : TPanel;
    FView   : TEuoOutlineView;
    FEds    : TList;
    FJumpEd : TSynEdit;
    FJumpTo : Integer;
    function  NewEd(const Src : array of String) : TSynEdit;
    procedure Jumped(Ed : TSynEdit; Line : Integer);
    // the visible rows, '  ' before an entry inside a sub, '+' after a closed sub
    function  Shown : String;
    function  NodeText(const Text : String) : TTreeNode;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSubsStartClosed;
    procedure TestFilterOpensAndKeepsTheSub;
    procedure TestBadFilterLeavesTheList;
    procedure TestSortedByName;
    procedure TestFollowsTheCaret;
    procedure TestJumpGoesToTheEntry;
    procedure TestJumpAfterTypingFindsTheEntry;
    procedure TestRebuildWaitsForTypingToStop;
    procedure TestSameRowsKeepTheNodes;
    procedure TestOpenSubsKeptPerEditor;
    procedure TestFreedEditor;
  end;

implementation

const
  Script : array[0..11] of String = (
    'main:',          // 0
    '  gosub b',      // 1
    '  goto main',    // 2
    'sub b',          // 3
    'b2:',            // 4
    '  set %a 1',     // 5
    'b1:',            // 6
    'return',         // 7
    'sub a',          // 8
    'return',         // 9
    'menu form opts 1 2 3 4',  // 10
    'halt');          // 11

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.SetUp;
begin
  Application.Initialize;   // console runner never does; registers the window classes
  FEds:=TList.Create;
  FForm:=TForm.CreateNew(nil);
  FForm.SetBounds(0,0,300,400);
  FPanel:=TPanel.Create(FForm);
  FPanel.Parent:=FForm;
  FPanel.Align:=alClient;
  FView:=TEuoOutlineView.Create(FForm,FPanel);
  FView.OnJump:=Jumped;
  FJumpEd:=nil;
  FJumpTo:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TearDown;
var
  i : Integer;
begin
  for i:=0 to FEds.Count-1 do
    TSynEdit(FEds[i]).Free;
  FEds.Free;
  FForm.Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineViewTests.NewEd(const Src : array of String) : TSynEdit;
var
  Cnt : Integer;
begin
  Result:=TSynEdit.Create(nil);
  FEds.Add(Result);
  for Cnt:=Low(Src) to High(Src) do
    Result.Lines.Add(Src[Cnt]);
  Result.LogicalCaretXY:=Point(1,1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.Jumped(Ed : TSynEdit; Line : Integer);
begin
  FJumpEd:=Ed;
  FJumpTo:=Line;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineViewTests.Shown : String;
var
  Node : TTreeNode;
begin
  Result:='';
  Node:=FView.Tree.Items.GetFirstNode;
  while Node<>nil do
  begin
    // not IsVisible: that is "scrolled into view"
    if (Node.Parent=nil) or Node.Parent.Expanded then
    begin
      if Result<>'' then Result:=Result+' | ';
      if Node.Parent<>nil then Result:=Result+'  ';
      Result:=Result+Node.Text;
      if Node.HasChildren and not Node.Expanded then Result:=Result+'+';
    end;
    Node:=Node.GetNext;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineViewTests.NodeText(const Text : String) : TTreeNode;
begin
  Result:=FView.Tree.Items.GetFirstNode;
  while (Result<>nil) and (Result.Text<>Text) do
    Result:=Result.GetNext;
  AssertNotNull('no node '+Text,Result);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestSubsStartClosed;
begin
  FView.Refresh(NewEd(Script));
  AssertEquals('main: | sub b+ | sub a | menu form opts',Shown);
  NodeText('sub b').Expanded:=True;
  AssertEquals('main: | sub b |   b2: |   b1: | sub a | menu form opts',Shown);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestFilterOpensAndKeepsTheSub;
begin
  FView.Refresh(NewEd(Script));
  FView.Filter:='b1';
  AssertEquals('sub b |   b1:',Shown);
  FView.Filter:='^sub';
  AssertEquals('sub b | sub a',Shown);
  FView.Filter:='';
  AssertEquals('main: | sub b+ | sub a | menu form opts',Shown);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestBadFilterLeavesTheList;
begin
  FView.Refresh(NewEd(Script));
  FView.Filter:='main';
  AssertEquals('main:',Shown);
  FView.Filter:='main(';
  AssertEquals('the list stays','main:',Shown);
  AssertEquals('the box turns red',clRed,FView.FilterEdit.Font.Color);
  AssertTrue('the error is its hint',FView.FilterEdit.Hint<>'');
  FView.Filter:='';
  AssertEquals(clDefault,FView.FilterEdit.Font.Color);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestSortedByName;
begin
  FView.Refresh(NewEd(Script));
  FView.Sorted:=True;
  AssertTrue('the button shows it',FView.SortButton.Down);
  NodeText('sub b').Expanded:=True;
  AssertEquals('sub a | sub b |   b1: |   b2: | main: | menu form opts',Shown);
  FView.Sorted:=False;
  AssertEquals('main: | sub b |   b2: |   b1: | sub a | menu form opts',Shown);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestFollowsTheCaret;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(Script);
  FView.Refresh(Ed);
  Ed.CaretY:=3;  // goto main
  FView.Poll(Ed);
  AssertEquals('main:',FView.Tree.Selected.Text);
  Ed.CaretY:=6;  // in b2:, its sub closed
  FView.Poll(Ed);
  AssertEquals('the closed sub','sub b',FView.Tree.Selected.Text);
  AssertFalse('stays closed',NodeText('sub b').Expanded);
  NodeText('sub b').Expanded:=True;
  FView.FollowCaret;
  AssertEquals('b2:',FView.Tree.Selected.Text);
  Ed.CaretY:=8;  // return of sub b, in b1:
  FView.Poll(Ed);
  AssertEquals('b1:',FView.Tree.Selected.Text);
  Ed.CaretY:=12; // halt, after the menu form at top level
  FView.Poll(Ed);
  AssertEquals('menu form opts',FView.Tree.Selected.Text);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestJumpGoesToTheEntry;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(Script);
  FView.Refresh(Ed);
  FView.Tree.Selected:=NodeText('sub a');
  FView.JumpToSelected;
  AssertTrue(FJumpEd=Ed);
  AssertEquals(9,FJumpTo);
  FView.Tree.Selected:=nil;
  FJumpTo:=-1;
  FView.JumpToSelected;
  AssertEquals('nothing selected',-1,FJumpTo);
end;

////////////////////////////////////////////////////////////////////////////////
// Lines typed above an entry before the outline caught up: the jump still lands on it.
procedure TEuoOutlineViewTests.TestJumpAfterTypingFindsTheEntry;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(Script);
  FView.Refresh(Ed);
  FView.Tree.Selected:=NodeText('sub a');
  Ed.Lines.Insert(0,'set %x 1');
  Ed.Lines.Insert(0,'set %y 1');
  FView.JumpToSelected;
  AssertEquals(11,FJumpTo);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestRebuildWaitsForTypingToStop;
var
  Ed  : TSynEdit;
  Cnt : Integer;
begin
  Ed:=NewEd(Script);
  FView.Poll(Ed);
  AssertEquals('another editor: at once','main: | sub b+ | sub a | menu form opts',Shown);
  Ed.Lines.Add('sub c');
  FView.Poll(Ed);
  AssertEquals('not yet','main: | sub b+ | sub a | menu form opts',Shown);
  for Cnt:=1 to QuietPolls do
    FView.Poll(Ed);
  AssertEquals('main: | sub b+ | sub a | menu form opts | sub c',Shown);
end;

////////////////////////////////////////////////////////////////////////////////
// Typing that moves entries but changes no row keeps the tree's nodes (no flicker), and the
// entries take their new lines.
procedure TEuoOutlineViewTests.TestSameRowsKeepTheNodes;
var
  Ed   : TSynEdit;
  Node : TTreeNode;
begin
  Ed:=NewEd(Script);
  FView.Refresh(Ed);
  Node:=NodeText('sub a');
  Ed.Lines.Insert(0,'');
  FView.Refresh(Ed);
  AssertTrue('the same node',Node=NodeText('sub a'));
  AssertEquals('the new line',9,FView.Items[Integer(PtrUInt(Node.Data))].Line);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestOpenSubsKeptPerEditor;
var
  Ed1, Ed2 : TSynEdit;
begin
  Ed1:=NewEd(Script);
  Ed2:=NewEd(['sub b','b9:','return']);
  FView.Poll(Ed1);
  NodeText('sub b').Expanded:=True;
  FView.Poll(Ed2);
  AssertEquals('the other tab''s sub b','sub b+',Shown);
  FView.Poll(Ed1);
  AssertEquals('main: | sub b |   b2: |   b1: | sub a | menu form opts',Shown);
  NodeText('sub b').Expanded:=False;
  Ed1.Lines.Insert(0,'');
  FView.Refresh(Ed1);
  FView.Refresh(Ed2);
  FView.Refresh(Ed1);
  AssertEquals('closed again','main: | sub b+ | sub a | menu form opts',Shown);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineViewTests.TestFreedEditor;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(Script);
  FView.Refresh(Ed);
  FEds.Remove(Ed);
  Ed.Free;
  AssertNull('the view lets go of it',FView.Editor);
  AssertEquals('the list is empty',0,FView.Tree.Items.Count);
  FView.Poll(nil);
  FView.FollowCaret;
  FView.JumpToSelected;
  AssertEquals(-1,FJumpTo);
end;

initialization
  RegisterTest(TEuoOutlineViewTests);
end.
