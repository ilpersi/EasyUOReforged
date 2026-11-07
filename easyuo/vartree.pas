unit vartree;

{
  Ported from the original Delphi 7 easyuo\vartree.pas, near-verbatim. Populates
  MainForm.VarTreeView from the hardcoded Identifiers list (built-in #IDENTIFIER
  names grouped by category) plus live values refreshed on a timer.

  Ported unchanged: the Obj(nil).Method idiom below (a class with methods that
  never touch Self, called through a nil-typed reference purely to obtain a
  TNotifyEvent/TTVChangedEvent-compatible method pointer without allocating an
  instance) -- a well-known classic-Delphi pattern for a stateless callback,
  predating class methods/anonymous methods. Works identically under FPC for
  the same reason it works under Delphi: the method bodies never dereference
  Self, so the hidden Self parameter being nil is never actually read.

  Port changes (the inspector was hard to search):
  - The default Identifiers list is regrouped. The groups are the variable
    categories of the documentation site (VARIABLE_CATEGORIES in
    website\src\reference.mjs, same labels), and the groups and the variables
    inside each are in alphabetical order. tests\tools\CheckDocsCoverage.ps1
    fails when the list and the site disagree or the order breaks. A list
    edited through Tools > Manage VarList is shown as typed, never re-sorted.
  - A filter box (MainForm.VarFilterEdit) above the tree: VarTreeFilter
    rebuilds the tree with only the variables whose name (without its '#'),
    or whose group's name, matches the text as a case-insensitive regular
    expression -- TRegExpr, the engine of the Find window (eufind.pas), whose
    CheckPattern also gives the error message. Plain text is a regex that
    matches itself. A '#' typed at the start (or after a leading '^') is
    dropped, as names are matched without theirs. A pattern that does not
    compile leaves the tree as it is and turns the box's text red, with the
    error as its hint. Groups left empty are not added, and every group shown
    is expanded while filtering.
  - The open groups are saved by name (registry value VarTree.Expanded, the
    full paths of the expanded groups, each followed by '|'), not as the
    original Tree0.State, one '+'/'-' per group by position, which a group
    inserted in the middle scrambled. Tree0.State is left alone:
    \Software\EasyUO is shared with the original EasyUO. While a filter is
    active the state of the unfiltered tree is kept aside and comes back when
    the filter is cleared.
  - FormMouseWheel returns when the tree is empty (no TopItem), which a
    filter that matches nothing makes possible.
}

{$mode delphi}{$H+}

interface
uses Windows, Forms, Controls, Classes, Menus, ComCtrls, Registry,
     SysUtils, Clipbrd, Dialogs, StdCtrls;

  procedure VarTreeLoad(ListStr : String);
  procedure VarTreeFilter(S : String);
  procedure VarTreeRefresh;
  procedure VarTreeFormCreate;
  procedure VarTreeFormClose;

