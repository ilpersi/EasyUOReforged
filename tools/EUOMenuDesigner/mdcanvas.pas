unit mdcanvas;

{
  Port addition: the MENU Designer's canvas for one form (docs/menu-designer.md, sections 7
  and 9.2). It hosts the form's Surface, as TMdEngine builds it, under a title bar it draws.

  Every window on the hosted surface answers WM_NCHITTEST with HTTRANSPARENT (a window
  procedure put in front of LCL's), so Windows hands the mouse to the canvas itself, which hit-
  tests the components by their bounds: buttons never click, edits never take the focus,
  combos never drop down. Selection handles, outlines, snap guides and the marquee are small
  windows above the surface, so they draw over native controls too, and are hit-test
  transparent as well. An outline with its handles is one window (TMdFrame) whose region is
  the outline and the handle squares: a drag moves one window per selected component, where
  twelve small ones cost the mouse its smoothness.

  Dragging moves or sizes the real controls; on mouse-up the change goes into the model through
  OnBeforeChange / OnAfterChange, and the form is built again.
}

{$mode delphi}{$H+}

interface
uses
  Windows, Messages, Classes, SysUtils, Types, Math, Graphics, Controls, ExtCtrls, Forms,
  LCLType, LMessages, EuoMenuCommon, mdtypes, mdmodel, mdengine, mdgeometry;

type
  TMdRects = array of TRect;

  TMdMark = class(TCustomControl)
  protected
    procedure Paint; override;
  end;

  // An outline and its handles as one window, shaped by a region to draw only those.
  TMdFrame = class(TMdMark)
  private
    Shape : String;   // the shape the region was last made for
  protected
    procedure CreateWnd; override;
  public
    procedure Place(const Box : TRect; HasBox : Boolean; const Handles : array of TRect;
                AColor : TColor);
  end;

  TMdHandle = (mhTL, mhT, mhTR, mhR, mhBR, mhB, mhBL, mhL);
  TMdDragMode = (dmNone, dmMove, dmResize, dmMarquee);

  TMdFormView = class(TCustomControl)
  private
    FDoc        : TMdDocument;
    FEngine     : TMdEngine;
    FForm       : TMdComponent;
    FSel        : TList;
    FSurface    : TWinControl;
    Marks       : TList;      // guides and the marquee
    MarkUsed    : Integer;
    Frames      : TList;      // outlines of panels and of the selection, with handles
    FrameUsed   : Integer;
    TitleSel    : Boolean;      // the title bar shows the form selected
    Mode        : TMdDragMode;
    Down        : TPoint;
    Edges       : TMdEdges;
    Starts      : array of TRect;
    Dragged     : array of TMdComponent;
    Moved       : Boolean;
    function    Mark(R : TRect; Color : TColor) : TMdMark;
    procedure   Outline(R : TRect; Color : TColor; Width : Integer);
    procedure   HideUnusedMarks;
    function    Frame(const Box : TRect; HasBox : Boolean; const Handles : array of TRect;
                  Color : TColor) : TMdFrame;
    function    ParentRect(C : TMdComponent) : TRect;
    function    Offset(C : TMdComponent) : TPoint;
    function    HitIn(Container : TMdComponent; P : TPoint) : TMdComponent;
    function    HandleRect(const R : TRect; H : TMdHandle) : TRect;
    function    HandleAt(P : TPoint; out H : TMdHandle) : Boolean;
    function    Resizable(C : TMdComponent; H : TMdHandle) : Boolean;
    function    Siblings(C : TMdComponent) : TMdRects;
    procedure   PaintGrid(Sender : TObject);
    procedure   SetLive(C : TMdComponent; const R : TRect);
    procedure   Commit;
    function    ContainerAt(P : TPoint; Skip : TMdComponent) : TMdComponent;
    procedure   WMGetDlgCode(var Message : TLMGetDlgCode); message LM_GETDLGCODE;
  protected
    procedure   Paint; override;
    procedure   MouseDown(Button : TMouseButton; Shift : TShiftState; X, Y : Integer); override;
    procedure   MouseMove(Shift : TShiftState; X, Y : Integer); override;
    procedure   MouseUp(Button : TMouseButton; Shift : TShiftState; X, Y : Integer); override;
    procedure   KeyDown(var Key : Word; Shift : TShiftState); override;
  public
    Snap           : TMdSnap;
    ShowGrid       : Boolean;
    Placing        : Boolean;     // the next click places a PlaceType
    PlaceType      : TMdType;
    OnBeforeChange : TNotifyEvent;
    OnAfterChange  : TMdChangeEvent;
    OnSelect       : TNotifyEvent;
    OnPlaced       : TNotifyEvent;
    constructor Create(AOwner : TComponent; ADoc : TMdDocument; AEngine : TMdEngine;
                  AForm : TMdComponent; ASel : TList); reintroduce;
    destructor  Destroy; override;
    procedure   Host;
    procedure   UpdateMarks;
    function    ComponentAt(P : TPoint) : TMdComponent;
    function    ViewRect(C : TMdComponent) : TRect;
    procedure   Nudge(DX, DY : Integer; Resize : Boolean);
    property    FormComponent : TMdComponent read FForm;
  end;

