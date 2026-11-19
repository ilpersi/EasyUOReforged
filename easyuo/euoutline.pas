unit euoutline;

{
  Port addition (not present in the original app): the outline panel left of the editor, an
  index of the current script's subs, labels and MENU windows that jumps there on a click.
  What it lists, and where each entry starts and ends, is parser\EuoOutline.pas; this unit is
  the panel. MainForm (main.pas) gives it a parent panel and calls Poll from its timer, and
  OnJump moves the editor (TInstHandler.JumpTo, so Go Back returns).

  - Poll rebuilds at once for another editor, and for the same editor once its ChangeStamp has
    stayed the same for QuietPolls timer ticks, so typing never rebuilds on every key. A
    rebuild that would show the same rows only takes the new line numbers: the tree is not
    touched, so it does not flicker.
  - It follows the caret: the innermost entry the caret line is in is selected, or its sub
    when the sub is collapsed (collapsed subs are never opened for the user), or nothing.
  - A click on an entry (not on its +/- button) or Enter jumps. In the filter box Enter jumps
    to the selected or first entry, Down goes to the list and Esc empties the box.
  - The filter is the variable filter's (vartree.pas): a case-insensitive regular expression,
    TRegExpr, checked with eufind's CheckPattern; a pattern that does not compile leaves the
    list as it is and turns the box red, with the error as its hint. It matches the text
    shown ('sub Name', 'Name:', 'menu Title'). A sub stays when one of its entries matches, and
    every sub is open while filtering.
  - Subs start collapsed. Which subs are open is kept per editor, in a component the editor
    owns (the way insthandler's TJumpHistory is), keyed by the entry's text and how many
    entries of that text come before it, so it survives edits and tab switches.
  - Unused subs (EuoOutline's Unused) are drawn in clGrayText. The tree is drawn without
    themes (tvoThemedDraw off): the themed path draws text with DrawThemeText, which ignores
    Canvas.Font.Color (lcl\interfaces\win32\win32themes.pas, DrawText), and a disabled node,
    which themes would grey, takes no clicks (treeview.inc, MouseDown).
  - It holds the editor with FreeNotification, so closing a tab never leaves it a dead pointer.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Buttons, ComCtrls, Graphics, LCLType,
  SynEdit, EuoOutline;

type
  // Line is 1-based.
  TEuoOutlineJump = procedure(Ed : TSynEdit; Line : Integer) of object;

  TEuoOutlineView = class(TComponent)
  private
    FHeader    : TPanel;
    FFilterEd  : TEdit;
    FSortBtn   : TSpeedButton;
    FTree      : TTreeView;
    FEd        : TSynEdit;
    FItems     : TEuoOutline;
    FShape     : String;   // the rows the tree shows, see ApplyRows
    FStamp     : Int64;    // FEd.ChangeStamp FItems were built from
    FSeenStamp : Int64;    // the last ChangeStamp Poll saw
    FQuiet     : Integer;  // polls since FSeenStamp changed
    FCaretY    : Integer;  // the caret line FollowCaret last saw
    FFilter    : String;
    FBadFilter : Boolean;
    FSorted    : Boolean;
    FBuilding  : Boolean;
    FOnJump    : TEuoOutlineJump;
    procedure SetEditor(Ed : TSynEdit);
    procedure ClearTree;
    procedure SetSorted(Value : Boolean);
    function  GetFilter : String;
    procedure SetFilter(const Value : String);
    function  ItemKey(Idx : Integer) : String;
    function  FindKey(const Key : String) : Integer;
    function  NodeOf(Idx : Integer) : TTreeNode;
    function  OpenSubs : TStringList;
    procedure ApplyRows;
    procedure FilterChange(Sender : TObject);
    procedure FilterKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
    procedure SortClick(Sender : TObject);
    procedure TreeMouseUp(Sender : TObject; Button : TMouseButton; Shift : TShiftState; X, Y : Integer);
    procedure TreeKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
    procedure TreeExpanded(Sender : TObject; Node : TTreeNode);
    procedure TreeDrawItem(Sender : TCustomTreeView; Node : TTreeNode;
                State : TCustomDrawState; var DefaultDraw : Boolean);
  protected
    procedure Notification(AComponent : TComponent; Operation : TOperation); override;
  public
    constructor Create(AOwner : TComponent; AParent : TWinControl); reintroduce;
    // From the timer: follows Ed's text and caret (see the header).
    procedure Poll(Ed : TSynEdit);
    // Rebuilds now from Ed's text.
    procedure Refresh(Ed : TSynEdit);
    procedure FollowCaret;
    // Fires OnJump for the selected entry, at the line it has in the editor's text now.
    procedure JumpToSelected;
    property Items      : TEuoOutline read FItems;
    property Tree       : TTreeView read FTree;
    property FilterEdit : TEdit read FFilterEd;
    property SortButton : TSpeedButton read FSortBtn;
    property Editor     : TSynEdit read FEd;
    property Sorted     : Boolean read FSorted write SetSorted;
    property Filter     : String read GetFilter write SetFilter;
    property OnJump     : TEuoOutlineJump read FOnJump write FOnJump;
  end;

const
  QuietPolls = 2;  // timer ticks (100 ms) the text stays the same before a rebuild

implementation

uses
  RegExpr, eufind;

type
  // The subs open in one editor's outline, owned by that editor.
  TOutlineEdState = class(TComponent)
  public
    Open : TStringList;
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
  end;

constructor TOutlineEdState.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  Open:=TStringList.Create;
  Open.Sorted:=True;
  Open.Duplicates:=dupIgnore;
end;

destructor TOutlineEdState.Destroy;
begin
  Open.Free;
  inherited;
end;

////////////////////////////////////////////////////////////////////////////////
// The entry a node shows (its Data).
function ItemOf(Node : TTreeNode) : Integer;
begin
  Result:=Integer(PtrUInt(Node.Data));
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoOutlineView.Create(AOwner : TComponent; AParent : TWinControl);
begin
  inherited Create(AOwner);
  FCaretY:=-1;

  FHeader:=TPanel.Create(Self);
  FHeader.Parent:=AParent;
  FHeader.Align:=alTop;
  FHeader.BevelOuter:=bvNone;

  FFilterEd:=TEdit.Create(Self);
  FFilterEd.Parent:=FHeader;
  FFilterEd.Align:=alClient;
  FFilterEd.TextHint:='Filter';
  FFilterEd.OnChange:=FilterChange;
  FFilterEd.OnKeyDown:=FilterKeyDown;
  FHeader.Height:=FFilterEd.Height;

  FSortBtn:=TSpeedButton.Create(Self);
  FSortBtn.Parent:=FHeader;
  FSortBtn.Align:=alRight;
  FSortBtn.Width:=32;
  FSortBtn.Caption:='A-Z';
  FSortBtn.GroupIndex:=1;
  FSortBtn.AllowAllUp:=True;
  FSortBtn.Hint:='Sort by name';
  FSortBtn.ShowHint:=True;
  FSortBtn.OnClick:=SortClick;

  FTree:=TTreeView.Create(Self);
  FTree.Parent:=AParent;
  FTree.Align:=alClient;
  FTree.ReadOnly:=True;
  FTree.HideSelection:=False;
  FTree.Options:=FTree.Options-[tvoThemedDraw]+[tvoNoDoubleClickExpand];
  FTree.OnMouseUp:=TreeMouseUp;
  FTree.OnKeyDown:=TreeKeyDown;
  FTree.OnExpanded:=TreeExpanded;
  FTree.OnCollapsed:=TreeExpanded;
  FTree.OnCustomDrawItem:=TreeDrawItem;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.Notification(AComponent : TComponent; Operation : TOperation);
begin
  inherited;
  if (Operation=opRemove) and (AComponent=FEd) then
  begin
    FEd:=nil;
    FItems:=nil;
    FShape:='';
    if not (csDestroying in ComponentState) then
      ClearTree;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.SetEditor(Ed : TSynEdit);
begin
  if Ed=FEd then Exit;
  if FEd<>nil then FEd.RemoveFreeNotification(Self);
  FEd:=Ed;
  if FEd<>nil then FEd.FreeNotification(Self);
  // another editor's entries and open subs: always rebuild, from the top
  FShape:='';
  ClearTree;
end;

////////////////////////////////////////////////////////////////////////////////
// Not while FBuilding is off: the nodes going away must not count as subs the user closed.
procedure TEuoOutlineView.ClearTree;
begin
  FBuilding:=True;
  try
    FTree.Items.Clear;
  finally
    FBuilding:=False;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.Poll(Ed : TSynEdit);
var
  S : Int64;
begin
  if Ed<>FEd then
  begin
    Refresh(Ed);
    Exit;
  end;
  if FEd=nil then Exit;

  S:=FEd.ChangeStamp;
  if S<>FStamp then
  begin
    if S<>FSeenStamp then
    begin
      FSeenStamp:=S;
      FQuiet:=0;
    end
    else Inc(FQuiet);
    if FQuiet>=QuietPolls then Refresh(FEd);
  end;

  if FEd.CaretY<>FCaretY then FollowCaret;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.Refresh(Ed : TSynEdit);
begin
  SetEditor(Ed);
  if FEd=nil then
  begin
    FItems:=nil;
    FShape:='';
    ClearTree;
    Exit;
  end;
  EuoBuildOutline(FEd.Lines,FItems);
  FStamp:=FEd.ChangeStamp;
  FSeenStamp:=FStamp;
  FQuiet:=0;
  ApplyRows;
  FollowCaret;
end;

////////////////////////////////////////////////////////////////////////////////
// The entry's text, uppercased, and how many entries with that text come before it.
function TEuoOutlineView.ItemKey(Idx : Integer) : String;
var
  Cnt, N : Integer;
begin
  N:=0;
  for Cnt:=0 to Idx-1 do
    if CompareText(FItems[Cnt].Text,FItems[Idx].Text)=0 then Inc(N);
  Result:=UpperCase(FItems[Idx].Text)+'#'+IntToStr(N);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineView.FindKey(const Key : String) : Integer;
var
  Cnt, N, P : Integer;
  Text      : String;
begin
  Result:=-1;
  P:=Length(Key);
  while (P>0) and (Key[P]<>'#') do Dec(P);
  if P=0 then Exit;
  Text:=Copy(Key,1,P-1);
  N:=StrToIntDef(Copy(Key,P+1,MaxInt),-1);
  for Cnt:=0 to High(FItems) do
    if CompareText(FItems[Cnt].Text,Text)=0 then
  begin
    if N=0 then
    begin
      Result:=Cnt;
      Exit;
    end;
    Dec(N);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineView.NodeOf(Idx : Integer) : TTreeNode;
begin
  Result:=FTree.Items.GetFirstNode;
  while Result<>nil do
  begin
    if ItemOf(Result)=Idx then Exit;
    Result:=Result.GetNext;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineView.OpenSubs : TStringList;
var
  Cnt : Integer;
  St  : TOutlineEdState;
begin
  St:=nil;
  for Cnt:=0 to FEd.ComponentCount-1 do
    if FEd.Components[Cnt] is TOutlineEdState then
  begin
    St:=TOutlineEdState(FEd.Components[Cnt]);
    Break;
  end;
  if St=nil then St:=TOutlineEdState.Create(FEd);
  Result:=St.Open;
end;

////////////////////////////////////////////////////////////////////////////////
// Fills the tree from FItems, the filter and the order. FShape is the rows as text (entry,
// depth, text, unused, filtered or not): when it comes out the same, the tree already shows
// them, and only FItems changed (line numbers).
procedure TEuoOutlineView.ApplyRows;
var
  Match   : array of Boolean;
  Rows    : TEuoOutlineRows;
  Re      : TRegExpr;
  Shape   : String;
  TopKey  : String;
  Cnt     : Integer;
  Node    : TTreeNode;
  Parent  : TTreeNode;
  Open    : TStringList;
begin
  Match:=nil;
  if FFilter<>'' then
  begin
    SetLength(Match,Length(FItems));
    Re:=TRegExpr.Create;
    try
      Re.ModifierI:=True;
      Re.Expression:=FFilter;  // FilterChange compiled it already
      for Cnt:=0 to High(FItems) do
        Match[Cnt]:=Re.Exec(FItems[Cnt].Text);
    finally
      Re.Free;
    end;
  end;
  Rows:=EuoOutlineRows(FItems,Match,FSorted);

  Shape:=BoolToStr(FFilter<>'',True)+#10;
  for Cnt:=0 to High(Rows) do
    Shape:=Shape+IntToStr(Rows[Cnt].Item)+'/'+IntToStr(Rows[Cnt].Depth)+'/'+
      BoolToStr(FItems[Rows[Cnt].Item].Unused,True)+'/'+FItems[Rows[Cnt].Item].Text+#10;
  if Shape=FShape then Exit;

  // the shape changed, so the old rows' entries are gone from FItems: keep the top row by
  // its node text instead
  TopKey:='';
  if FTree.TopItem<>nil then TopKey:=UpperCase(FTree.TopItem.Text);

  FBuilding:=True;
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    Parent:=nil;
    for Cnt:=0 to High(Rows) do
      if Rows[Cnt].Depth=0 then
        Parent:=FTree.Items.AddObject(nil,FItems[Rows[Cnt].Item].Text,Pointer(PtrUInt(Rows[Cnt].Item)))
      else
        FTree.Items.AddChildObject(Parent,FItems[Rows[Cnt].Item].Text,Pointer(PtrUInt(Rows[Cnt].Item)));

    if FFilter<>'' then
      FTree.FullExpand
    else if FEd<>nil then
    begin
      Open:=OpenSubs;
      Node:=FTree.Items.GetFirstNode;
      while Node<>nil do
      begin
        if Node.HasChildren then
          Node.Expanded:=Open.IndexOf(ItemKey(ItemOf(Node)))>=0;
        Node:=Node.GetNextSibling;
      end;
    end;

    if TopKey<>'' then
    begin
      Node:=FTree.Items.GetFirstNode;
      while Node<>nil do
      begin
        if ((Node.Parent=nil) or Node.Parent.Expanded) and (UpperCase(Node.Text)=TopKey) then
        begin
          FTree.TopItem:=Node;
          Break;
        end;
        Node:=Node.GetNext;
      end;
    end;
  finally
    FTree.Items.EndUpdate;
    FBuilding:=False;
  end;
  FShape:=Shape;
  FCaretY:=-1;  // select again in the new nodes
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.FollowCaret;
var
  Idx  : Integer;
  Node : TTreeNode;
begin
  if FEd=nil then Exit;
  FCaretY:=FEd.CaretY;
  Idx:=EuoOutlineItemAt(FItems,FCaretY-1);
  Node:=nil;
  if Idx>=0 then
  begin
    Node:=NodeOf(Idx);
    // filtered out, or sorted away from its sub: its sub, if that is shown
    if (Node=nil) and (FItems[Idx].Parent>=0) then
      Node:=NodeOf(FItems[Idx].Parent);
  end;
  if (Node<>nil) and (Node.Parent<>nil) and not Node.Parent.Expanded then
    Node:=Node.Parent;
  if FTree.Selected<>Node then FTree.Selected:=Node;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.JumpToSelected;
var
  Idx : Integer;
  Key : String;
begin
  if (FEd=nil) or (FTree.Selected=nil) then Exit;
  Idx:=ItemOf(FTree.Selected);
  if (Idx<0) or (Idx>High(FItems)) then Exit;

  // text typed since the last rebuild: the same entry, where it is now
  if FEd.ChangeStamp<>FStamp then
  begin
    Key:=ItemKey(Idx);
    Refresh(FEd);
    Idx:=FindKey(Key);
    if Idx<0 then Exit;
  end;

  if Assigned(FOnJump) then FOnJump(FEd,FItems[Idx].Line+1);
  FCaretY:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.SetSorted(Value : Boolean);
begin
  FSortBtn.Down:=Value;
  if Value=FSorted then Exit;
  FSorted:=Value;
  ApplyRows;
  FollowCaret;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineView.GetFilter : String;
begin
  Result:=FFilterEd.Text;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.SetFilter(const Value : String);
begin
  FFilterEd.Text:=Value;  // OnChange applies it
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.FilterChange(Sender : TObject);
var
  Find : TFindSettings;
  Msg  : String;
  S    : String;
begin
  S:=Trim(FFilterEd.Text);
  Find:=Default(TFindSettings);
  Find.FindText:=S;
  Find.RegExpr:=True;
  if not CheckPattern(Find,Msg) then
  begin
    FBadFilter:=True;
    FFilterEd.Font.Color:=clRed;
    FFilterEd.Hint:=Msg;
    FFilterEd.ShowHint:=True;
    Exit;
  end;
  if FBadFilter then
  begin
    FBadFilter:=False;
    FFilterEd.Font.Color:=clDefault;
    FFilterEd.Hint:='';
    FFilterEd.ShowHint:=False;
  end;

  if S=FFilter then Exit;
  FFilter:=S;
  ApplyRows;
  FollowCaret;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.FilterKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
begin
  case Key of
    VK_ESCAPE:
      begin
        FFilterEd.Text:='';
        Key:=0;
      end;
    VK_RETURN:
      begin
        if FTree.Selected=nil then FTree.Selected:=FTree.Items.GetFirstNode;
        JumpToSelected;
        Key:=0;
      end;
    VK_DOWN:
      if FTree.Items.Count>0 then
      begin
        if FTree.Selected=nil then FTree.Selected:=FTree.Items.GetFirstNode;
        if FTree.CanFocus then FTree.SetFocus;
        Key:=0;
      end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.SortClick(Sender : TObject);
begin
  SetSorted(FSortBtn.Down);
end;

////////////////////////////////////////////////////////////////////////////////
// A click on an entry's text or row jumps; one on its +/- button or left of it only opens
// or closes the sub.
procedure TEuoOutlineView.TreeMouseUp(Sender : TObject; Button : TMouseButton;
  Shift : TShiftState; X, Y : Integer);
var
  Hit  : THitTests;
  Node : TTreeNode;
begin
  if Button<>mbLeft then Exit;
  if Shift*[ssShift,ssAlt,ssCtrl]<>[] then Exit;
  Hit:=FTree.GetHitTestInfoAt(X,Y);
  if not (htOnItem in Hit) or (Hit*[htOnButton,htOnIndent]<>[]) then Exit;
  Node:=FTree.GetNodeAt(X,Y);
  if Node=nil then Exit;
  if FTree.Selected<>Node then FTree.Selected:=Node;
  JumpToSelected;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.TreeKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
begin
  if Key<>VK_RETURN then Exit;
  JumpToSelected;
  Key:=0;
end;

////////////////////////////////////////////////////////////////////////////////
// The user opened or closed a sub: remember it for this editor (not while filtering, when
// every sub is open).
procedure TEuoOutlineView.TreeExpanded(Sender : TObject; Node : TTreeNode);
var
  Open : TStringList;
  Key  : String;
  Idx  : Integer;
begin
  if FBuilding or (FFilter<>'') or (FEd=nil) then Exit;
  Idx:=ItemOf(Node);
  if (Idx<0) or (Idx>High(FItems)) then Exit;
  Open:=OpenSubs;
  Key:=ItemKey(Idx);
  if Node.Expanded then Open.Add(Key)
  else if Open.IndexOf(Key)>=0 then Open.Delete(Open.IndexOf(Key));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineView.TreeDrawItem(Sender : TCustomTreeView; Node : TTreeNode;
  State : TCustomDrawState; var DefaultDraw : Boolean);
var
  Idx : Integer;
begin
  if cdsSelected in State then Exit;
  Idx:=ItemOf(Node);
  if (Idx>=0) and (Idx<=High(FItems)) and FItems[Idx].Unused then
    Sender.Canvas.Font.Color:=clGrayText;
end;

end.