var
  Identifiers : String =

   '\Buffs'#13#10+
   '#BUFFBAROPEN'#13#10+
   '#BUFFCLILOC'#13#10+
   '#BUFFCNT'#13#10+
   '#BUFFDESC'#13#10+
   '#BUFFID'#13#10+
   '#BUFFINDEX'#13#10+
   '#BUFFNAME'#13#10+
   '#BUFFTIME'#13#10+

    #13#10+
   '\Character'#13#10+
   '#BACKPACKID'#13#10+
   '#CHARDIR'#13#10+
   '#CHARGHOST'#13#10+
   '#CHARID'#13#10+
   '#CHARPOSX'#13#10+
   '#CHARPOSY'#13#10+
   '#CHARPOSZ'#13#10+
   '#CHARSTATUS'#13#10+
   '#CHARTYPE'#13#10+
   '#MOUNTID'#13#10+
   '#MOUNTTYPE'#13#10+

    #13#10+
   '\Client'#13#10+
   '#CLICNT'#13#10+
   '#CLILANG'#13#10+
   '#CLILEFT'#13#10+
   '#CLILOGGED'#13#10+
   '#CLINR'#13#10+
   '#CLITITLE'#13#10+
   '#CLITOP'#13#10+
   '#CLIVER'#13#10+
   '#CLIXRES'#13#10+
   '#CLIYRES'#13#10+
   '#LSHARD'#13#10+
   '#SHARD'#13#10+

    #13#10+
   '\Combat'#13#10+
   '#ENEMYHITS'#13#10+
   '#ENEMYID'#13#10+
   '#LHANDID'#13#10+
   '#RHANDID'#13#10+

    #13#10+
   '\Container'#13#10+
   '#CONTHP'#13#10+
   '#CONTID'#13#10+
   '#CONTKIND'#13#10+
   '#CONTNAME'#13#10+
   '#CONTPOSX'#13#10+
   '#CONTPOSY'#13#10+
   '#CONTSIZE'#13#10+
   '#CONTSIZEX'#13#10+
   '#CONTSIZEY'#13#10+
   '#CONTTYPE'#13#10+
   '#NEXTCPOSX'#13#10+
   '#NEXTCPOSY'#13#10+

    #13#10+
   '\Cursor & targeting'#13#10+
   '#CURSKIND'#13#10+
   '#CURSORX'#13#10+
   '#CURSORY'#13#10+
   '#TARGCURS'#13#10+

    #13#10+
   '\FindItem'#13#10+
   '#FINDBAGID'#13#10+
   '#FINDCNT'#13#10+
   '#FINDCOL'#13#10+
   '#FINDDIST'#13#10+
   '#FINDID'#13#10+
   '#FINDINDEX'#13#10+
   '#FINDKIND'#13#10+
   '#FINDLAYER'#13#10+
   '#FINDMOD'#13#10+
   '#FINDREP'#13#10+
   '#FINDSTACK'#13#10+
   '#FINDTYPE'#13#10+
   '#FINDX'#13#10+
   '#FINDY'#13#10+
   '#FINDZ'#13#10+

    #13#10+
   '\Journal & messages'#13#10+
   '#JCOLOR'#13#10+
   '#JFOUND'#13#10+
   '#JINDEX'#13#10+
   '#JOURNAL'#13#10+
   '#SYSMSG'#13#10+
   '#SYSMSGCOL'#13#10+

    #13#10+
   '\Last action'#13#10+
   '#LLIFTEDID'#13#10+
   '#LLIFTEDKIND'#13#10+
   '#LLIFTEDTYPE'#13#10+
   '#LOBJECTID'#13#10+
   '#LOBJECTTYPE'#13#10+
   '#LSKILL'#13#10+
   '#LSPELL'#13#10+
   '#LTARGETID'#13#10+
   '#LTARGETKIND'#13#10+
   '#LTARGETTILE'#13#10+
   '#LTARGETX'#13#10+
   '#LTARGETY'#13#10+
   '#LTARGETZ'#13#10+

    #13#10+
   '\Pathfinding'#13#10+
   '#PATHCNT'#13#10+
   '#PATHDIR'#13#10+
   '#PATHSTATE'#13#10+
   '#PATHX'#13#10+
   '#PATHY'#13#10+
   '#PATHZ'#13#10+

    #13#10+
   '\Result'#13#10+
   '#DISPRES'#13#10+
   '#MENUBUTTON'#13#10+
   '#MENURES'#13#10+
   '#PIXCOL'#13#10+
   '#PROPERTY'#13#10+
   '#RESULT'#13#10+
   '#STRRES'#13#10+
   '#WAITRES'#13#10+

    #13#10+
   '\Script'#13#10+
   '#CURPATH'#13#10+
   '#EUOVER'#13#10+
   '#LPC'#13#10+
   '#NSNAME'#13#10+
   '#NSTYPE'#13#10+
   '#OPTS'#13#10+
   '#OSVER'#13#10+
   '#RANDOM'#13#10+
   '#REFORGEDVER'#13#10+
   '#SENDHEADER'#13#10+

    #13#10+
   '\Shop'#13#10+
   '#SHOPCNT'#13#10+
   '#SHOPCURPOS'#13#10+
   '#SHOPITEMID'#13#10+
   '#SHOPITEMMAX'#13#10+
   '#SHOPITEMNAME'#13#10+
   '#SHOPITEMPRICE'#13#10+
   '#SHOPITEMTYPE'#13#10+

    #13#10+
   '\Skills'#13#10+
   '#SKILL'#13#10+
   '#SKILLCAP'#13#10+
   '#SKILLLOCK'#13#10+

    #13#10+
   '\SQL'#13#10+
   '#SQLCHANGES'#13#10+
   '#SQLCNT'#13#10+
   '#SQLLASTID'#13#10+
   '#SQLRES'#13#10+

    #13#10+
   '\Status bar'#13#10+
   '#AR'#13#10+
   '#CHARNAME'#13#10+
   '#CR'#13#10+
   '#DEX'#13#10+
   '#ER'#13#10+
   '#FOLLOWERS'#13#10+
   '#FR'#13#10+
   '#GOLD'#13#10+
   '#HITS'#13#10+
   '#INT'#13#10+
   '#LUCK'#13#10+
   '#MANA'#13#10+
   '#MAXDMG'#13#10+
   '#MAXFOL'#13#10+
   '#MAXHITS'#13#10+
   '#MAXMANA'#13#10+
   '#MAXSTAM'#13#10+
   '#MAXSTATS'#13#10+
   '#MAXWEIGHT'#13#10+
   '#MINDMG'#13#10+
   '#PR'#13#10+
   '#SEX'#13#10+
   '#STAMINA'#13#10+
   '#STR'#13#10+
   '#TP'#13#10+
   '#WEIGHT'#13#10+

    #13#10+
   '\Tile'#13#10+
   '#TILECNT'#13#10+
   '#TILEFLAGS'#13#10+
   '#TILENAME'#13#10+
   '#TILETYPE'#13#10+
   '#TILEZ'#13#10+

    #13#10+
   '\Time'#13#10+
   '#DATE'#13#10+
   '#SCNT'#13#10+
   '#SCNT2'#13#10+
   '#SYSTIME'#13#10+
   '#TIME';

