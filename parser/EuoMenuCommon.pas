unit EuoMenuCommon;

{
  The window-system layer shared by the MENU implementations: the classes and helpers that exist
  because of LCL and Windows, not because of anything EasyUO does. Moved verbatim out of
  EuoMenu.pas (the 1.5 MENU logic) so that the 1.6 MENU logic uses the same window, button and
  glyph handling instead of a second copy (docs/menu-1.6-analysis.md, section 6.4).

  The one change made in the move: TEuoMenuForm no longer assigns its own OnClose. What closing
  the window means (#MenuButton becomes CLOSED in 1.5, the form's name in 1.6) belongs to the MENU
  logic that owns the form, so the owner assigns OnClose (TMenuObj.MyFormClose in EuoMenu.pas).

  The deviations from the original Delphi 7 parser\menu.pas that live in this unit, as they were
  documented in EuoMenu.pas:

  - TBitBtnWithColor (parser\colorbtn.pas, ~1080 lines) is NOT ported. It's a
    Windows-owner-draw (WM_MEASUREITEM/WM_DRAWITEM) TButton descendant whose
    only behavior menu.pas actually exercises is a plain button that honors
    Font.* and a solid background Color -- something LCL's native TButton
    does not reliably support cross-widgetset any more than VCL's did (the
    original needed a custom class for exactly this reason). Replaced with
    TEuoMenuButton below: a small self-painted TCustomControl with the same
    public surface menu.pas needs (Caption/Font/Color/OnClick). This is a
    deliberate scope reduction, not a silent one -- flagged here and at the
    class itself.
  - TMenuForm's CreateParams(WS_EX_TOPMOST) override IS kept, unlike most of
    the rest of this file's Win32-API-manual-plumbing -- a first revision of
    this file replaced it with LCL's FormStyle:=fsStayOnTop instead, which
    compiled and reported Visible=True/HandleAllocated=True/Showing=True in
    testing, but every non-native (Canvas-painted) child -- Labels, Shapes,
    Images, and TEuoMenuButton below -- silently never actually rendered,
    while native win32 Edit/CheckBox children (drawn by the OS independently
    of this form's own paint cycle) did. Confirmed by comparison against
    easyuo\text.pas's TTextForm, an already-working form elsewhere in this
    migration with a real rendering TLabel among its children, whose only
    meaningful difference from this one was the absence of fsStayOnTop.
    Reverted to the original's own CreateParams technique, which carries no
    such risk since it's exactly what TTextForm's (working) code path already
    exercises. The desktop-reparenting half of the original's hack
    (WndParent:=GetDesktopWindow) is NOT restored -- WS_EX_TOPMOST alone is
    sufficient for "stay on top" and doesn't touch how LCL tracks this form's
    parent/owner relationships.
    The ownership half IS needed, though, for a different reason: with the
    LCL default owner (the hidden Application window) minimizing/restoring the
    editor window minimized/restored the MENU window with it, so scripts like
    Claw whose menu is meant to be shrunk or minimized independently (it shows
    live status) could not be managed separately. TEuoMenuForm.Create now sets
    ShowInTaskBar:=stAlways, which leaves the window owner at 0 -- see there.
    Staying on top of ANOTHER PROCESS's window (the UO client) needs one more
    thing. LCL's Win32 layer answers WM_ACTIVATEAPP(deactivate) by stripping
    WS_EX_TOPMOST from every window of the thread (RemoveStayOnTopFlags: sent
    to HWND_BOTTOM, then HWND_TOP -- by design, so an LCL application's
    stay-on-top forms never cover other programs), however the flag got there
    (FormStyle or CreateParams alike), and only puts it back when the
    application is re-activated. So the moment the client was focused the MENU
    window dropped behind it. TEuoMenuForm.AppDeactivated re-applies
    HWND_TOPMOST from Application's deactivate handler list, which LCL runs
    (queued) after that demotion.
  - SetTransparency's manual GetProcAddress('SetLayeredWindowAttributes')
    dance is replaced with LCL's native AlphaBlend/AlphaBlendValue form
    properties, which wrap the same underlying Win32 call on this target.
}

{$mode delphi}{$H+}

interface
uses
  Windows, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  LCLType, LazUTF8;

type
  TEuoMenuForm  = class(TForm)
  private
    procedure   MyFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure   AppDeactivated(Sender: TObject);
  protected
    procedure   CreateParams(var Params: TCreateParams); override;
  public
    Surface     : TPanel;      // parent of every MENU control -- see Create
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
    procedure   SetTransparency(Value : Byte);
    procedure   ShowEUO;
    procedure   HideEUO;
  end;

  // Deliberate replacement for the original's TBitBtnWithColor -- see unit
  // header comment. A small self-painted button: flat rectangle, Frame3D
  // border (raised normally, sunken while pressed -- see MouseDown/MouseUp),
  // centered caption in the configured Font, filled with the configured
  // Color. Fires the inherited TControl.OnClick exactly like any other
  // windowed control on a normal mouse click (no custom click-dispatch
  // needed -- TControl's default WMLButtonUp handling already does this);
  // MouseDown/MouseUp are overridden purely for the pressed-state repaint,
  // not to implement clicking itself.
  TEuoMenuButton = class(TCustomControl)
  private
    FPressed : Boolean;
  protected
    procedure   Paint; override;
    procedure   MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure   MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner : TComponent); override;
  end;