const
  TitleH = 24;

procedure MakeHitTransparent(W : TWinControl);

implementation

function Sub(const A, B : TPoint) : TPoint;
begin
  Result:=Point(A.X-B.X,A.Y-B.Y);
end;

function Add(const A, B : TPoint) : TPoint;
begin
  Result:=Point(A.X+B.X,A.Y+B.Y);
end;

const
  PropName  = 'MdHitProc';
  HandleSz  = 6;
  SelColor  = clHighlight;
  GuideCol  = clFuchsia;
  PanelCol  = clGray;

////////////////////////////////////////////////////////////////////////////////
// A window procedure in front of LCL's: transparent to hit-testing, the rest goes on.
function HitProc(Wnd : HWND; Msg : UINT; wP : WPARAM; lP : LPARAM) : LRESULT; stdcall;
var
  Old : Pointer;
begin
  Old:=Pointer(GetPropW(Wnd,PropName));
  if Msg=WM_NCHITTEST then Exit(HTTRANSPARENT);
  if Msg=WM_NCDESTROY then
  begin
    SetWindowLongPtrW(Wnd,GWLP_WNDPROC,LONG_PTR(Old));
    RemovePropW(Wnd,PropName);
  end;
  Result:=CallWindowProcW(Old,Wnd,Msg,wP,lP);
end;

procedure MakeHitTransparent(W : TWinControl);
var
  Cnt : Integer;
begin
  W.HandleNeeded;
  if GetPropW(W.Handle,PropName)=0 then
  begin
    SetPropW(W.Handle,PropName,HANDLE(GetWindowLongPtrW(W.Handle,GWLP_WNDPROC)));
    SetWindowLongPtrW(W.Handle,GWLP_WNDPROC,LONG_PTR(@HitProc));
  end;
  W.TabStop:=False;
  for Cnt:=0 to W.ControlCount-1 do
    if W.Controls[Cnt] is TWinControl then MakeHitTransparent(TWinControl(W.Controls[Cnt]));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdMark.Paint;
begin
  Canvas.Brush.Color:=Color;
  Canvas.FillRect(ClientRect);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdFrame.CreateWnd;
begin
  inherited CreateWnd;
  Shape:='';   // a new window has no region yet
end;

// Box (a one-pixel outline) and Handles in the view's coordinates. The window covers them all;
// its region is made again only when their shape changes, so a move is one window move.
procedure TMdFrame.Place(const Box : TRect; HasBox : Boolean; const Handles : array of TRect;
  AColor : TColor);
var
  B    : TRect;
  Cnt  : Integer;
  Key  : String;
  Rgn  : HRGN;
  Part : HRGN;
  Hole : HRGN;
  R    : TRect;
begin
  if HasBox then B:=Box else B:=Handles[0];
  for Cnt:=Low(Handles) to High(Handles) do
    UnionRect(B,B,Handles[Cnt]);
  Key:=Format('%d,%d',[B.Right-B.Left,B.Bottom-B.Top]);
  if HasBox then
    Key:=Key+Format('|%d,%d,%d,%d',[Box.Left-B.Left,Box.Top-B.Top,Box.Right-B.Left,Box.Bottom-B.Top]);
  for Cnt:=Low(Handles) to High(Handles) do
    Key:=Key+Format('|%d,%d',[Handles[Cnt].Left-B.Left,Handles[Cnt].Top-B.Top]);

  if not EqualRect(BoundsRect,B) then BoundsRect:=B;
  if Key<>Shape then
  begin
    HandleNeeded;
    Rgn:=CreateRectRgn(0,0,0,0);
    if HasBox then
    begin
      R:=Box;
      OffsetRect(R,-B.Left,-B.Top);
      Part:=CreateRectRgnIndirect(R);
      InflateRect(R,-1,-1);
      Hole:=CreateRectRgnIndirect(R);
      CombineRgn(Part,Part,Hole,RGN_DIFF);
      CombineRgn(Rgn,Rgn,Part,RGN_OR);
      DeleteObject(Hole);
      DeleteObject(Part);
    end;
    for Cnt:=Low(Handles) to High(Handles) do
    begin
      R:=Handles[Cnt];
      OffsetRect(R,-B.Left,-B.Top);
      Part:=CreateRectRgnIndirect(R);
      CombineRgn(Rgn,Rgn,Part,RGN_OR);
      DeleteObject(Part);
    end;
    SetWindowRgn(Handle,Rgn,True);   // the window owns the region from here
    Shape:=Key;
  end;
  if Color<>AColor then
  begin
    Color:=AColor;
    Invalidate;
  end;
  if not Visible then Visible:=True;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TMdFormView.Create(AOwner : TComponent; ADoc : TMdDocument; AEngine : TMdEngine;
  AForm : TMdComponent; ASel : TList);
