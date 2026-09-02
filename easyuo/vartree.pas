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
}

{$mode delphi}{$H+}

interface
uses Windows, Forms, Controls, Classes, Menus, ComCtrls, Registry,
     SysUtils, Clipbrd, Dialogs;

  procedure VarTreeLoad(ListStr : String);
  procedure VarTreeRefresh;
  procedure VarTreeFormCreate;
  procedure VarTreeFormClose;

var
  Identifiers : String =

   '\Character Info'#13#10+
   '#CHARPOSX'#13#10+
   '#CHARPOSY'#13#10+
   '#CHARPOSZ'#13#10+
   '#CHARDIR'#13#10+
   '#CHARSTATUS'#13#10+
   '#CHARID'#13#10+
   '#CHARTYPE'#13#10+
   '#CHARGHOST'#13#10+
   '#BACKPACKID'#13#10+

    #13#10+
   '\Status Bar'#13#10+
   '#CHARNAME'#13#10+
   '#SEX'#13#10+
   '#STR'#13#10+
   '#DEX'#13#10+
   '#INT'#13#10+
   '#HITS'#13#10+
   '#MAXHITS'#13#10+
   '#STAMINA'#13#10+
   '#MAXSTAM'#13#10+
   '#MANA'#13#10+
   '#MAXMANA'#13#10+
   '#MAXSTATS'#13#10+
   '#LUCK'#13#10+
   '#WEIGHT'#13#10+
   '#MAXWEIGHT'#13#10+
   '#MINDMG'#13#10+
   '#MAXDMG'#13#10+
   '#GOLD'#13#10+
   '#FOLLOWERS'#13#10+
   '#MAXFOL'#13#10+
   '#AR'#13#10+
   '#FR'#13#10+
   '#CR'#13#10+
   '#PR'#13#10+
   '#ER'#13#10+
   '#TP'#13#10+

    #13#10+
   '\Container Info'#13#10+
   '#NEXTCPOSX'#13#10+
   '#NEXTCPOSY'#13#10+
   '#CONTPOSX'#13#10+
   '#CONTPOSY'#13#10+
   '#CONTSIZEX'#13#10+
   '#CONTSIZEY'#13#10+
   '#CONTKIND'#13#10+
   '#CONTNAME'#13#10+
   '#CONTID'#13#10+
   '#CONTTYPE'#13#10+
   '#CONTHP'#13#10+

    #13#10+
   '\Last Action'#13#10+
   '#LOBJECTID'#13#10+
   '#LOBJECTTYPE'#13#10+
   '#LTARGETID'#13#10+
   '#LTARGETX'#13#10+
   '#LTARGETY'#13#10+
   '#LTARGETZ'#13#10+
   '#LTARGETKIND'#13#10+
   '#LTARGETTILE'#13#10+
   '#LLIFTEDID'#13#10+
   '#LLIFTEDTYPE'#13#10+
   '#LLIFTEDKIND'#13#10+
   '#LSKILL'#13#10+
   '#LSPELL'#13#10+

    #13#10+
   '\Find Item'#13#10+
   '#FINDID'#13#10+
   '#FINDTYPE'#13#10+
   '#FINDX'#13#10+
   '#FINDY'#13#10+
   '#FINDZ'#13#10+
   '#FINDDIST'#13#10+
   '#FINDKIND'#13#10+
   '#FINDSTACK'#13#10+
   '#FINDBAGID'#13#10+
   '#FINDMOD'#13#10+
   '#FINDREP'#13#10+
   '#FINDCOL'#13#10+
   '#FINDINDEX'#13#10+
   '#FINDCNT'#13#10+

    #13#10+
   '\Shop Info'#13#10+
   '#SHOPCURPOS'#13#10+
   '#SHOPCNT'#13#10+
   '#SHOPITEMTYPE'#13#10+
   '#SHOPITEMID'#13#10+
   '#SHOPITEMNAME'#13#10+
   '#SHOPITEMPRICE'#13#10+
   '#SHOPITEMMAX'#13#10+

    #13#10+
   '\Extended Info'#13#10+
   '#SKILL'#13#10+
   '#SKILLLOCK'#13#10+
   '#SKILLCAP'#13#10+
   '#JOURNAL'#13#10+
   '#JCOLOR'#13#10+
   '#JINDEX'#13#10+
   '#SYSMSG'#13#10+
   '#SYSMSGCOL'#13#10+
   '#TARGCURS'#13#10+
   '#CURSKIND'#13#10+
   '#PROPERTY'#13#10+

    #13#10+
   '\Client Info'#13#10+
   '#CLICNT'#13#10+
   '#CLINR'#13#10+
   '#CLILOGGED'#13#10+
   '#CLIXRES'#13#10+
   '#CLIYRES'#13#10+
   '#CLILEFT'#13#10+
   '#CLITOP'#13#10+
   '#CLIVER'#13#10+
   '#CLILANG'#13#10+
   '#CLITITLE'#13#10+

    #13#10+
   '\Combat Info'#13#10+
   '#LHANDID'#13#10+
   '#RHANDID'#13#10+
   '#ENEMYHITS'#13#10+
   '#ENEMYID'#13#10+

    #13#10+
   '\Tile Info'#13#10+
   '#TILETYPE'#13#10+
   '#TILEZ'#13#10+
   '#TILECNT'#13#10+
   '#TILENAME'#13#10+
   '#TILEFLAGS'#13#10+

    #13#10+
   '\Time Info'#13#10+
   '#TIME'#13#10+
   '#DATE'#13#10+
   '#SYSTIME'#13#10+
   '#SCNT'#13#10+
   '#SCNT2'#13#10+

    #13#10+
   '\Miscellaneous'#13#10+
   '#SHARD'#13#10+
   '#LSHARD'#13#10+
   '#PIXCOL'#13#10+
   '#CURSORX'#13#10+
   '#CURSORY'#13#10+
   '#RANDOM'#13#10+
   '#MENUBUTTON'#13#10+
   '#SENDHEADER'#13#10+
   '#NSNAME'#13#10+
   '#NSTYPE'#13#10+
   '#LPC'#13#10+
   '#EUOVER'#13#10+
   '#REFORGEDVER'#13#10+
   '#OPTS'#13#10+
   '#OSVER'#13#10+

    #13#10+
   '\Result Variables'#13#10+
   '#DISPRES'#13#10+
   '#MENURES'#13#10+
   '#STRRES'#13#10+
   '#RESULT';

