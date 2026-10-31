unit EuoMenu16;

{
  Port addition: the MENU command as EasyUO 1.6 (build 1.6.0.337) implements it -- the "1.6
  logic" a script runs under when EuoMenuSelect chooses it. EasyUO 1.6 is closed source; this is
  a port of its behaviour as read from the binary and recorded from it at runtime, documented in
  docs/menu-1.6-analysis.md (section 3) and pinned by the golden values in tests/fixtures/menu16
  (tests/tools/Record16MenuGolden.py). The 1.5 logic stays in EuoMenu.pas, untouched by this unit;
  the window and button classes, the Symbol-font handling and the image primitives are shared
  with it through EuoMenuCommon.pas.

  Where it comes from in the binary (addresses in easyuo.exe):
  - TMenu16.Run is TOldParser.MenuProc ($4c120c): the same argument checks, in the same order.
    Its sub-commands are independent ifs there; they are distinct words, so an else-if chain
    behaves the same, and a failed check ends the line.
  - The registry (Find/AddCtrl/RemoveCtrl/FreeCtrl) is TObjMgr ($4ae364): names stored
    lower-case; a nil control, an empty name, a control already registered or a name already
    taken is refused, and the refused control stays where it is, unreachable. Removing a
    container first detaches every child and removes the registered ones; an unregistered
    child is only detached.
  - TMenu16Default is TDefault ($4ae7ac): a control whose Font, Color, Parent and Alignment
    are what the next control is created with. It is a child of the current default container,
    so deleting that container leaves the default parent nil, as in 1.6.
  - The property table (Props) is the table at $4cd9d0: first row whose name matches and
    whose type mask contains the control's type; GetProp reads, SetProp reads first (which
    sets the last string result, as GetProp does) and then writes.
  - StrRes is the menu object's last string result ([TMenu2Obj+$14]): every string property
    read writes it, and "getprop x parent" copies it to #MenuRes even when the parent has no
    name, which is where 1.6's stale parent value comes from.
  - ScriptStart is TOldParser.Clear ($4bc914): everything destroyed, a new hidden form0 at
    100,100 with a 295 x 170 client area that the frame change makes 305 x 180 (FrameGrowth).

  Deliberate deviations, each because 1.6 would crash or corrupt memory, or because LCL forces it:
  - "menu image ..." on a name that is not an image does nothing; 1.6 draws through TImage's
    canvas on whatever control has the name. "menu image pos" still moves any control, as in
    1.6, but only an image gets Stretch. A shape whose name is taken draws on the registered
    control of that name only if it is an image.
  - show/hide/window need form0 to be a form: after "menu delete form0" another control can be
    called form0, and 1.6 would then call form methods on it.
  - A control is never moved into itself or into one of its own children: VCL raises for the
    first and nothing stopped the second. "menu activate" focuses only a control that can take
    the focus; VCL raised for the others.
  - "list select" out of range leaves the selection alone (LCL raises where VCL's
    LB_SETCURSEL failed quietly).
  - Controls that 1.6 leaves unreachable (duplicate names, children of a deleted container)
    are kept, hidden or detached, as in 1.6 -- a duplicate form even survives the next start --
    but freed with the interpreter instead of leaking.
  - LCL sizes labels and edits differently from VCL (a label one pixel taller, and not at all
    while its form is hidden; an edit one pixel shorter). TMenu16Label.FitText and FitEdit do
    what VCL's TCustomLabel.AdjustBounds and TCustomEdit.AdjustHeight did, when VCL did it:
    on a text or font change.
  - Shared with the 1.5 logic (EuoMenuCommon.pas, EuoMenu.pas): TEuoMenuButton for
    TBitBtnWithColor, 24 bpp images, TPicture for TOleGraphic, Symbol-font remapping, and
    every control on the form's Surface panel. Check and radio buttons keep the alignment value
    as written in Tag (LCL's TLeftRight cannot hold 2, which 1.6 stores and reads back).
  - Colours are read and written as Delphi 7 numbers (ColorToVcl/ColorFromVcl): system colours
    are $FF0000xx there and $800000xx in LCL.
  - What LCL does differently and is put back here: a form's size is clamped to Windows'
    minimum window size at once (SetFormClientWidth); rectangles on images get square corners
    (DrawRectangle).
  - What is left different: a panel asked for a negative size reads back 0 (VCL kept the
    number while the panel had no window), and "menu image file" draws the whole picture,
    where 1.6's OLE loader lost the last column of a bitmap to its HIMETRIC rounding.

  Reforged addition: "menu memo", with the 1.5 syntax, as a control type of its own (MT_MEMO)
  that has the properties of an edit; its text turns "$" into line breaks and back.

  Not done here: the repaint bursts TMenuObj holds while a script rebuilds a visible window.

  Read-only views for the MENU designer (tools/EUOMenuDesigner, docs/menu-designer.md), which
  builds its canvas and reads scripts back through this unit: the registry (RegistryCount and
  RegistryName/Kind/Ctrl) and the property table (Menu16PropCount, Menu16PropRow). Nothing at
  runtime reads them, and they change nothing.
}

{$mode delphi}{$H+}

interface
uses
  Windows, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  LCLType, EuoTokens, EuoConversion, EuoMenuCommon;

const
  // Control types, as in 1.6's table at $4cd958; the property table masks on them.
  MT_FORM    = $001;
  MT_PANEL   = $002;
  MT_TEXT    = $004;
  MT_BUTTON  = $008;
  MT_EDIT    = $010;
  MT_CHECK   = $020;
  MT_RADIO   = $040;
  MT_COMBO   = $080;
  MT_LIST    = $100;
  MT_IMAGE   = $200;
  MT_DEFAULT = $400;
  MT_MEMO    = $800;   // Reforged addition

  PT_STR  = 1;   // the types 1.6's GetProp returns
  PT_INT  = 2;
  PT_BOOL = 3;