begin
  inherited Create(AOwner);
  FDoc:=ADoc;
  FEngine:=AEngine;
  FForm:=AForm;
  FSel:=ASel;
  Marks:=TList.Create;
  Frames:=TList.Create;
  Snap:=DefaultSnap;
  ShowGrid:=True;
  TabStop:=True;
  Color:=clBtnFace;
end;

destructor TMdFormView.Destroy;
begin
  Marks.Free;   // the marks and frames themselves are owned by the view
  Frames.Free;
  inherited Destroy;
end;

// After the engine built the form: its Surface into this view, under the title bar.
procedure TMdFormView.Host;
var
  F : TEuoMenuForm;
  Cnt : Integer;
begin
  F:=FEngine.FormWindow(FForm);
  if F=nil then Exit;
  FSurface:=F.Surface;
  SetBounds(Left,Top,F.ClientWidth,F.ClientHeight+TitleH);
  FSurface.Align:=alNone;
  FSurface.Parent:=Self;
  FSurface.SetBounds(0,TitleH,F.ClientWidth,F.ClientHeight);
  TPanel(FSurface).ParentColor:=False;
  TPanel(FSurface).Color:=F.Color;
  TPanel(FSurface).OnPaint:=PaintGrid;
  MakeHitTransparent(FSurface);
  for Cnt:=0 to Frames.Count-1 do
    TMdFrame(Frames[Cnt]).BringToFront;
  for Cnt:=0 to Marks.Count-1 do
    TMdMark(Marks[Cnt]).BringToFront;
  Invalidate;
  FSurface.Invalidate;
  UpdateMarks;
end;

procedure TMdFormView.PaintGrid(Sender : TObject);
var
  X, Y : Integer;
  Cvs  : TCanvas;
begin
  if not ShowGrid or (Snap.Grid<4) then Exit;
  Cvs:=TPanel(Sender).Canvas;
  Y:=0;
  while Y<TPanel(Sender).Height do
  begin
    X:=0;
    while X<TPanel(Sender).Width do
    begin
      Cvs.Pixels[X,Y]:=clGray;
      Inc(X,Snap.Grid);
    end;
    Inc(Y,Snap.Grid);
  end;
end;

procedure TMdFormView.Paint;
var
  R  : TRect;
  TS : TTextStyle;
begin
  R:=Rect(0,0,Width,TitleH);
  if FSel.IndexOf(FForm)>=0 then Canvas.Brush.Color:=clActiveCaption
  else Canvas.Brush.Color:=clInactiveCaption;
  Canvas.FillRect(R);
  Canvas.Font.Assign(Font);
  Canvas.Font.Color:=clCaptionText;
  FillChar(TS,SizeOf(TS),0);
  TS.Layout:=tlCenter;
  TS.SingleLine:=True;
  TS.Clipping:=True;
  Canvas.Brush.Style:=bsClear;
  Canvas.TextRect(Rect(8,0,Width-30,TitleH),8,0,FForm.Text+'   ('+FForm.Name+')',TS);
  Canvas.TextRect(Rect(Width-22,0,Width,TitleH),Width-18,0,'×',TS);
  Canvas.Brush.Style:=bsSolid;
end;

////////////////////////////////////////////////////////////////////////////////
// Where a component is: its parent's client origin in the view, and its rectangle there.
function TMdFormView.Offset(C : TMdComponent) : TPoint;
var
  P    : TMdComponent;
  Ctrl : TControl;