var
  DList     : TStringList;

////////////////////////////////////////////////////////////////////////////////
implementation
uses Main, InstHandler;
var
  VReg      : TRegistry;
  NodePopup : TPopupMenu;
  NodeStr   : String;
  VList     : TTreeView;
  MForm     : TForm;
  UserNode  : TTreeNode = nil;

////////////////////////////////////////////////////////////////////////////////
procedure TreeLoadSaveState(Load : Boolean; Tag : Integer);
var
  sBuf  : String;
  tNode : TTreeNode;
  Tree  : Char;
begin
  Tree:=Char(Tag+48);

  if Load then
  begin
    if VReg.GetDataType('Tree'+Tree+'.State')<>rdString then Exit;
    sBuf:=VReg.ReadString('Tree'+Tree+'.State');
    tNode:=VList.Items.GetFirstNode;
    while tNode<>nil do
    begin
      if sBuf='' then Break;
      if tNode.Data<>nil then
      begin
        tNode.Expanded:=sBuf[1]='-';
        Delete(sBuf,1,1);
      end;
      tNode:=tNode.GetNext;
    end;
  end;

  if not Load then
  begin
    sBuf:='';
    tNode:=VList.Items.GetFirstNode;
    while tNode<>nil do
    begin
      if tNode.Data<>nil then
      if tNode.Expanded then sBuf:=sBuf+'-'
      else sBuf:=sBuf+'+';
      tNode:=tNode.GetNext;
    end;
    VReg.WriteString('Tree'+Tree+'.State',sBuf);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure VarTreeLoad(ListStr : String);
var
  List       : TStringList;
  sBuf1      : String;
  sBuf2      : String;
  iBuf       : Integer;
  ParentNode : TTreeNode;
  TmpNode    : TTreeNode;
begin
  VList.Items.Clear;

  List:=TStringList.Create;
  List.Text:=Identifiers;

  ParentNode:=nil;
  while List.Count>0 do
  begin
    sBuf1:=Trim(List[0]);
    List.Delete(0);
    if sBuf1='' then Continue;

    if sBuf1[1]='\' then
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

      Continue;
    end;

    VList.Items.AddChildObject(ParentNode,sBuf1+': N/A',Pointer(0));
  end;

  List.Free;
  TreeLoadSaveState(True,0);
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
  TreeLoadSaveState(False,0);

  while NodePopup.Items.Count>0 do
    NodePopup.Items[0].Free;
  NodePopup.Free;

  DList.Free;

  VReg.CloseKey;
  VReg.Free;
end;

end.