type
  TMenu16Default = class(TControl)
  public
    Alignment   : Integer;
    constructor Create(AOwner : TComponent); override;
  end;

  // A label sized the VCL way (see FitText); LCL's AutoSize is off.
  TMenu16Label = class(TLabel)
  public
    procedure   FitText;
  end;

  TMenu16Item = class(TObject)
  public
    Name        : String;     // lower-case
    Ctrl        : TControl;
    Kind        : Integer;    // MT_*
    RawText     : String;     // the caption as written, when Symbol-font remapping changed it
    HasRaw      : Boolean;
  end;

  TMenu16 = class(TObject)
  private
    Items       : TList;      // TMenu16Item: the registry
    Created     : TList;      // every control made here, registered or not
    Protect     : TControl;   // not freed by FreeCtrl (form0 during "menu clear")
    Def         : TMenu16Default;
    DefStack    : TList;      // pushdef copies, oldest first
    FMenuButton : String;
    StrRes      : String;
    P           : TParList;   // the line Run is running
    function    Rest(Nr : Integer) : String;
    function    Find(const Name : String; out Item : TMenu16Item) : Boolean;
    function    FindCtrl(const Name : String) : TControl;
    function    IndexOfCtrl(C : TControl) : Integer;
    function    NameOf(C : TControl; out Name : String) : Boolean;
    function    AddCtrl(C : TControl; const Name : String; Kind : Integer) : TMenu16Item;
    procedure   RemoveCtrl(C : TControl);
    procedure   FreeCtrl(C : TControl);
    procedure   ClearMenu;
    procedure   FreeOrphans;
    procedure   ResetDefault;
    function    DefBox : TWinControl;
    procedure   SetDefParent(C : TWinControl);
    function    Form0 : TEuoMenuForm;
    procedure   Reparent(C : TControl; const Target : String);
    procedure   SetCaption(Item : TMenu16Item; C : TControl; const Str : String);
    function    CaptionOf(Item : TMenu16Item; C : TControl) : String;
    function    GetProp(Item : TMenu16Item; C : TControl; Kind : Integer; const PName : String;
                  out IVal : Integer; out BVal : Boolean) : Integer;
    procedure   SetProp(Item : TMenu16Item; C : TControl; Kind : Integer; const PName,
                  SVal : String; IVal : Int64);
    procedure   ShowRes(PType : Integer; IVal : Integer; BVal : Boolean);
    procedure   PushDef;
    procedure   PopDef;
    procedure   MenuClear;
    procedure   Activate(const Name : String);
    procedure   Get(const Name : String);
    procedure   _Set(const Name, Str : String);
    procedure   FormCreate(const Name : String; X,Y,W,H : Integer; const Cap : String);
    procedure   PanelCreate(const Name : String; X,Y,W,H : Integer);
    procedure   TextCreate(const Name : String; X,Y : Integer; const Str : String);
    procedure   ButtonCreate(const Name : String; X,Y,W,H : Integer; const Str : String);
    procedure   EditCreate(const Name : String; X,Y,W : Integer; const Str : String);
    procedure   MemoCreate(const Name : String; X,Y,W,H : Integer; const Str : String);
    procedure   CheckCreate(const Name : String; X,Y,W,H : Integer; C : Boolean;
                  const Str : String; Radio : Boolean);
    procedure   ComboCreate(const Name : String; X,Y,W : Integer);
    procedure   ListCreate(const Name : String; X,Y,W,H : Integer);
    procedure   ComboListAdd(const Name, Str : String);
    procedure   ComboListSelect(const Name : String; Ind : Integer);
    procedure   ComboListClear(const Name : String);
    procedure   ImageCreate(const Name : String; X,Y,W,H : Integer);
    function    FindImage(const Name : String; out Img : TImage) : Boolean;
    procedure   ShapeCreate(const Name : String; X,Y,W,H,ST,LW,LC,FC : Integer;
                  LineOn,FillOn : Boolean);
    procedure   RunWindow;
    procedure   RunFont;
    procedure   RunImage;
    procedure   FormClose(Sender : TObject; var CloseAction : TCloseAction);
    procedure   ButtonClick(Sender : TObject);
    procedure   ComboSelect(Sender : TObject);
  public
    MenuRes     : String;
    constructor Create;
    destructor  Destroy; override;
    procedure   ScriptStart;
    procedure   Run(Pars : TParList);
    function    GetMenuButton : String;
    procedure   SetMenuButton(const Value : String);
    function    RegistryCount : Integer;
    function    RegistryName(Index : Integer) : String;
    function    RegistryKind(Index : Integer) : Integer;
    function    RegistryCtrl(Index : Integer) : TControl;
  end;

function  Menu16PropCount : Integer;
procedure Menu16PropRow(Index : Integer; out Name : String; out PType, Mask : Integer);

implementation

type
  TPropRow = record
    Name  : String;
    Id    : Integer;
    PType : Integer;
    Mask  : Integer;
  end;

const
  PI_ALIGNMENT = 0;  PI_CHECKED = 1;  PI_COLOR = 2;  PI_ENABLED = 3;  PI_FONTCOLOR = 4;
  PI_FONTNAME = 5;  PI_FONTSIZE = 6;  PI_FONTSTYLE = 7;  PI_CLIENTHEIGHT = 8;  PI_HEIGHT = 9;
  PI_LEFT = 10;  PI_PARENT = 11;  PI_CAPTION = 12;  PI_TEXT = 13;  PI_TOOLTIP = 14;  PI_TOP = 15;
  PI_VISIBLE = 16;  PI_CLIENTWIDTH = 17;  PI_WIDTH = 18;

  // The table at $4cd9d0, plus MT_MEMO wherever edit has the property.
  Props : array[0..18] of TPropRow = (
    (Name:'alignment'; Id:PI_ALIGNMENT;    PType:PT_INT;  Mask:$464),
    (Name:'checked';   Id:PI_CHECKED;      PType:PT_BOOL; Mask:$060),
    (Name:'color';     Id:PI_COLOR;        PType:PT_INT;  Mask:$5FF or MT_MEMO),
    (Name:'enabled';   Id:PI_ENABLED;      PType:PT_BOOL; Mask:$3FF or MT_MEMO),
    (Name:'fontcolor'; Id:PI_FONTCOLOR;    PType:PT_INT;  Mask:$5FC or MT_MEMO),
    (Name:'fontname';  Id:PI_FONTNAME;     PType:PT_STR;  Mask:$5FC or MT_MEMO),
    (Name:'fontsize';  Id:PI_FONTSIZE;     PType:PT_INT;  Mask:$5FC or MT_MEMO),
    (Name:'fontstyle'; Id:PI_FONTSTYLE;    PType:PT_INT;  Mask:$5FC or MT_MEMO),
    (Name:'height';    Id:PI_CLIENTHEIGHT; PType:PT_INT;  Mask:MT_FORM),
    (Name:'height';    Id:PI_HEIGHT;       PType:PT_INT;  Mask:$3FE or MT_MEMO),
    (Name:'left';      Id:PI_LEFT;         PType:PT_INT;  Mask:$3FF or MT_MEMO),
    (Name:'parent';    Id:PI_PARENT;       PType:PT_STR;  Mask:$7FE or MT_MEMO),
    (Name:'text';      Id:PI_CAPTION;      PType:PT_STR;  Mask:$06D),
    (Name:'text';      Id:PI_TEXT;         PType:PT_STR;  Mask:MT_EDIT or MT_MEMO),
    (Name:'tooltip';   Id:PI_TOOLTIP;      PType:PT_STR;  Mask:$3FF or MT_MEMO),
    (Name:'top';       Id:PI_TOP;          PType:PT_INT;  Mask:$3FF or MT_MEMO),
    (Name:'visible';   Id:PI_VISIBLE;      PType:PT_BOOL; Mask:$3FF or MT_MEMO),
    (Name:'width';     Id:PI_CLIENTWIDTH;  PType:PT_INT;  Mask:MT_FORM),
    (Name:'width';     Id:PI_WIDTH;        PType:PT_INT;  Mask:$3FE or MT_MEMO));

////////////////////////////////////////////////////////////////////////////////
function FindProp(const PName : String; Kind : Integer) : Integer;
var
  Cnt   : Integer;
  Lower : String;
begin
  Lower:=LowerCase(PName);
  for Cnt:=Low(Props) to High(Props) do
    if (Props[Cnt].Name=Lower) and ((Props[Cnt].Mask and Kind)<>0) then Exit(Cnt);
  Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
function Menu16PropCount : Integer;
begin
  Result:=Length(Props);
end;

procedure Menu16PropRow(Index : Integer; out Name : String; out PType, Mask : Integer);
begin
  Name:=Props[Low(Props)+Index].Name;
  PType:=Props[Low(Props)+Index].PType;
  Mask:=Props[Low(Props)+Index].Mask;
end;

////////////////////////////////////////////////////////////////////////////////
// How much bigger a form's client area ends up than asked for. 1.6 sets the client size
// while the form still has its default sizeable frame, then gives it a single frame; VCL
// keeps the outer size, so the client area grows by the difference between the two frames
// (10 px each way on Windows 10/11).
function FrameGrowth : Integer;
var
  Sizeable : TRect;
  Single   : TRect;
begin
  Sizeable:=Rect(0,0,100,100);
  Single:=Sizeable;
  AdjustWindowRectEx(@Sizeable,WS_CAPTION or WS_THICKFRAME or WS_SYSMENU or
    WS_MINIMIZEBOX or WS_MAXIMIZEBOX,False,0);
  AdjustWindowRectEx(@Single,WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,False,0);
  Result:=(Sizeable.Right-Sizeable.Left)-(Single.Right-Single.Left);
end;

////////////////////////////////////////////////////////////////////////////////
// Windows keeps a captioned window at least SM_CXMINTRACK x SM_CYMINTRACK. VCL put a form's
// size on its window at once and read the clamped size back (a form asked for 10 px is 130
// px wide); LCL keeps the size asked for while the window is hidden, so the clamp is done here.
function MinClient(Horizontal : Boolean) : Integer;
var
  Frame : TRect;