begin
  Result:=Point(0,TitleH);
  P:=C.Parent;
  while (P<>nil) and not P.IsForm do
  begin
    Ctrl:=FEngine.Control(P);
    if Ctrl<>nil then Result:=Add(Result,Point(Ctrl.Left,Ctrl.Top));
    P:=P.Parent;
  end;
end;

function TMdFormView.ParentRect(C : TMdComponent) : TRect;
var
  Ctrl : TControl;
begin
  if C.IsForm then Exit(Rect(0,0,C.Width,C.Height));
  Ctrl:=FEngine.Control(C);
  if Ctrl<>nil then Result:=Ctrl.BoundsRect
  else Result:=Bounds(C.Left,C.Top,C.Width,C.Height);
end;

function TMdFormView.ViewRect(C : TMdComponent) : TRect;
begin
  Result:=ParentRect(C);
  if C.IsForm then OffsetRect(Result,0,TitleH)
  else OffsetRect(Result,Offset(C).X,Offset(C).Y);
end;

function TMdFormView.HitIn(Container : TMdComponent; P : TPoint) : TMdComponent;
var
  Cnt : Integer;
  C   : TMdComponent;
  R   : TRect;
  D   : TMdComponent;
begin
  for Cnt:=Container.ChildCount-1 downto 0 do
  begin
    C:=Container.Child(Cnt);
    R:=ParentRect(C);
    if not PtInRect(R,P) then Continue;
    if C.IsContainer then
    begin
      D:=HitIn(C,Sub(P,R.TopLeft));
      if D<>nil then Exit(D);
    end;
    Exit(C);
  end;
  Result:=nil;
end;

// The component under a view point: the deepest one, else the form (nil on the title bar).
function TMdFormView.ComponentAt(P : TPoint) : TMdComponent;
begin
  if P.Y<TitleH then Exit(nil);
  Result:=HitIn(FForm,Sub(P,Point(0,TitleH)));
  if Result=nil then Result:=FForm;
end;

// The form or panel a point drops into, leaving out Skip and what is inside it.
function TMdFormView.ContainerAt(P : TPoint; Skip : TMdComponent) : TMdComponent;

  function Find(Container : TMdComponent; Q : TPoint) : TMdComponent;
  var
    Cnt : Integer;
    C   : TMdComponent;
    R   : TRect;
  begin
    for Cnt:=Container.ChildCount-1 downto 0 do
    begin
      C:=Container.Child(Cnt);
      if (C=Skip) or not C.IsContainer then Continue;
      R:=ParentRect(C);
      if PtInRect(R,Q) then Exit(Find(C,Sub(Q,R.TopLeft)));
    end;
    Result:=Container;
  end;

begin
  Result:=Find(FForm,Sub(P,Point(0,TitleH)));
end;

////////////////////////////////////////////////////////////////////////////////
// The next mark, where R says. A drag calls this for every mark on every mouse move, so a mark
// is only touched where it changes: moving, showing or recolouring a window repaints what is
// around it, and doing that for every mark each time made a drag lag behind the mouse.
function TMdFormView.Mark(R : TRect; Color : TColor) : TMdMark;
begin
  if MarkUsed<Marks.Count then Result:=TMdMark(Marks[MarkUsed])
  else
  begin
    Result:=TMdMark.Create(Self);
    Result.Parent:=Self;
    MakeHitTransparent(Result);
    Result.BringToFront;   // over the surface; Host puts them back over a new one
    Marks.Add(Result);
  end;
  Inc(MarkUsed);
  if Result.Color<>Color then
  begin
    Result.Color:=Color;
    Result.Invalidate;
  end;
  if not EqualRect(Result.BoundsRect,R) then Result.BoundsRect:=R;
  if not Result.Visible then Result.Visible:=True;
end;

procedure TMdFormView.Outline(R : TRect; Color : TColor; Width : Integer);
begin
  Mark(Rect(R.Left,R.Top,R.Right,R.Top+Width),Color);
  Mark(Rect(R.Left,R.Bottom-Width,R.Right,R.Bottom),Color);
  Mark(Rect(R.Left,R.Top,R.Left+Width,R.Bottom),Color);
  Mark(Rect(R.Right-Width,R.Top,R.Right,R.Bottom),Color);
end;

function TMdFormView.Frame(const Box : TRect; HasBox : Boolean; const Handles : array of TRect;
  Color : TColor) : TMdFrame;