var
  DList     : TStringList;

////////////////////////////////////////////////////////////////////////////////
implementation
uses Main, InstHandler, Graphics, RegExpr, eufind;
var
  VReg      : TRegistry;
  NodePopup : TPopupMenu;
  NodeStr   : String;
  VList     : TTreeView;
  MForm     : TForm;
  UserNode  : TTreeNode = nil;
  FilterStr : String = '';     // port addition: the filter box's regex, '#' stripped
  Filtered  : Boolean = False; // port addition: the tree shown was built with a filter
  BadFilter : Boolean = False; // port addition: the box's text does not compile
  ExpState  : String = '';     // port addition: open groups of the unfiltered tree

////////////////////////////////////////////////////////////////////////////////
// Port change: the open groups are kept by path (\Group\Sub), each followed by
// '|', instead of the original positional Tree0.State (see the header).
function NodePath(Node : TTreeNode) : String;
begin
  Result:='';
  while Node<>nil do
  begin
    Result:='\'+Node.Text+Result;
    Node:=Node.Parent;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TreeGetState : String;
var
  tNode : TTreeNode;
begin
  Result:='';
  tNode:=VList.Items.GetFirstNode;
  while tNode<>nil do
  begin
    if tNode.Data<>nil then
      if tNode.Expanded then
        Result:=Result+NodePath(tNode)+'|';
    tNode:=tNode.GetNext;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TreeSetState(State : String);
var
  tNode : TTreeNode;
begin
  State:='|'+UpperCase(State);
  tNode:=VList.Items.GetFirstNode;
  while tNode<>nil do
  begin
    if tNode.Data<>nil then
      tNode.Expanded:=Pos('|'+UpperCase(NodePath(tNode))+'|',State)>0;
    tNode:=tNode.GetNext;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function GroupNode(sBuf1 : String) : TTreeNode;
var
  sBuf2      : String;
  iBuf       : Integer;
  ParentNode : TTreeNode;
  TmpNode    : TTreeNode;