function  IsSymbolFontName(const AFontName : String) : Boolean;
function  RemapForSymbolFont(const Str, AFontName : String) : String;
procedure InvalidateImageMask(Img : TImage);

implementation

////////////////////////////////////////////////////////////////////////////////
// Added during this migration -- not present in (or needed by) the original
// VCL/Delphi 7 menu.pas. Symbol-charset fonts (Wingdings/Webdings/Symbol/
// Marlett) are a Windows-specific legacy convention: their glyphs are keyed
// by raw single-byte character codes ($20-$FF), not "real" Unicode
// codepoints. When text is drawn via the old ANSI GDI calls (TextOutA),
// Windows maps a byte straight to the font's glyph automatically. LCL,
// like any modern Unicode-first toolkit, draws all text via the Unicode
// calls (TextOutW) and treats String/Caption content as UTF-8 throughout --
// and under that path, a Symbol-charset font's glyphs are only reachable at
// Private Use Area codepoints $F020-$F0FF (byte value OR $F000), per
// Microsoft's own documented convention for exposing legacy Symbol-charset
// fonts to Unicode-aware text APIs. A script written for the original
// (ANSI-native) EasyUO -- like a "Menu Text ... <raw glyph byte>" line
// selecting a Wingdings icon -- supplies the raw byte value expecting the
// old automatic mapping, which never happens on this path, so the glyph
// silently fails to resolve.
//
// This remaps each character of Str into that Private Use Area range
// whenever the currently-selected font name looks like a known
// Symbol-charset font, and is a no-op otherwise. It also has to cope with
// not knowing, in general, whether the script's own on-disk encoding for
// the raw glyph byte survived as literal Latin-1/CP1252 bytes or was
// re-saved as UTF-8 by an intervening modern text editor: if Str parses as
// valid UTF-8, it's decoded properly first (recovering the original
// codepoint, e.g. U+00CF for a 2-byte UTF-8 "Ï"); otherwise every raw byte
// is treated as its own Latin-1 codepoint directly. Either way, the
// resulting codepoint is what gets OR'd with $F000.
function IsSymbolFontName(const AFontName : String) : Boolean;
const
  SymbolFontNames : array[0..3] of String = ('WINGDING','WEBDING','SYMBOL','MARLETT');
var
  UpName : String;
  Cnt    : Integer;
begin
  Result:=False;
  UpName:=UpperCase(Trim(AFontName));
  for Cnt:=0 to High(SymbolFontNames) do
    if Pos(SymbolFontNames[Cnt],UpName)>0 then
    begin
      Result:=True;
      Exit;
    end;
end;

function RemapForSymbolFont(const Str, AFontName : String) : String;
var
  UStr      : UnicodeString;
  Cnt       : Integer;
  Codepoint : Word;
begin
  Result:=Str;
  if Str='' then Exit;
  if not IsSymbolFontName(AFontName) then Exit;

  if FindInvalidUTF8Codepoint(PChar(Str),Length(Str))<0 then
    UStr:=UTF8ToUTF16(Str)
  else
  begin
    SetLength(UStr,Length(Str));
    for Cnt:=1 to Length(Str) do
      UStr[Cnt]:=WideChar(Ord(Str[Cnt]));
  end;

  for Cnt:=1 to Length(UStr) do
  begin
    Codepoint:=Word(UStr[Cnt]);
    if (Codepoint>=$20) and (Codepoint<=$FF) then
      UStr[Cnt]:=WideChar(Codepoint or $F000);
  end;

  Result:=UTF16ToUTF8(UStr);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoMenuForm.Create(AOwner : TComponent);
begin
  inherited CreateNew(AOwner);

  // Matches the original's menu.dfm defaults (Left/Top/Width/Height/Caption/
  // Color/Font) -- there is no .lfm here, per this migration's established
  // build-every-form-in-code approach (see main.pas's header comment).
  Left:=10;
  Top:=10;
  Width:=200;
  Height:=100;
  Caption:='EUO Menu';
  Color:=clBtnFace;
  Font.Name:='Arial';
  Position:=poDesigned;         // honor explicit Left/Top, don't auto-center
  Visible:=False;                // hidden until "MENU SHOW" -- matches original

  // Make this an independent top-level window. By default LCL/Win32 makes every
  // non-main form owned by the hidden Application window, and minimizing the
  // main form minimizes that Application window -- which Windows applies to
  // every window it owns, so the MENU window used to vanish and reappear in
  // lock-step with the editor. stAlways makes LCL leave the owner at 0 (the
  // same effect as the original's WndParent:=GetDesktopWindow), and gives the
  // window its own taskbar button so it can be minimized/restored on its own.
  ShowInTaskBar:=stAlways;

  // Every MENU control goes on this panel rather than on the form, so that
  // TMenuObj's repaint hold can sit on a child window instead of on this
  // top-level one -- see TMenuObj.BurstBegin. No border and alClient keep the
  // controls' X/Y exactly where they were; ParentColor (the TPanel default)
  // keeps MENU WINDOW COLOR colouring the whole window.
  Surface:=TPanel.Create(Self);
  Surface.BevelOuter:=bvNone;
  Surface.Align:=alClient;
  Surface.Parent:=Self;

  // The main editor window's TMainMenu carries Ctrl+A/C/X/V/Z shortcuts, and
  // LCL's TApplication.IsShortcut falls back to the MainForm's menu for any key
  // the active (non-main) form doesn't claim -- so without this, Ctrl+A inside
  // a MENU EDIT/MEMO would run Select-All on the *script editor* instead of the
  // focused control. KeyPreview + this handler claim those keys for the edit
  // control first (also giving a plain Win32 TMemo the Ctrl+A it otherwise
  // lacks), so they never reach that fallback.
  KeyPreview:=True;

  OnKeyDown:=MyFormKeyDown;
  Application.AddOnDeactivateHandler(AppDeactivated);