begin
  if FrameUsed<Frames.Count then Result:=TMdFrame(Frames[FrameUsed])
  else
  begin
    Result:=TMdFrame.Create(Self);
    Result.Parent:=Self;
    MakeHitTransparent(Result);
    Result.BringToFront;
    Frames.Add(Result);
  end;
  Inc(FrameUsed);
  Result.Place(Box,HasBox,Handles,Color);
end;

procedure TMdFormView.HideUnusedMarks;
var
  Cnt : Integer;
begin
  for Cnt:=MarkUsed to Marks.Count-1 do
    if TMdMark(Marks[Cnt]).Visible then TMdMark(Marks[Cnt]).Visible:=False;
end;

function TMdFormView.HandleRect(const R : TRect; H : TMdHandle) : TRect;
var
  X, Y : Integer;
begin
  case H of
    mhTL, mhL, mhBL: X:=R.Left;
    mhT, mhB:        X:=(R.Left+R.Right) div 2;
  else               X:=R.Right;
  end;
  case H of
    mhTL, mhT, mhTR: Y:=R.Top;
    mhL, mhR:        Y:=(R.Top+R.Bottom) div 2;
  else               Y:=R.Bottom;
  end;
  Result:=Rect(X-HandleSz div 2,Y-HandleSz div 2,X+HandleSz div 2,Y+HandleSz div 2);
end;

// Which edges of a component the user can drag. A form only grows from its right and bottom.
function TMdFormView.Resizable(C : TMdComponent; H : TMdHandle) : Boolean;
var
  R : TMdTypeRow;
  W : Boolean;
  V : Boolean;
begin
  R:=C.Row;
  W:=R.W<>szFit;
  V:=R.H<>szFit;
  if C.IsForm then
    Result:=H in [mhR,mhB,mhBR]
  else
    case H of
      mhL, mhR:   Result:=W;
      mhT, mhB:   Result:=V;
    else          Result:=W and V;
    end;
  if (C.TypeId=mdtShape) and (C.ShapeStyle in [1,5,6]) then Result:=H in [mhTL,mhTR,mhBL,mhBR];
end;

procedure TMdFormView.UpdateMarks;
var
  Cnt  : Integer;
  L    : TList;
  C    : TMdComponent;
  R    : TRect;
  H    : TMdHandle;
  Hand : TMdRects;
begin
  FrameUsed:=0;
  if FSurface<>nil then
  begin
    // panels: a faint outline, since a panel is often the colour of its form
    L:=TList.Create;
    try
      FDoc.AllComponents(L);
      for Cnt:=0 to L.Count-1 do
      begin
        C:=TMdComponent(L[Cnt]);
        if (C.TypeId=mdtPanel) and (C.FormOf=FForm) then Frame(ViewRect(C),True,[],PanelCol);
      end;
    finally
      L.Free;
    end;
    for Cnt:=0 to FSel.Count-1 do
    begin
      C:=TMdComponent(FSel[Cnt]);
      if C.FormOf<>FForm then Continue;
      R:=ViewRect(C);
      Hand:=nil;
      if FSel.Count=1 then
        for H:=Low(TMdHandle) to High(TMdHandle) do
          if Resizable(C,H) then Hand:=Hand+[HandleRect(R,H)];
      if not C.IsForm then
        Frame(Rect(R.Left-1,R.Top-1,R.Right+1,R.Bottom+1),True,Hand,SelColor)
      else if Length(Hand)>0 then Frame(R,False,Hand,SelColor);
    end;
  end;
  for Cnt:=FrameUsed to Frames.Count-1 do
    if TMdFrame(Frames[Cnt]).Visible then TMdFrame(Frames[Cnt]).Visible:=False;
  // the title bar's colour says whether the form is selected
  if (FSel.IndexOf(FForm)>=0)<>TitleSel then
  begin
    TitleSel:=not TitleSel;
    InvalidateRect(Handle,Rect(0,0,Width,TitleH),False);
  end;
end;

function TMdFormView.HandleAt(P : TPoint; out H : TMdHandle) : Boolean;
var
  C  : TMdComponent;
  R  : TRect;
  HR : TRect;
  K  : TMdHandle;
begin
  Result:=False;
  H:=mhTL;
  if FSel.Count<>1 then Exit;
  C:=TMdComponent(FSel[0]);
  if C.FormOf<>FForm then Exit;
  R:=ViewRect(C);
  for K:=Low(TMdHandle) to High(TMdHandle) do
    if Resizable(C,K) then
    begin
      HR:=HandleRect(R,K);
      if PtInRect(Rect(HR.Left-2,HR.Top-2,HR.Right+2,HR.Bottom+2),P) then
      begin
        H:=K;
        Exit(True);
      end;
    end;