begin
  ParentNode:=nil;
  sBuf1:=sBuf1+'\';
  repeat
    iBuf:=Pos('\',sBuf1);
    if iBuf=0 then Break;
    sBuf2:=Copy(sBuf1,1,iBuf-1);
    Delete(sBuf1,1,iBuf);
    if iBuf=1 then Continue;

    if ParentNode<>nil then TmpNode:=ParentNode.GetFirstChild
    else TmpNode:=VList.Items.GetFirstNode;

    while TmpNode<>nil do
    begin
      if TmpNode.Data<>nil then
        if UpperCase(TmpNode.Text)=UpperCase(sBuf2) then
          Break;
      TmpNode:=TmpNode.GetNextSibling;
    end;

    if TmpNode<>nil then ParentNode:=TmpNode
    else
      ParentNode:=VList.Items.AddChildObject(
      ParentNode,sBuf2,Pointer(-1));

  until False;
  Result:=ParentNode;
end;

////////////////////////////////////////////////////////////////////////////////
// Port change: the group lookup moved to GroupNode, and with a filter a group
// is only added once one of its variables matches (see the header).
procedure VarTreeLoad(ListStr : String);
var
  List       : TStringList;
  sBuf1      : String;
  sPath      : String;
  sName      : String;
  Pending    : Boolean;
  ParentNode : TTreeNode;
  Re         : TRegExpr;
begin
  if (VList.Items.Count>0) and not Filtered then
    ExpState:=TreeGetState;

  Re:=nil;
  if FilterStr<>'' then
  begin
    Re:=TRegExpr.Create;
    Re.ModifierI:=True;
    Re.Expression:=FilterStr; // VarTreeFilter compiled it already
  end;

  VList.Items.BeginUpdate;
  VList.Items.Clear;

  List:=TStringList.Create;
  List.Text:=Identifiers;

  ParentNode:=nil;
  sPath:='';
  Pending:=False;
  while List.Count>0 do
  begin
    sBuf1:=Trim(List[0]);
    List.Delete(0);
    if sBuf1='' then Continue;

    if sBuf1[1]='\' then
    begin
      sPath:=sBuf1;
      ParentNode:=nil;
      Pending:=Re<>nil;
      if not Pending then ParentNode:=GroupNode(sPath);
      Continue;
    end;

    if Re<>nil then
    begin
      sName:=sBuf1;
      if sName[1]='#' then Delete(sName,1,1);
      if not Re.Exec(sName) and not Re.Exec(Copy(sPath,2,MaxInt)) then Continue;
    end;

    if Pending then
    begin
      ParentNode:=GroupNode(sPath);
      Pending:=False;
    end;

    VList.Items.AddChildObject(ParentNode,sBuf1+': N/A',Pointer(0));
  end;

  List.Free;
  Re.Free;
  Filtered:=FilterStr<>'';
  if Filtered then VList.FullExpand
  else TreeSetState(ExpState);
  VList.Items.EndUpdate;
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition: the filter box's OnChange (see the header).
procedure VarTreeFilter(S : String);
var
  Find : TFindSettings;
  Msg  : String;
begin
  S:=Trim(S);
  if (S<>'') and (S[1]='#') then Delete(S,1,1)
  else if (Length(S)>1) and (S[1]='^') and (S[2]='#') then Delete(S,2,1);

  Find:=Default(TFindSettings);
  Find.FindText:=S;
  Find.RegExpr:=True;
  if not CheckPattern(Find,Msg) then
  begin
    BadFilter:=True;
    MainForm.VarFilterEdit.Font.Color:=clRed;
    MainForm.VarFilterEdit.Hint:=Msg;
    MainForm.VarFilterEdit.ShowHint:=True;
    Exit;
  end;
  if BadFilter then
  begin
    BadFilter:=False;
    MainForm.VarFilterEdit.Font.Color:=clDefault;
    MainForm.VarFilterEdit.Hint:='';
    MainForm.VarFilterEdit.ShowHint:=False;
  end;

  if S=FilterStr then Exit;
  FilterStr:=S;
  VarTreeLoad(Identifiers);
  VarTreeRefresh;
end;

////////////////////////////////////////////////////////////////////////////////
procedure VarTreeRefresh;
var
  INode : TTreeNode;
  sBuf  : String;
begin
  if VList.Items.Count=0 then Exit;

  INode:=VList.Items.GetFirstNode;
  while INode<>nil do
  begin
    if INode.Data=nil then
      if INode.IsVisible then
    begin
      sBuf:=INode.Text;
      sBuf:=Copy(sBuf,1,Pos(': ',sBuf)-1);

      sBuf:=sBuf+': '+CExec.GetVar(sBuf);

      if INode.Text<>sBuf then INode.Text:=sBuf;
    end;
    INode:=INode.GetNext;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
type
  Obj = class
    procedure VarListEnter(Sender: TObject);
    procedure VarListChange(Sender: TObject; Node: TTreeNode);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure VarPopupClick(Sender: TObject);
    procedure VarFilterChange(Sender: TObject);
    procedure VarFilterKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  end;

////////////////////////////////////////////////////////////////////////////////
procedure Obj.VarListEnter(Sender: TObject);
begin
  MForm.ActiveControl:=CSyn;
end;

////////////////////////////////////////////////////////////////////////////////
procedure Obj.VarListChange(Sender: TObject; Node: TTreeNode);
var
  MPos : TPoint;
begin
  if VList.Selected=nil then Exit;

  if VList.Selected.Data=nil then
  begin
    NodeStr:=VList.Selected.Text;
    GetCursorPos(MPos);
    NodePopup.Popup(MPos.X,MPos.Y);
  end;

  VList.Selected:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
procedure Obj.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  MPos : TPoint;
begin
  GetCursorPos(MPos);
  if WindowFromPoint(MPos)=VList.Handle then
  begin
    Handled:=True;
    if VList.TopItem=nil then Exit; // port addition: empty after a filter
    if WheelDelta>0 then
    begin
      VList.TopItem:=VList.TopItem.GetPrevVisible;
      VList.TopItem:=VList.TopItem.GetPrevVisible;
    end
    else begin
      VList.TopItem:=VList.TopItem.GetNextVisible;
      VList.TopItem:=VList.TopItem.GetNextVisible;
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure Obj.VarPopupClick(Sender: TObject);
var
  sBuf1 : String;
  sBuf2 : String;
  Cnt   : Integer;
begin
  sBuf2:=NodeStr;
  Cnt:=Pos(': ',sBuf2);
  sBuf1:=Copy(sBuf2,1,Cnt-1);
  Delete(sBuf2,1,Cnt+1);

  case TComponent(Sender).Tag of
    0: Clipboard.SetTextBuf(PChar(sBuf1));
    2: Clipboard.SetTextBuf(PChar(sBuf2));
    3: CExec.SetVar(sBuf1,InputBox('Set Variable',sBuf1+':',sBuf2));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition: the filter box (see the header). Esc clears it.
procedure Obj.VarFilterChange(Sender: TObject);
begin
  VarTreeFilter(TEdit(Sender).Text);
end;

////////////////////////////////////////////////////////////////////////////////
procedure Obj.VarFilterKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key<>VK_ESCAPE then Exit;
  TEdit(Sender).Text:='';
  Key:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure VarTreeFormCreate;
const
  Caps : Array[0..3] of String = ('Copy Name','-','Copy Value','Set Value');
var
  Cnt  : Integer;
  Item : TMenuItem;
begin
  VReg:=TRegistry.Create;
  VReg.OpenKey('\Software\EasyUO',True);

  DList:=TStringList.Create;

  MForm:=MainForm;
  VList:=MainForm.VarTreeView;

  VList.OnEnter:=Obj(nil).VarListEnter;
  VList.OnChange:=Obj(nil).VarListChange;
  MForm.OnMouseWheel:=Obj(nil).FormMouseWheel;
  MainForm.VarFilterEdit.OnChange:=Obj(nil).VarFilterChange;
  MainForm.VarFilterEdit.OnKeyDown:=Obj(nil).VarFilterKeyDown;

  if VReg.GetDataType('VarTree.Expanded')=rdString then
    ExpState:=VReg.ReadString('VarTree.Expanded');

  NodePopup:=TPopupMenu.Create(nil);
  for Cnt:=0 to High(Caps) do
  begin
    Item:=TMenuItem.Create(nil);
    Item.Caption:=Caps[Cnt];
    Item.Tag:=Cnt;
    Item.OnClick:=Obj(nil).VarPopupClick;
    NodePopup.Items.Add(Item);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure VarTreeFormClose;
begin
  if not Filtered then ExpState:=TreeGetState;
  VReg.WriteString('VarTree.Expanded',ExpState);

  while NodePopup.Items.Count>0 do
    NodePopup.Items[0].Free;
  NodePopup.Free;

  DList.Free;

  VReg.CloseKey;
  VReg.Free;
end;

end.