end;

////////////////////////////////////////////////////////////////////////////////
destructor TEuoMenuForm.Destroy;
begin
  if Application<>nil then
    Application.RemoveOnDeactivateHandler(AppDeactivated);
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
// Runs (queued) after LCL's WM_ACTIVATEAPP handling has stripped WS_EX_TOPMOST
// from this window because another process's window -- typically the UO client
// -- took the focus; see the unit header. Putting it back keeps the MENU window
// above the client. Skipped while a modal dialog is up: LCL deliberately lowers
// stay-on-top windows then so the dialog is not covered, and restores them
// itself once the dialog closes.
procedure TEuoMenuForm.AppDeactivated(Sender: TObject);
begin
  if not (HandleAllocated and Visible) then Exit;
  if Application.ModalLevel>0 then Exit;
  SetWindowPos(Handle,HWND_TOPMOST,0,0,0,0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuForm.MyFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Ed : TCustomEdit;
begin
  if Shift<>[ssCtrl] then Exit;
  if not (ActiveControl is TCustomEdit) then Exit;

  Ed:=TCustomEdit(ActiveControl);
  case Key of
    VK_A: Ed.SelectAll;
    VK_C: Ed.CopyToClipboard;
    VK_X: Ed.CutToClipboard;
    VK_V: Ed.PasteFromClipboard;
    VK_Z: Ed.Undo;
  else
    Exit;
  end;
  Key:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // "Always on top" via the same raw WS_EX_TOPMOST flag the original used,
  // rather than LCL's FormStyle:=fsStayOnTop abstraction -- an earlier
  // revision used fsStayOnTop and every non-native (Canvas-painted) child
  // control silently failed to render (native win32 Edit/CheckBox still
  // did, since the OS draws those independently of this form's own paint
  // cycle). This CreateParams override is the exact technique this
  // migration's easyuo\text.pas TTextForm already uses successfully
  // elsewhere (that form has no such override and no such problem, and
  // this is the one property this form had that TTextForm doesn't) -- see
  // unit header comment for the full reasoning.
  Params.ExStyle:=Params.ExStyle or WS_EX_TOPMOST;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuForm.SetTransparency(Value : Byte);
begin
  AlphaBlendValue:=Value;
  AlphaBlend:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuForm.ShowEUO;
begin
  Application.Restore;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuForm.HideEUO;
begin
  Application.Minimize;
  Show;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoMenuButton.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  ControlStyle:=ControlStyle+[csOpaque];
  TabStop:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuButton.Paint;
var
  R  : TRect;
  TS : TTextStyle;
begin
  R:=ClientRect;
  Canvas.Brush.Color:=Color;
  Canvas.Brush.Style:=bsSolid;
  Canvas.FillRect(R);
  if FPressed then
    Canvas.Frame3d(R,2,bvLowered)
  else
    Canvas.Frame3d(R,2,bvRaised);

  Canvas.Brush.Style:=bsClear;
  Canvas.Font:=Font;
  FillChar(TS,SizeOf(TS),0);
  TS.Alignment:=taCenter;
  TS.Layout:=tlCenter;
  TS.WordBreak:=True;
  TS.Opaque:=False;
  Canvas.TextRect(R,0,0,Caption,TS);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button,Shift,X,Y);
  if Button=mbLeft then
  begin
    FPressed:=True;
    Invalidate;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button=mbLeft then
  begin
    FPressed:=False;
    Invalidate;
  end;
  inherited MouseUp(Button,Shift,X,Y);
end;

////////////////////////////////////////////////////////////////////////////////
// LCL builds a colour-keyed image's transparency mask lazily on first paint and
// caches it; drawing on the bitmap afterwards does not invalidate it. Scripts
// routinely SHOW the window first and draw into images later (SOS Master), so
// without this a strip painted blank once stays fully transparent for good.
// Dropping the cached mask makes the next paint rebuild it from current pixels.
procedure InvalidateImageMask(Img : TImage);
begin
  Img.Picture.Bitmap.MaskHandle:=0;
end;

end.