end;

function TMdFormView.Siblings(C : TMdComponent) : TMdRects;
var
  Cnt : Integer;
  S   : TMdComponent;
begin
  Result:=nil;
  if C.Parent=nil then Exit;
  for Cnt:=0 to C.Parent.ChildCount-1 do
  begin
    S:=C.Parent.Child(Cnt);
    if FSel.IndexOf(S)>=0 then Continue;
    SetLength(Result,Length(Result)+1);
    Result[High(Result)]:=ParentRect(S);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdFormView.SetLive(C : TMdComponent; const R : TRect);
var
  Ctrl : TControl;
  F    : TEuoMenuForm;
begin
  if C.IsForm then
  begin
    F:=FEngine.FormWindow(C);
    if F=nil then Exit;
    FSurface.SetBounds(0,TitleH,R.Right-R.Left,R.Bottom-R.Top);
    SetBounds(Left,Top,R.Right-R.Left,R.Bottom-R.Top+TitleH);
    Exit;
  end;
  Ctrl:=FEngine.Control(C);
  if Ctrl<>nil then Ctrl.BoundsRect:=R;
end;

procedure TMdFormView.MouseDown(Button : TMouseButton; Shift : TShiftState; X, Y : Integer);
var
  P   : TPoint;
  C   : TMdComponent;
  H   : TMdHandle;
  Cnt : Integer;
  Box : TMdComponent;
  New : TMdComponent;
  Pos : TPoint;
begin
  inherited MouseDown(Button,Shift,X,Y);
  if CanFocus then SetFocus;
  if Button<>mbLeft then Exit;
  P:=Point(X,Y);
  Down:=P;
  Moved:=False;
  Mode:=dmNone;

  if Placing then
  begin
    Placing:=False;
    Box:=ContainerAt(P,nil);
    if Box.IsForm then Pos:=Sub(P,Point(0,TitleH))
    else Pos:=Sub(P,ViewRect(Box).TopLeft);
    if Snap.ToGrid and (Snap.Grid>1) then
      Pos:=Point(Round(Pos.X/Snap.Grid)*Snap.Grid,Round(Pos.Y/Snap.Grid)*Snap.Grid);
    if Assigned(OnBeforeChange) then OnBeforeChange(Self);
    New:=FDoc.Add(PlaceType,Box,Pos.X,Pos.Y);
    FSel.Clear;
    FSel.Add(New);
    if Assigned(OnAfterChange) then OnAfterChange(FForm);
    if Assigned(OnPlaced) then OnPlaced(Self);
    Exit;
  end;

  if HandleAt(P,H) then
  begin
    Mode:=dmResize;
    case H of
      mhTL: Edges:=[egLeft,egTop];
      mhT:  Edges:=[egTop];
      mhTR: Edges:=[egRight,egTop];
      mhR:  Edges:=[egRight];
      mhBR: Edges:=[egRight,egBottom];
      mhB:  Edges:=[egBottom];
      mhBL: Edges:=[egLeft,egBottom];
      mhL:  Edges:=[egLeft];
    end;
  end
  else
  begin
    C:=ComponentAt(P);
    if C=nil then Exit;
    if ssShift in Shift then
    begin
      if FSel.IndexOf(C)>=0 then FSel.Remove(C) else FSel.Add(C);
    end
    else if FSel.IndexOf(C)<0 then
    begin
      FSel.Clear;
      FSel.Add(C);
    end;
    if Assigned(OnSelect) then OnSelect(Self);
    if C.IsForm then Mode:=dmMarquee
    else
    begin
      Mode:=dmMove;
      Edges:=[egLeft,egTop,egRight,egBottom];
    end;
  end;

  // what is dragged: the selection in this form, forms and their children aside
  SetLength(Dragged,0);
  SetLength(Starts,0);
  if Mode in [dmMove,dmResize] then
    for Cnt:=0 to FSel.Count-1 do
    begin
      C:=TMdComponent(FSel[Cnt]);
      if (C.FormOf<>FForm) or (C.IsForm and (Mode=dmMove)) then Continue;
      SetLength(Dragged,Length(Dragged)+1);
      Dragged[High(Dragged)]:=C;
      SetLength(Starts,Length(Starts)+1);
      Starts[High(Starts)]:=ParentRect(C);
    end;
  if (Mode in [dmMove,dmResize]) and (Length(Dragged)=0) then Mode:=dmNone;
  MouseCapture:=True;
  UpdateMarks;
end;