begin
  Frame:=Rect(0,0,0,0);
  AdjustWindowRectEx(@Frame,WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,False,0);
  if Horizontal then Result:=GetSystemMetrics(SM_CXMINTRACK)-(Frame.Right-Frame.Left)
  else Result:=GetSystemMetrics(SM_CYMINTRACK)-(Frame.Bottom-Frame.Top);
end;

procedure SetFormClientWidth(F : TCustomForm; W : Integer);
begin
  if W<MinClient(True) then W:=MinClient(True);
  F.ClientWidth:=W;
end;

procedure SetFormClientHeight(F : TCustomForm; H : Integer);
begin
  if H<MinClient(False) then H:=MinClient(False);
  F.ClientHeight:=H;
end;

////////////////////////////////////////////////////////////////////////////////
// The Delphi set TFontStyles as 1.6 reads and writes it: bit 1 bold, 2 italic, 4 underline,
// 8 strike-out.
function StyleToInt(S : TFontStyles) : Integer;
begin
  Result:=0;
  if fsBold in S then Result:=Result or 1;
  if fsItalic in S then Result:=Result or 2;
  if fsUnderline in S then Result:=Result or 4;
  if fsStrikeOut in S then Result:=Result or 8;
end;

function IntToStyle(V : Integer) : TFontStyles;
begin
  Result:=[];
  if V and 1<>0 then Include(Result,fsBold);
  if V and 2<>0 then Include(Result,fsItalic);
  if V and 4<>0 then Include(Result,fsUnderline);
  if V and 8<>0 then Include(Result,fsStrikeOut);
end;

////////////////////////////////////////////////////////////////////////////////
procedure SetSymbolCharSet(F : TFont);
begin
  if IsSymbolFontName(F.Name) then F.CharSet:=SYMBOL_CHARSET
  else F.CharSet:=DEFAULT_CHARSET;
end;

////////////////////////////////////////////////////////////////////////////////
// A check box's alignment as 1.6 reads and writes it is mirrored (0 <-> 1); a radio
// button's is not.
function SwapAlign(V : Integer) : Integer;
begin
  case V of
    0: Result:=1;
    1: Result:=0;
  else Result:=V;
  end;
end;

// Tag holds the value as written; on screen 0 is text on the left, anything else on the
// right (VCL indexed past its two-entry table for 2 and got the right).
procedure ApplyCheckAlign(C : TControl);
var
  A : TLeftRight;
begin
  if C.Tag=0 then A:=taLeftJustify else A:=taRightJustify;
  if C is TRadioButton then TRadioButton(C).Alignment:=A
  else TCheckBox(C).Alignment:=A;
end;

////////////////////////////////////////////////////////////////////////////////
// Controls on a form live on its Surface panel; to the script the form is their parent.
function ParentOf(C : TControl) : TWinControl;
begin
  Result:=C.Parent;
  if (Result<>nil) and (Result.Owner is TEuoMenuForm) and
     (TEuoMenuForm(Result.Owner).Surface=Result) then
    Result:=TEuoMenuForm(Result.Owner);
end;

function ContainerOf(C : TWinControl) : TWinControl;
begin
  Result:=C;
  if C is TEuoMenuForm then Result:=TEuoMenuForm(C).Surface;
end;

////////////////////////////////////////////////////////////////////////////////
// VCL's TCustomEdit.AdjustHeight: the font's text height plus 8 border pixels.
procedure FitEdit(E : TEdit);
var
  DC  : HDC;
  Old : HGDIOBJ;
  TM  : Windows.TTextMetric;
begin
  DC:=GetDC(0);
  Old:=SelectObject(DC,E.Font.Reference.Handle);
  GetTextMetrics(DC,TM);
  SelectObject(DC,Old);
  ReleaseDC(0,DC);
  E.Height:=TM.tmHeight+GetSystemMetrics(SM_CYBORDER)*8;
end;

////////////////////////////////////////////////////////////////////////////////
// VCL's TCustomLabel.AdjustBounds: the text measured with DrawText on the screen, the label
// resized to it; a right-aligned label keeps its right edge. An empty text measures as a space.
procedure TMenu16Label.FitText;
var
  DC    : HDC;
  Old   : HGDIOBJ;
  R     : TRect;
  S     : UnicodeString;
  X     : Integer;
  Flags : Cardinal;
begin
  S:=UTF8Decode(Caption);
  if (S='') or (ShowAccelChar and (S='&')) then S:=S+' ';
  Flags:=DT_EXPANDTABS or DT_CALCRECT;
  if WordWrap then Flags:=Flags or DT_WORDBREAK;
  if not ShowAccelChar then Flags:=Flags or DT_NOPREFIX;
  R:=Rect(0,0,Width,Height);
  DC:=GetDC(0);
  Old:=SelectObject(DC,Font.Reference.Handle);
  DrawTextW(DC,PWideChar(S),Length(S),R,Flags);
  SelectObject(DC,Old);
  ReleaseDC(0,DC);
  X:=Left;
  if Alignment=taRightJustify then Inc(X,Width-R.Right);
  SetBounds(X,Top,R.Right,R.Bottom);
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TMenu16Default.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  Visible:=False;
  SetBounds(0,0,0,0);
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TMenu16.Create;
begin
  inherited Create;
  Items:=TList.Create;
  Created:=TList.Create;
  DefStack:=TList.Create;
  Def:=TMenu16Default.Create(nil);
  ResetDefault;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TMenu16.Destroy;
begin
  Protect:=nil;
  ClearMenu;
  FreeOrphans;
  Def.Free;
  DefStack.Free;
  Created.Free;
  Items.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
// TOldParser.Clear: a stopped script starting.
procedure TMenu16.ScriptStart;
begin
  Protect:=nil;
  ClearMenu;
  MenuRes:='';
  FormCreate('form0',100,100,295,170,'EUO Menu');
end;

////////////////////////////////////////////////////////////////////////////////
function TMenu16.GetMenuButton : String;
begin
  if FMenuButton='form0' then Result:='CLOSED'
  else Result:=FMenuButton;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.SetMenuButton(const Value : String);
begin
  FMenuButton:=Value;
end;

////////////////////////////////////////////////////////////////////////////////
// The registry in registration order, read-only (see the unit header).
function TMenu16.RegistryCount : Integer;
begin
  Result:=Items.Count;
end;

function TMenu16.RegistryName(Index : Integer) : String;
begin
  Result:=TMenu16Item(Items[Index]).Name;
end;

function TMenu16.RegistryKind(Index : Integer) : Integer;
begin
  Result:=TMenu16Item(Items[Index]).Kind;
end;

function TMenu16.RegistryCtrl(Index : Integer) : TControl;
begin
  Result:=TMenu16Item(Items[Index]).Ctrl;
end;

////////////////////////////////////////////////////////////////////////////////
// TOldParser.GetParStr: the words from Nr on, as one string.
function TMenu16.Rest(Nr : Integer) : String;
var
  Cnt : Integer;
begin
  Result:='';
  for Cnt:=Nr to Integer(P.Count)-1 do
    Result:=Result+P[Cnt].Str+' ';
  Result:=Trim(Result);
end;

////////////////////////////////////////////////////////////////////////////////
// The registry.
function TMenu16.Find(const Name : String; out Item : TMenu16Item) : Boolean;
var
  Cnt   : Integer;
  Lower : String;
begin
  Lower:=LowerCase(Name);
  for Cnt:=0 to Items.Count-1 do
  begin
    Item:=TMenu16Item(Items[Cnt]);
    if Item.Name=Lower then Exit(True);
  end;
  Item:=nil;
  Result:=False;
end;

function TMenu16.FindCtrl(const Name : String) : TControl;
var
  Item : TMenu16Item;
begin
  if Find(Name,Item) then Result:=Item.Ctrl
  else Result:=nil;
end;