procedure TMdFormView.MouseMove(Shift : TShiftState; X, Y : Integer);
var
  Cnt    : Integer;
  R      : TRect;
  S      : TRect;
  G      : TMdGuides;
  Sn     : TMdSnap;
  DX, DY : Integer;
  Par    : TRect;
  Off    : TPoint;
  C      : TMdComponent;
  H      : TMdHandle;
begin
  inherited MouseMove(Shift,X,Y);
  if Mode=dmNone then
  begin
    if HandleAt(Point(X,Y),H) then
      case H of
        mhTL, mhBR: Cursor:=crSizeNWSE;
        mhTR, mhBL: Cursor:=crSizeNESW;
        mhT, mhB:   Cursor:=crSizeNS;
      else          Cursor:=crSizeWE;
      end
    else if Placing then Cursor:=crCross
    else Cursor:=crDefault;
    Exit;
  end;
  DX:=X-Down.X;
  DY:=Y-Down.Y;
  if not Moved and (Abs(DX)<2) and (Abs(DY)<2) then Exit;
  Moved:=True;

  if Mode=dmMarquee then
  begin
    MarkUsed:=0;
    Outline(Rect(Min(Down.X,X),Min(Down.Y,Y),Max(Down.X,X)+1,Max(Down.Y,Y)+1),SelColor,1);
    HideUnusedMarks;
    Exit;
  end;

  Sn:=Snap;
  if ssAlt in Shift then
  begin
    Sn.ToGrid:=False;
    Sn.ToEdges:=False;
  end;
  // snap the first dragged component; the others follow it
  C:=Dragged[0];
  R:=MovedRect(Starts[0],Edges,DX,DY);
  // the parent's client area, in the coordinates the component's rectangle uses
  if C.IsForm then Par:=Rect(0,0,100000,100000)
  else if C.Parent.IsForm then Par:=Rect(0,0,FSurface.Width,FSurface.Height)
  else
  begin
    Par:=ParentRect(C.Parent);
    Par:=Rect(0,0,Par.Right-Par.Left,Par.Bottom-Par.Top);
  end;
  S:=SnapRect(R,Edges,Siblings(C),Par,Sn,G);
  DX:=DX+(S.Left-R.Left);
  DY:=DY+(S.Top-R.Top);
  if Mode=dmResize then
  begin
    SetLive(C,S);
  end
  else
    for Cnt:=0 to High(Dragged) do
      SetLive(Dragged[Cnt],MovedRect(Starts[Cnt],Edges,DX,DY));
  UpdateMarks;
  MarkUsed:=0;
  if C.IsForm then Off:=Point(0,TitleH) else Off:=Offset(C);
  for Cnt:=0 to High(G) do
    if G[Cnt].Vertical then Mark(Rect(Off.X+G[Cnt].Pos,0,Off.X+G[Cnt].Pos+1,Height),GuideCol)
    else Mark(Rect(0,Off.Y+G[Cnt].Pos,Width,Off.Y+G[Cnt].Pos+1),GuideCol);
  HideUnusedMarks;
end;

procedure TMdFormView.MouseUp(Button : TMouseButton; Shift : TShiftState; X, Y : Integer);
var
  M   : TRect;
  Cnt : Integer;
  C   : TMdComponent;
  R   : TRect;
begin
  inherited MouseUp(Button,Shift,X,Y);
  MouseCapture:=False;
  if (Mode=dmMarquee) and Moved then
  begin
    M:=Rect(Min(Down.X,X),Min(Down.Y,Y),Max(Down.X,X),Max(Down.Y,Y));
    if not (ssShift in Shift) then FSel.Clear;
    for Cnt:=0 to FForm.ChildCount-1 do
    begin
      C:=FForm.Child(Cnt);
      R:=ViewRect(C);
      if IntersectRect(R,R,M) and (FSel.IndexOf(C)<0) then FSel.Add(C);
    end;
    if FSel.Count=0 then FSel.Add(FForm);
    if Assigned(OnSelect) then OnSelect(Self);
  end
  else if (Mode in [dmMove,dmResize]) and Moved then Commit;
  Mode:=dmNone;
  MarkUsed:=0;      // the guides and the marquee go
  HideUnusedMarks;
  UpdateMarks;
end;

// The live positions and sizes into the model; a drop onto another form or panel moves the
// component into it.
procedure TMdFormView.Commit;
var
  Cnt  : Integer;
  C    : TMdComponent;
  R    : TRect;
  Box  : TMdComponent;
  Drop : TPoint;
  Org  : TPoint;
begin
  if Assigned(OnBeforeChange) then OnBeforeChange(Self);
  for Cnt:=0 to High(Dragged) do
  begin
    C:=Dragged[Cnt];
    if C.IsForm then
    begin
      C.Width:=FSurface.Width;
      C.Height:=FSurface.Height;
      Continue;
    end;
    R:=ParentRect(C);
    C.Left:=R.Left;
    C.Top:=R.Top;
    if (R.Right-R.Left<>Starts[Cnt].Right-Starts[Cnt].Left) or (Mode=dmResize) and
       (Edges*[egLeft,egRight]<>[]) then
    begin
      C.Width:=R.Right-R.Left;
      if C.Row.W=szAuto then C.FixedW:=True;
    end;
    if (R.Bottom-R.Top<>Starts[Cnt].Bottom-Starts[Cnt].Top) or (Mode=dmResize) and
       (Edges*[egTop,egBottom]<>[]) then
    begin
      C.Height:=R.Bottom-R.Top;
      if C.Row.H=szAuto then C.FixedH:=True;
    end;
    if (C.Row.Drawing or (C.TypeId=mdtShape)) and not C.Stretch then
    begin
      C.BitmapW:=C.Width;
      C.BitmapH:=C.Height;
    end;
  end;

  // one component dropped onto another container
  if (Mode=dmMove) and (Length(Dragged)=1) then
  begin
    C:=Dragged[0];
    Drop:=ScreenToClient(Mouse.CursorPos);
    Box:=ContainerAt(Drop,C);
    if (Box<>C.Parent) and FDoc.CanMoveTo(C,Box) then
    begin
      Org:=ViewRect(C).TopLeft;
      if Box.IsForm then Org:=Sub(Org,Point(0,TitleH))
      else Org:=Sub(Org,ViewRect(Box).TopLeft);
      FDoc.MoveTo(C,Box);
      C.Left:=Org.X;
      C.Top:=Org.Y;
    end;
  end;
  if Assigned(OnAfterChange) then OnAfterChange(FForm);
end;

// The arrow keys are the canvas's, not the form's focus navigation.
procedure TMdFormView.WMGetDlgCode(var Message : TLMGetDlgCode);
begin
  Message.Result:=DLGC_WANTARROWS;
end;

// Arrow keys: move by one pixel (Shift: a grid step); with Ctrl, size.
procedure TMdFormView.Nudge(DX, DY : Integer; Resize : Boolean);
var
  Cnt : Integer;
  C   : TMdComponent;
  Any : Boolean;
begin
  Any:=False;
  for Cnt:=0 to FSel.Count-1 do
    if not TMdComponent(FSel[Cnt]).IsForm then Any:=True;
  if not Any then Exit;
  if Assigned(OnBeforeChange) then OnBeforeChange(Self);
  for Cnt:=0 to FSel.Count-1 do
  begin
    C:=TMdComponent(FSel[Cnt]);
    if C.IsForm then Continue;
    if Resize then
    begin
      if (DX<>0) and (C.Row.W<>szFit) then
      begin
        C.Width:=Max(1,C.Width+DX);
        if C.Row.W=szAuto then C.FixedW:=True;
      end;
      if (DY<>0) and (C.Row.H<>szFit) then
      begin
        C.Height:=Max(1,C.Height+DY);
        if C.Row.H=szAuto then C.FixedH:=True;
      end;
      if (C.Row.Drawing or (C.TypeId=mdtShape)) and not C.Stretch then
      begin
        C.BitmapW:=C.Width;
        C.BitmapH:=C.Height;
      end;
    end
    else
    begin
      C.Left:=C.Left+DX;
      C.Top:=C.Top+DY;
    end;
  end;
  if Assigned(OnAfterChange) then OnAfterChange(FForm);
end;

procedure TMdFormView.KeyDown(var Key : Word; Shift : TShiftState);
var
  Step : Integer;
begin
  inherited KeyDown(Key,Shift);
  if ssShift in Shift then Step:=Max(1,Snap.Grid) else Step:=1;
  case Key of
    VK_LEFT:  Nudge(-Step,0,ssCtrl in Shift);
    VK_RIGHT: Nudge(Step,0,ssCtrl in Shift);
    VK_UP:    Nudge(0,-Step,ssCtrl in Shift);
    VK_DOWN:  Nudge(0,Step,ssCtrl in Shift);
    VK_ESCAPE: Placing:=False;
  else
    Exit;
  end;
  Key:=0;
end;

end.