function TMenu16.IndexOfCtrl(C : TControl) : Integer;
begin
  for Result:=0 to Items.Count-1 do
    if TMenu16Item(Items[Result]).Ctrl=C then Exit;
  Result:=-1;
end;

function TMenu16.NameOf(C : TControl; out Name : String) : Boolean;
var
  Cnt : Integer;
begin
  Cnt:=IndexOfCtrl(C);
  Result:=(C<>nil) and (Cnt>=0);
  if Result then Name:=TMenu16Item(Items[Cnt]).Name;
end;

function TMenu16.AddCtrl(C : TControl; const Name : String; Kind : Integer) : TMenu16Item;
var
  Dup : TMenu16Item;
begin
  Result:=nil;
  if (C=nil) or (Name='') then Exit;
  if IndexOfCtrl(C)>=0 then Exit;
  if Find(Name,Dup) then Exit;
  Result:=TMenu16Item.Create;
  Result.Name:=LowerCase(Name);
  Result.Ctrl:=C;
  Result.Kind:=Kind;
  Items.Add(Result);
end;

////////////////////////////////////////////////////////////////////////////////
// TObjMgr's RemoveByPtr: unregister C, then free it (FreeCtrl).
procedure TMenu16.RemoveCtrl(C : TControl);
var
  Cnt : Integer;
begin
  Cnt:=IndexOfCtrl(C);
  if Cnt<0 then Exit;
  TMenu16Item(Items[Cnt]).Free;
  Items.Delete(Cnt);
  FreeCtrl(C);
end;

////////////////////////////////////////////////////////////////////////////////
// TObjMgr's FreeItem: detach every child, removing the registered ones; then free C
// unless it is protected. An unregistered child is only detached (FreeOrphans frees it
// with the interpreter).
procedure TMenu16.FreeCtrl(C : TControl);
var
  Box   : TWinControl;
  Child : TControl;
begin
  if C is TWinControl then
  begin
    Box:=ContainerOf(TWinControl(C));
    while Box.ControlCount>0 do
    begin
      Child:=Box.Controls[0];
      Child.Parent:=nil;
      RemoveCtrl(Child);
    end;
  end;
  if C=Protect then Exit;
  Created.Remove(C);
  C.Free;
end;

////////////////////////////////////////////////////////////////////////////////
// TMenu2Obj.Clear ($4af344).
procedure TMenu16.ClearMenu;
var
  Cnt : Integer;
begin
  while Items.Count>0 do
    RemoveCtrl(TMenu16Item(Items[0]).Ctrl);
  for Cnt:=0 to DefStack.Count-1 do
    TObject(DefStack[Cnt]).Free;
  DefStack.Clear;
  ResetDefault;
  FMenuButton:='';
  StrRes:='';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.FreeOrphans;
var
  Cnt : Integer;
begin
  for Cnt:=Created.Count-1 downto 0 do
    TControl(Created[Cnt]).Parent:=nil;
  for Cnt:=Created.Count-1 downto 0 do
    TControl(Created[Cnt]).Free;
  Created.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ResetDefault;
begin
  Def.Alignment:=0;
  Def.Color:=clBtnFace;
  Def.Font.Name:='Arial';
  Def.Font.Size:=10;
  Def.Font.Style:=[];
  Def.Font.Color:=clBlack;
  SetSymbolCharSet(Def.Font);
  Def.Parent:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
function TMenu16.DefBox : TWinControl;
begin
  Result:=Def.Parent;
end;

procedure TMenu16.SetDefParent(C : TWinControl);
begin
  if C=nil then Def.Parent:=nil
  else Def.Parent:=ContainerOf(C);
end;

function TMenu16.Form0 : TEuoMenuForm;
var
  C : TControl;
begin
  C:=FindCtrl('form0');
  if C is TEuoMenuForm then Result:=TEuoMenuForm(C)
  else Result:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
// "setprop c parent p" / "setdef parent p": into a registered windowed control.
procedure TMenu16.Reparent(C : TControl; const Target : String);
var
  T   : TControl;
  Box : TWinControl;
  Up  : TWinControl;
begin
  T:=FindCtrl(Target);
  if not (T is TWinControl) then Exit;
  Box:=ContainerOf(TWinControl(T));
  Up:=Box;
  while Up<>nil do
  begin
    if Up=C then Exit;   // into itself or one of its own children
    Up:=Up.Parent;
  end;
  try
    C.Parent:=Box;
  except
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.SetCaption(Item : TMenu16Item; C : TControl; const Str : String);
var
  Shown : String;
begin
  if C is TEuoMenuForm then Shown:=Str
  else Shown:=RemapForSymbolFont(Str,C.Font.Name);
  C.Caption:=Shown;
  if C is TMenu16Label then TMenu16Label(C).FitText;
  if Item<>nil then
  begin
    Item.RawText:=Str;
    Item.HasRaw:=Shown<>Str;
  end;
end;

function TMenu16.CaptionOf(Item : TMenu16Item; C : TControl) : String;
begin
  if (Item<>nil) and Item.HasRaw then Result:=Item.RawText
  else Result:=C.Caption;
end;

////////////////////////////////////////////////////////////////////////////////
// GetProp ($4aeca0). Returns the property's type, 0 if C has no such property.
function TMenu16.GetProp(Item : TMenu16Item; C : TControl; Kind : Integer;
  const PName : String; out IVal : Integer; out BVal : Boolean) : Integer;
var
  Row  : Integer;
  Name : String;
begin
  IVal:=0;
  BVal:=False;
  Row:=FindProp(PName,Kind);
  if Row<0 then Exit(0);
  Result:=Props[Row].PType;

  case Props[Row].Id of
    PI_ALIGNMENT:
      if C is TMenu16Default then IVal:=TMenu16Default(C).Alignment
      else if Kind=MT_CHECK then IVal:=SwapAlign(C.Tag)
      else if Kind=MT_RADIO then IVal:=C.Tag
      else IVal:=Ord(TLabel(C).Alignment);
    PI_CHECKED:
      if C is TRadioButton then BVal:=TRadioButton(C).Checked
      else BVal:=TCheckBox(C).Checked;
    PI_COLOR:        IVal:=ColorToVcl(C.Color);
    PI_ENABLED:      BVal:=C.Enabled;
    PI_FONTCOLOR:    IVal:=ColorToVcl(C.Font.Color);
    PI_FONTNAME:     StrRes:=C.Font.Name;
    PI_FONTSIZE:     IVal:=C.Font.Size;
    PI_FONTSTYLE:    IVal:=StyleToInt(C.Font.Style);
    PI_CLIENTHEIGHT: IVal:=TCustomForm(C).ClientHeight;
    PI_HEIGHT:       IVal:=C.Height;
    PI_LEFT:         IVal:=C.Left;
    PI_PARENT:       if NameOf(ParentOf(C),Name) then StrRes:=Name;
    PI_CAPTION:      StrRes:=CaptionOf(Item,C);
    PI_TEXT:
      if Kind=MT_MEMO then
        StrRes:=ReplaceStr(ReplaceStr(TMemo(C).Text,#13#10,'$'),#10,'$')
      else StrRes:=TEdit(C).Text;
    PI_TOOLTIP:      StrRes:=C.Hint;
    PI_TOP:          IVal:=C.Top;
    PI_VISIBLE:      BVal:=C.Visible;
    PI_CLIENTWIDTH:  IVal:=TCustomForm(C).ClientWidth;
    PI_WIDTH:        IVal:=C.Width;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// SETPROP/SETDEF: read the property first (its type, and the last string result as a side
// effect, as in 1.6), then write it. Strings take SVal; integers the low 32 bits of IVal with
// no validity check ("red" is 0); booleans IVal<>0.
procedure TMenu16.SetProp(Item : TMenu16Item; C : TControl; Kind : Integer;
  const PName, SVal : String; IVal : Int64);
var
  Row  : Integer;
  Old  : Integer;
  OldB : Boolean;
  V    : Integer;
  B    : Boolean;
begin
  if GetProp(Item,C,Kind,PName,Old,OldB)=0 then Exit;
  Row:=FindProp(PName,Kind);
  V:=Integer(IVal);
  B:=IVal<>0;

  case Props[Row].Id of
    PI_ALIGNMENT:
      if C is TMenu16Default then TMenu16Default(C).Alignment:=V
      else if (Kind=MT_CHECK) or (Kind=MT_RADIO) then
      begin
        if Kind=MT_CHECK then C.Tag:=SwapAlign(V) else C.Tag:=V;
        ApplyCheckAlign(C);
      end
      else if (V>=0) and (V<=2) then TLabel(C).Alignment:=TAlignment(V);
    PI_CHECKED:
      if C is TRadioButton then TRadioButton(C).Checked:=B
      else TCheckBox(C).Checked:=B;
    PI_COLOR:        C.Color:=ColorFromVcl(V);
    PI_ENABLED:      C.Enabled:=B;
    PI_FONTCOLOR:    C.Font.Color:=ColorFromVcl(V);
    PI_FONTNAME:
      begin
        C.Font.Name:=SVal;
        SetSymbolCharSet(C.Font);
      end;
    PI_FONTSIZE:     C.Font.Size:=V;
    PI_FONTSTYLE:    C.Font.Style:=IntToStyle(V);
    PI_CLIENTHEIGHT: SetFormClientHeight(TCustomForm(C),V);
    PI_HEIGHT:       C.Height:=V;
    PI_LEFT:         C.Left:=V;
    PI_PARENT:       Reparent(C,SVal);
    PI_CAPTION:      SetCaption(Item,C,SVal);
    PI_TEXT:
      if Kind=MT_MEMO then TMemo(C).Text:=ReplaceStr(SVal,'$',#13#10)
      else TEdit(C).Text:=SVal;
    PI_TOOLTIP:      C.Hint:=SVal;
    PI_TOP:          C.Top:=V;
    PI_VISIBLE:      C.Visible:=B;
    PI_CLIENTWIDTH:  SetFormClientWidth(TCustomForm(C),V);
    PI_WIDTH:        C.Width:=V;
  end;

  // VCL refits a label and an edit whenever their font changes
  if (Props[Row].Id>=PI_FONTCOLOR) and (Props[Row].Id<=PI_FONTSTYLE) then
    if C is TMenu16Label then TMenu16Label(C).FitText
    else if C is TEdit then FitEdit(TEdit(C));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ShowRes(PType : Integer; IVal : Integer; BVal : Boolean);
begin
  case PType of
    PT_STR:  MenuRes:=StrRes;
    PT_INT:  MenuRes:=IntToStr(IVal);
    PT_BOOL: if BVal then MenuRes:='-1' else MenuRes:='0';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// PushDef ($4af3ec): a copy of the font, colour and parent -- not the alignment -- goes to
// the end of the list. PopDef ($4af438): the current default is dropped and the FIRST copy
// in the list takes its place, so nested pushes come back in the wrong order.
procedure TMenu16.PushDef;
var
  D : TMenu16Default;
begin
  D:=TMenu16Default.Create(nil);
  D.Font.Assign(Def.Font);
  D.Color:=Def.Color;
  D.Parent:=Def.Parent;
  DefStack.Add(D);
end;

procedure TMenu16.PopDef;
begin
  if DefStack.Count=0 then Exit;
  Def.Free;
  Def:=TMenu16Default(DefStack[0]);
  DefStack.Delete(0);
end;

////////////////////////////////////////////////////////////////////////////////
// "menu clear": everything but form0 goes; form0 keeps its position, size, caption and
// colour, and is the default parent again.
procedure TMenu16.MenuClear;
var
  F : TControl;
begin
  F:=FindCtrl('form0');
  Protect:=F;
  ClearMenu;
  Protect:=nil;
  AddCtrl(F,'form0',MT_FORM);
  if F is TWinControl then SetDefParent(TWinControl(F))
  else SetDefParent(nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.Activate(const Name : String);
var
  C : TControl;
  F : TCustomForm;
begin
  C:=FindCtrl(Name);
  if C=nil then Exit;

  if C is TCustomForm then
  begin
    SetForegroundWindow(TCustomForm(C).Handle);
    Exit;
  end;
  F:=GetParentForm(C);
  if F=nil then Exit;
  SetForegroundWindow(F.Handle);
  if (C is TWinControl) and TWinControl(C).CanFocus then
    F.ActiveControl:=TWinControl(C);
end;

////////////////////////////////////////////////////////////////////////////////
// TOldParser's GET ($4c0e00).
procedure TMenu16.Get(const Name : String);
var
  C : TControl;
begin
  MenuRes:='N/A';
  C:=FindCtrl(Name);
  if C=nil then Exit;

  if C is TMemo then
    MenuRes:=ReplaceStr(ReplaceStr(TMemo(C).Text,#13#10,'$'),#10,'$')
  else if C is TCustomEdit then
    MenuRes:=TCustomEdit(C).Text
  else if C is TComboBox then
    MenuRes:=IntToStr(C.Tag+1)
  else if C is TListBox then
    MenuRes:=IntToStr(TListBox(C).ItemIndex+1)
  else if C is TRadioButton then
  begin
    if TRadioButton(C).Checked then MenuRes:='-1' else MenuRes:='0';
  end
  else if C is TCheckBox then
    if TCheckBox(C).Checked then MenuRes:='-1' else MenuRes:='0';
end;

////////////////////////////////////////////////////////////////////////////////
// TOldParser's SET ($4c0f90). "$" stays as written, except in a memo.
procedure TMenu16._Set(const Name, Str : String);
var
  C    : TControl;
  Item : TMenu16Item;
begin
  if not Find(Name,Item) then Exit;
  C:=Item.Ctrl;

  if C is TMemo then
    TMemo(C).Text:=ReplaceStr(Str,'$',#13#10)
  else if C is TCustomEdit then
    TCustomEdit(C).Text:=Str
  else if (C is TLabel) or (C is TEuoMenuButton) then
    SetCaption(Item,C,Str)
  else if C is TRadioButton then
    TRadioButton(C).Checked:=StrToIntDef(Str,0)<>0
  else if C is TCheckBox then
    TCheckBox(C).Checked:=StrToIntDef(Str,0)<>0;
end;

////////////////////////////////////////////////////////////////////////////////
// FormCreate ($4af564): hidden, single frame, no maximize, stay on top, own taskbar button.
// The default parent becomes the new form even when the name is taken and the form is left
// unregistered. The window is created at once, as VCL did when the client size was set, so
// Windows' minimum window width applies to small and negative sizes as in 1.6 -- except in a
// host that never ran Application.Initialize (a console test runner), where LCL has not
// registered its window classes yet; the window is then created when first shown.
procedure TMenu16.FormCreate(const Name : String; X,Y,W,H : Integer; const Cap : String);
var
  F : TEuoMenuForm;
begin
  F:=TEuoMenuForm.Create(nil);
  F.BorderStyle:=bsSingle;
  F.BorderIcons:=[biSystemMenu,biMinimize];
  F.ShowHint:=True;
  F.OnClose:=FormClose;
  if AppInitialized in Application.Flags then F.HandleNeeded;
  F.Left:=X;
  F.Top:=Y;
  SetFormClientWidth(F,W+FrameGrowth);
  SetFormClientHeight(F,H+FrameGrowth);
  F.Caption:=Cap;
  Created.Add(F);
  AddCtrl(F,Name,MT_FORM);
  SetDefParent(F);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.PanelCreate(const Name : String; X,Y,W,H : Integer);
var
  NewPanel : TPanel;
begin
  NewPanel:=TPanel.Create(nil);
  NewPanel.Left:=X;
  NewPanel.Top:=Y;
  NewPanel.Width:=W;
  NewPanel.Height:=H;
  NewPanel.Color:=Def.Color;
  NewPanel.BevelOuter:=bvNone;
  NewPanel.ShowHint:=True;
  NewPanel.Parent:=DefBox;
  Created.Add(NewPanel);
  AddCtrl(NewPanel,Name,MT_PANEL);
  SetDefParent(NewPanel);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.TextCreate(const Name : String; X,Y : Integer; const Str : String);
var
  NewLabel : TMenu16Label;
begin
  NewLabel:=TMenu16Label.Create(nil);
  NewLabel.AutoSize:=False;
  NewLabel.Left:=X;
  NewLabel.Top:=Y;
  NewLabel.Font.Assign(Def.Font);
  NewLabel.Color:=Def.Color;
  NewLabel.Transparent:=False;   // VCL's labels are opaque; LCL's are transparent by default
  NewLabel.ShowHint:=True;
  NewLabel.Width:=0;
  if (Def.Alignment>=0) and (Def.Alignment<=2) then
    NewLabel.Alignment:=TAlignment(Def.Alignment);
  NewLabel.Parent:=DefBox;
  Created.Add(NewLabel);
  SetCaption(AddCtrl(NewLabel,Name,MT_TEXT),NewLabel,Str);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ButtonCreate(const Name : String; X,Y,W,H : Integer; const Str : String);
var
  NewButton : TEuoMenuButton;
begin
  NewButton:=TEuoMenuButton.Create(nil);
  NewButton.Left:=X;
  NewButton.Top:=Y;
  NewButton.Width:=W;
  NewButton.Height:=H;
  NewButton.Font.Assign(Def.Font);
  NewButton.Color:=Def.Color;
  NewButton.OnClick:=ButtonClick;
  NewButton.ShowHint:=True;
  NewButton.Parent:=DefBox;
  Created.Add(NewButton);
  SetCaption(AddCtrl(NewButton,Name,MT_BUTTON),NewButton,Str);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.EditCreate(const Name : String; X,Y,W : Integer; const Str : String);
var
  NewEdit : TEdit;
begin
  NewEdit:=TEdit.Create(nil);
  NewEdit.Left:=X;
  NewEdit.Top:=Y;
  NewEdit.Width:=W;
  NewEdit.Text:=Str;
  NewEdit.AutoSize:=False;
  NewEdit.Font.Assign(Def.Font);
  FitEdit(NewEdit);
  NewEdit.Color:=Def.Color;
  NewEdit.ShowHint:=True;
  NewEdit.Parent:=DefBox;
  Created.Add(NewEdit);
  AddCtrl(NewEdit,Name,MT_EDIT);
end;

////////////////////////////////////////////////////////////////////////////////
// Reforged addition, as TMenuObj.MemoCreate, with the 1.6 defaults and parents.
procedure TMenu16.MemoCreate(const Name : String; X,Y,W,H : Integer; const Str : String);
var
  NewMemo : TMemo;
begin
  NewMemo:=TMemo.Create(nil);
  NewMemo.Left:=X;
  NewMemo.Top:=Y;
  NewMemo.Width:=W;
  NewMemo.Height:=H;
  NewMemo.Font.Assign(Def.Font);
  NewMemo.Color:=Def.Color;
  NewMemo.ScrollBars:=ssAutoBoth;
  NewMemo.WordWrap:=False;
  NewMemo.WantTabs:=False;
  NewMemo.Text:=ReplaceStr(Str,'$',#13#10);
  NewMemo.ShowHint:=True;
  NewMemo.Parent:=DefBox;
  Created.Add(NewMemo);
  AddCtrl(NewMemo,Name,MT_MEMO);
end;

////////////////////////////////////////////////////////////////////////////////
// CheckCreate ($4af9c0) / RadioCreate ($4afacc). Text on the right unless the default
// alignment is right. A radio button is checked after it is placed, so checking it unchecks
// the other radio buttons with the same parent.
procedure TMenu16.CheckCreate(const Name : String; X,Y,W,H : Integer; C : Boolean;
  const Str : String; Radio : Boolean);
var
  NewCheck : TCustomCheckBox;
  Kind     : Integer;
begin
  if Radio then
  begin
    NewCheck:=TRadioButton.Create(nil);
    Kind:=MT_RADIO;
  end
  else
  begin
    NewCheck:=TCheckBox.Create(nil);
    Kind:=MT_CHECK;
  end;
  NewCheck.AutoSize:=False;   // see TMenuObj.CheckCreate
  NewCheck.Left:=X;
  NewCheck.Top:=Y;
  NewCheck.Width:=W;
  NewCheck.Height:=H;
  if not Radio then TCheckBox(NewCheck).Checked:=C;
  NewCheck.Font.Assign(Def.Font);
  NewCheck.Color:=Def.Color;
  NewCheck.ShowHint:=True;
  if Def.Alignment=1 then NewCheck.Tag:=0 else NewCheck.Tag:=1;
  ApplyCheckAlign(NewCheck);
  NewCheck.Parent:=DefBox;
  if Radio then TRadioButton(NewCheck).Checked:=C;
  Created.Add(NewCheck);
  SetCaption(AddCtrl(NewCheck,Name,Kind),NewCheck,Str);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ComboCreate(const Name : String; X,Y,W : Integer);
var
  NewCombo : TComboBox;
begin
  NewCombo:=TComboBox.Create(nil);
  NewCombo.Left:=X;
  NewCombo.Top:=Y;
  NewCombo.Width:=W;
  NewCombo.Font.Assign(Def.Font);
  NewCombo.Color:=Def.Color;
  NewCombo.Style:=csDropDownList;
  NewCombo.Tag:=-1;
  NewCombo.OnSelect:=ComboSelect;
  NewCombo.ShowHint:=True;
  NewCombo.Parent:=DefBox;
  Created.Add(NewCombo);
  AddCtrl(NewCombo,Name,MT_COMBO);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ListCreate(const Name : String; X,Y,W,H : Integer);
var
  NewList : TListBox;
begin
  NewList:=TListBox.Create(nil);
  NewList.Left:=X;
  NewList.Top:=Y;
  NewList.Width:=W;
  NewList.Height:=H;
  NewList.Font.Assign(Def.Font);
  NewList.Color:=Def.Color;
  NewList.ShowHint:=True;
  NewList.Parent:=DefBox;
  Created.Add(NewList);
  AddCtrl(NewList,Name,MT_LIST);
end;

////////////////////////////////////////////////////////////////////////////////
// Only the registered control of the name, unlike 1.5, which changes every control so named.
procedure TMenu16.ComboListAdd(const Name, Str : String);
var
  C : TControl;
begin
  C:=FindCtrl(Name);
  if C is TListBox then TListBox(C).Items.Add(Str)
  else if C is TComboBox then TComboBox(C).Items.Add(Str);
end;

procedure TMenu16.ComboListSelect(const Name : String; Ind : Integer);
var
  C : TControl;
begin
  C:=FindCtrl(Name);
  if C is TListBox then
  begin
    // LB_SETCURSEL (what VCL sent) clears the selection for -1 and leaves it as it is for any
    // other index outside the list; LCL raises instead.
    if (Ind-1>=-1) and (Ind-1<TListBox(C).Items.Count) then
      TListBox(C).ItemIndex:=Ind-1;
  end
  else if C is TComboBox then
  begin
    TComboBox(C).ItemIndex:=Ind-1;
    C.Tag:=Ind-1;
  end;
end;

procedure TMenu16.ComboListClear(const Name : String);
var
  C : TControl;
begin
  C:=FindCtrl(Name);
  if C is TListBox then
  begin
    TListBox(C).Items.Clear;
    TListBox(C).ItemIndex:=-1;   // LCL keeps the old index while the list has no window
  end
  else if C is TComboBox then
  begin
    TComboBox(C).Items.Clear;
    C.Tag:=-1;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ImageCreate(const Name : String; X,Y,W,H : Integer);
var
  NewImage : TImage;
begin
  NewImage:=NewMenuImage(W,H);
  NewImage.Left:=X;
  NewImage.Top:=Y;
  NewImage.ShowHint:=True;
  NewImage.Parent:=DefBox;
  Created.Add(NewImage);
  AddCtrl(NewImage,Name,MT_IMAGE);
end;

// VCL's wide pens drew rectangles with square corners and ellipses as LCL's round joins do;
// the shared primitives leave the pen's join as it is, so it is set for each drawing.
procedure DrawRectangle(Img : TImage; X1,Y1,X2,Y2,C : Integer; Fill : Boolean; W : Integer);
begin
  Img.Canvas.Pen.JoinStyle:=pjsMiter;
  MenuImageRectangle(Img,X1,Y1,X2,Y2,C,Fill,W);
end;

procedure DrawEllipse(Img : TImage; X1,Y1,X2,Y2,C : Integer; Fill : Boolean; W : Integer);
begin
  Img.Canvas.Pen.JoinStyle:=pjsRound;
  MenuImageEllipse(Img,X1,Y1,X2,Y2,C,Fill,W);
end;

function TMenu16.FindImage(const Name : String; out Img : TImage) : Boolean;
var
  C : TControl;
begin
  C:=FindCtrl(Name);
  Result:=C is TImage;
  if Result then Img:=TImage(C) else Img:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
// TOldParser's shape emulation ($4c10ac). Types 1, 5 and 6 squeeze the box to a square,
// centred; 1 and 2 are ellipses, everything else a rectangle. The fill covers the whole box
// with a 1-pixel pen of the fill colour; the outline is drawn from (d,d) to (w-2d,h-2d),
// d = half the pen width -- off-centre by half a pen, as in 1.6.
procedure TMenu16.ShapeCreate(const Name : String; X,Y,W,H,ST,LW,LC,FC : Integer;
  LineOn,FillOn : Boolean);
var
  D   : Integer;
  Img : TImage;
begin
  D:=LW div 2;
  if (ST=1) or (ST=5) or (ST=6) then
  begin
    if H<W then
    begin
      X:=X+(W-H) div 2;
      W:=H;
    end;
    if W<H then
    begin
      Y:=Y+(H-W) div 2;
      H:=W;
    end;
  end;

  ImageCreate(Name,X,Y,W,H);
  if not FindImage(Name,Img) then Exit;

  if (ST=1) or (ST=2) then
  begin
    if FillOn then DrawEllipse(Img,0,0,W,H,FC,True,0);
    if LineOn then DrawEllipse(Img,D,D,W-2*D,H-2*D,LC,False,LW);
  end
  else
  begin
    if FillOn then DrawRectangle(Img,0,0,W,H,FC,True,0);
    if LineOn then DrawRectangle(Img,D,D,W-2*D,H-2*D,LC,False,LW);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.FormClose(Sender : TObject; var CloseAction : TCloseAction);
var
  Name : String;
begin
  CloseAction:=caHide;
  if NameOf(TControl(Sender),Name) then FMenuButton:=Name;
end;

procedure TMenu16.ButtonClick(Sender : TObject);
var
  Name : String;
begin
  if NameOf(TControl(Sender),Name) then FMenuButton:=Name;
end;

procedure TMenu16.ComboSelect(Sender : TObject);
begin
  TComboBox(Sender).Tag:=TComboBox(Sender).ItemIndex;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TMenu16.RunWindow;
var
  F       : TEuoMenuForm;
  iBuf    : Integer;
  ConvRes : Boolean;
begin
  F:=Form0;
  if F=nil then Exit;

  if P[2].StrU='SIZE' then
  begin
    if P.Count<5 then Exit;
    if not(P[3].CardValid and P[4].CardValid) then Exit;
    SetFormClientWidth(F,P[3].Int);
    SetFormClientHeight(F,P[4].Int);
  end

  else if P[2].StrU='COLOR' then
  begin
    if P.Count<4 then Exit;
    iBuf:=SToCol(P[3].Str,ConvRes);
    if ConvRes then F.Color:=iBuf;
  end

  else if P[2].StrU='TITLE' then
  begin
    if P.Count<3 then Exit;
    F.Caption:=Rest(3);
  end

  else if P[2].StrU='TRANSPARENT' then
  begin
    if P.Count>3 then
      if P[3].CardValid and (P[3].Int<101) then
        F.SetTransparency(P[3].Int*235 div 100 + 20);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// MENU FONT writes the default object. TRANSPARENT is gone in 1.6 (labels are opaque).
procedure TMenu16.RunFont;
var
  iBuf    : Integer;
  ConvRes : Boolean;
  Style   : TFontStyles;
begin
  if P.Count<3 then Exit;

  if P[2].StrU='NAME' then
  begin
    if P.Count>3 then
    begin
      Def.Font.Name:=Rest(3);
      SetSymbolCharSet(Def.Font);
    end;
  end

  else if P[2].StrU='ALIGN' then
  begin
    if P.Count<4 then Exit;
    if P[3].StrU='LEFT' then Def.Alignment:=Ord(taLeftJustify);
    if P[3].StrU='RIGHT' then Def.Alignment:=Ord(taRightJustify);
    if P[3].StrU='CENTER' then Def.Alignment:=Ord(taCenter);
  end

  else if P[2].StrU='SIZE' then
  begin
    if P.Count>3 then
      if P[3].CardValid then
        Def.Font.Size:=P[3].Int;
  end

  else if P[2].StrU='COLOR' then
  begin
    if P.Count<4 then Exit;
    iBuf:=SToCol(P[3].Str,ConvRes);
    if ConvRes then Def.Font.Color:=iBuf;
  end

  else if P[2].StrU='BGCOLOR' then
  begin
    if P.Count<4 then Exit;
    iBuf:=SToCol(P[3].Str,ConvRes);
    if ConvRes then Def.Color:=iBuf;
  end

  else if P[2].StrU='STYLE' then
  begin
    Def.Font.Style:=[];
    if P.Count<4 then Exit;
    Style:=[];
    if Pos('B',P[3].StrU)>0 then Include(Style,fsBold);
    if Pos('I',P[3].StrU)>0 then Include(Style,fsItalic);
    if Pos('U',P[3].StrU)>0 then Include(Style,fsUnderline);
    if Pos('S',P[3].StrU)>0 then Include(Style,fsStrikeOut);
    Def.Font.Style:=Style;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// MENU IMAGE, after CREATE: the checks run in this order whatever the sub-command, and the
// first one that fails ends the line.
procedure TMenu16.RunImage;
var
  C       : TControl;
  Img     : TImage;
  iBuf    : Integer;
  W       : Integer;
  ConvRes : Boolean;
begin
  if P.Count<6 then Exit;
  if not(P[4].IntValid and P[5].IntValid) then Exit;
  C:=FindCtrl(P[3].Str);
  if C=nil then Exit;
  if C is TImage then Img:=TImage(C) else Img:=nil;

  if P[2].StrU='POS' then
  begin
    C.Left:=P[4].Int;
    C.Top:=P[5].Int;
  end;

  if P.Count<7 then Exit;

  if P[2].StrU='PIX' then
  begin
    iBuf:=SToCol(P[6].Str,ConvRes);
    if ConvRes and (Img<>nil) then MenuImagePix(Img,P[4].Int,P[5].Int,iBuf);
  end;

  if P[2].StrU='FLOODFILL' then
  begin
    iBuf:=SToCol(P[6].Str,ConvRes);
    if ConvRes and (Img<>nil) then MenuImageFloodFill(Img,P[4].Int,P[5].Int,iBuf);
  end;

  if P[2].StrU='FILE' then
    if Img<>nil then MenuImageFile(Img,P[4].Int,P[5].Int,P[6].Str);

  if P.Count<8 then Exit;
  if not(P[6].CardValid and P[7].CardValid) then Exit;

  if P[2].StrU='POS' then
  begin
    C.Width:=P[6].Int;
    C.Height:=P[7].Int;
    if Img<>nil then Img.Stretch:=True;
  end;

  if P.Count<9 then Exit;
  iBuf:=SToCol(P[8].Str,ConvRes);
  if not ConvRes then Exit;
  W:=1;

  if P[2].StrU='LINE' then
  begin
    if (P.Count>9) and P[9].CardValid then W:=P[9].Int;
    if Img<>nil then MenuImageLine(Img,P[4].Int,P[5].Int,P[6].Int,P[7].Int,iBuf,W);
  end;

  if P.Count<10 then Exit;
  if (P.Count>10) and P[10].CardValid then W:=P[10].Int;

  if P[2].StrU='ELLIPSE' then
    if Img<>nil then
      DrawEllipse(Img,P[4].Int,P[5].Int,P[6].Int,P[7].Int,iBuf,P[9].Int<>0,W);

  if P[2].StrU='RECTANGLE' then
    if Img<>nil then
      DrawRectangle(Img,P[4].Int,P[5].Int,P[6].Int,P[7].Int,iBuf,P[9].Int<>0,W);
end;

////////////////////////////////////////////////////////////////////////////////
// TOldParser.MenuProc ($4c120c). Runs on the main thread (TEuoInterpreter.Menu16ProcSync).
procedure TMenu16.Run(Pars : TParList);
var
  Item    : TMenu16Item;
  F       : TEuoMenuForm;
  Sub     : String;
  IVal    : Integer;
  BVal    : Boolean;
  iBuf    : Integer;
  iBuf2   : Integer;
  ConvRes : Boolean;
begin
  P:=Pars;
  if P.Count<2 then Exit;
  Sub:=P[1].StrU;

  if Sub='GETPROP' then
  begin
    if not Find(P[2].Str,Item) then Exit;
    ShowRes(GetProp(Item,Item.Ctrl,Item.Kind,P[3].Str,IVal,BVal),IVal,BVal);
  end

  else if Sub='SETPROP' then
  begin
    if not Find(P[2].Str,Item) then Exit;
    SetProp(Item,Item.Ctrl,Item.Kind,P[3].Str,Rest(4),P[4].Int);
  end

  else if Sub='PUSHDEF' then PushDef

  else if Sub='POPDEF' then PopDef

  else if Sub='GETDEF' then
    ShowRes(GetProp(nil,Def,MT_DEFAULT,P[2].Str,IVal,BVal),IVal,BVal)

  else if Sub='SETDEF' then
    SetProp(nil,Def,MT_DEFAULT,P[2].Str,Rest(3),P[3].Int)

  else if Sub='SHOW' then
  begin
    F:=Form0;
    if F=nil then Exit;
    if (P.Count>=4) and P[2].IntValid and P[3].IntValid then
    begin
      F.Left:=P[2].Int;
      F.Top:=P[3].Int;
    end;
    F.Visible:=True;
    SetWindowPos(F.Handle,HWND_TOPMOST,0,0,0,0,SWP_NOMOVE or SWP_NOSIZE);
  end

  else if Sub='HIDE' then
  begin
    F:=Form0;
    if F=nil then Exit;
    F.Visible:=False;
  end

  else if Sub='CLEAR' then MenuClear

  else if Sub='DELETE' then
  begin
    if P.Count>2 then RemoveCtrl(FindCtrl(P[2].Str));
  end

  else if Sub='ACTIVATE' then
  begin
    if P.Count>2 then Activate(P[2].Str);
  end

  else if Sub='GET' then
  begin
    if P.Count>2 then Get(P[2].Str);
  end

  else if Sub='GETNUM' then
  begin
    if P.Count<3 then Exit;
    Get(P[2].Str);
    if not IsNumber(MenuRes) then
      if P.Count>3 then MenuRes:=P[3].Str;
  end

  else if Sub='SET' then
  begin
    if P.Count>2 then _Set(P[2].Str,Rest(3));
  end

  else if Sub='WINDOW' then RunWindow

  else if Sub='FONT' then RunFont

  else if Sub='FORM' then
  begin
    if P.Count<7 then Exit;
    if not(P[3].IntValid and P[4].IntValid and P[5].IntValid and P[6].IntValid) then Exit;
    FormCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,P[6].Int,Rest(7));
  end

  else if Sub='PANEL' then
  begin
    if P.Count<7 then Exit;
    if not(P[3].IntValid and P[4].IntValid and P[5].IntValid and P[6].IntValid) then Exit;
    PanelCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,P[6].Int);
  end

  else if Sub='TEXT' then
  begin
    if P.Count<5 then Exit;
    if not(P[3].IntValid and P[4].IntValid) then Exit;
    TextCreate(P[2].Str,P[3].Int,P[4].Int,ReplaceStr(Rest(5),'$',#13#10));
  end

  else if Sub='BUTTON' then
  begin
    if P.Count<7 then Exit;
    if not(P[3].IntValid and P[4].IntValid) then Exit;
    if not(P[5].CardValid and P[6].CardValid) then Exit;
    ButtonCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,P[6].Int,Rest(7));
  end

  else if Sub='EDIT' then
  begin
    if P.Count<6 then Exit;
    if not(P[3].IntValid and P[4].IntValid) then Exit;
    if not P[5].CardValid then Exit;
    EditCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,Rest(6));
  end

  else if Sub='MEMO' then
  begin
    if P.Count<7 then Exit;
    if not(P[3].IntValid and P[4].IntValid) then Exit;
    if not(P[5].CardValid and P[6].CardValid) then Exit;
    MemoCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,P[6].Int,Rest(7));
  end

  else if (Sub='CHECK') or (Sub='RADIO') then
  begin
    if P.Count<8 then Exit;
    if not(P[3].IntValid and P[4].IntValid) then Exit;
    if not(P[5].CardValid and P[6].CardValid) then Exit;
    if not P[7].IntValid then Exit;
    CheckCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,P[6].Int,P[7].Int<>0,Rest(8),Sub='RADIO');
  end

  else if (Sub='LIST') or (Sub='COMBO') then
  begin
    if P[2].StrU='CREATE' then
    begin
      if Sub='LIST' then
      begin
        if P.Count<8 then Exit;
        if not(P[4].IntValid and P[5].IntValid) then Exit;
        if not(P[6].CardValid and P[7].CardValid) then Exit;
        ListCreate(P[3].Str,P[4].Int,P[5].Int,P[6].Int,P[7].Int);
      end
      else
      begin
        if P.Count<7 then Exit;
        if not(P[4].IntValid and P[5].IntValid) then Exit;
        if not P[6].CardValid then Exit;
        ComboCreate(P[3].Str,P[4].Int,P[5].Int,P[6].Int);
      end;
    end;

    if P.Count<4 then Exit;
    if P[2].StrU='ADD' then ComboListAdd(P[3].Str,Rest(4));
    if P[2].StrU='CLEAR' then ComboListClear(P[3].Str);
    if P[2].StrU='SELECT' then
      if (P.Count>4) and P[4].IntValid then ComboListSelect(P[3].Str,P[4].Int);
  end

  else if Sub='SHAPE' then
  begin
    if P.Count<13 then Exit;
    if not(P[3].IntValid and P[4].IntValid) then Exit;
    if not(P[5].CardValid and P[6].CardValid and P[7].CardValid) then Exit;
    if not(P[8].CardValid and P[9].CardValid and P[11].CardValid) then Exit;
    iBuf:=SToCol(P[10].Str,ConvRes);
    if not ConvRes then Exit;
    iBuf2:=SToCol(P[12].Str,ConvRes);
    if not ConvRes then Exit;
    ShapeCreate(P[2].Str,P[3].Int,P[4].Int,P[5].Int,P[6].Int,P[7].Int,P[9].Int,
      iBuf,iBuf2,P[8].Int<>1,P[11].Int=7);
  end

  else if Sub='IMAGE' then
  begin
    if P[2].StrU='CREATE' then
    begin
      if P.Count<8 then Exit;
      if not(P[4].IntValid and P[5].IntValid) then Exit;
      if not(P[6].CardValid and P[7].CardValid) then Exit;
      ImageCreate(P[3].Str,P[4].Int,P[5].Int,P[6].Int,P[7].Int);
    end;
    RunImage;
  end;
end;

end.
