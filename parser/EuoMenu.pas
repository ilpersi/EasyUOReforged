unit EuoMenu;

{
  Full LCL port of the original Delphi 7 parser\menu.pas -- the MENU script
  command's window/control layer. A first migration pass ported only the
  data-management side (MENU GET/SET/DELETE/ACTIVATE/CLEAR against a plain
  TStringList) and deliberately stubbed every real widget/window as a no-op,
  with a header comment flagging that as deferred to "the GUI-shell phase".
  That follow-up never happened -- every MENU subcommand was a silent no-op,
  so no menu window ever appeared. This is the follow-up: real LCL controls,
  a real TForm, replacing every stub below.

  Ported near-verbatim from menu.pas; deviations, all deliberate and narrow:

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
  - MENU IMAGE FILE's TOleGraphic (COM/ActiveX image loader) is replaced with
    TPicture.LoadFromFile (BMP/PNG/JPEG/GIF natively), per the migration
    plan's own stated guidance for this exact spot.
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
  - SetTransparency's manual GetProcAddress('SetLayeredWindowAttributes')
    dance is replaced with LCL's native AlphaBlend/AlphaBlendValue form
    properties, which wrap the same underlying Win32 call on this target.
  - TBitmap.ScanLine in LCL requires a Begin/EndUpdate bracket (documented on
    the property itself); VCL's did not. Added around ImagePixLine's pixel
    writes -- the only behavior difference forced by the platform, not a
    style choice.
  - TextCreate/ButtonCreate/CheckCreate remap their Str through
    RemapForSymbolFont before assigning Caption. Reported by the user: a
    script selecting a Wingdings glyph by raw character code (a common old
    EasyUO technique for embedding an icon with no bitmap resource) rendered
    nothing, in a real script confirmed to reach TextCreate with its bytes
    completely intact (verified live). Root cause is a genuine platform
    difference, not a bug in the byte-handling above it: VCL's original ANSI
    GDI calls (TextOutA) let Windows map a Symbol-charset font's raw
    character byte straight to its glyph automatically; LCL always draws via
    the Unicode calls (TextOutW), where that same glyph is only reachable at
    Private Use Area codepoint (byte OR $F000) -- Microsoft's own documented
    convention for exposing legacy Symbol-charset fonts to Unicode-aware
    text APIs, which nothing upstream of Caption was doing. See
    RemapForSymbolFont's own comment for the full mapping.
    The PUA remapping alone was not sufficient, though (confirmed by the
    user: the glyph rendered as an empty box, the standard Windows
    "no glyph at this codepoint" indicator, not the door icon). Windows
    GDI only routes a codepoint through a font's special Symbol-charset
    glyph table -- PUA included -- when the selected LOGFONT's charset is
    explicitly SYMBOL_CHARSET; without it, a Symbol-charset font gets
    treated as an ordinary font, which has no glyph mapped at $F0xx
    codepoints at all. Each of TextCreate/ButtonCreate/CheckCreate now
    also sets Font.CharSet:=SYMBOL_CHARSET (via the shared
    IsSymbolFontName check) whenever the selected font is a known
    Symbol-charset one.

  Everything else -- every method name/signature, the Ctrls TStringList of
  UPPERCASE(name)->control pairs, the ClassName-string dispatch in Get/_Set/
  Activate/ComboListAdd/ComboListSelect/ComboListClear/Image*, MyButtonClick's
  MenuButton-from-Ctrls-lookup, MyComboSelect's Tag-tracks-selection trick,
  the exact ImagePixLine byte-decode table -- is preserved exactly, including
  the original's own quirks (e.g. ImagePos guards both Width and Height
  assignment on the *W* parameter's >=0 check, not H's own -- kept as-is,
  matching the original literally, not "fixed").
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls, LCLType,
  LazUTF8, EuoConversion;

type
  TEuoMenuForm  = class(TForm)
  private
    MenuObj     : TObject;
    procedure   MyFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure   MyFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    procedure   CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner : TComponent); override;
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

  TMenuObj      = class(TObject)
  private
    Ctrls       : TStringList;
    procedure   MyButtonClick(Sender : TObject);
    procedure   MyComboSelect(Sender : TObject);
  public
    Form        : TEuoMenuForm;
    FontName    : String;
    FontAlign   : TAlignment;
    FontSize    : Integer;
    FontColor   : Integer;
    FontBG      : Integer;
    FontStyle   : TFontStyles;
    FontTrans   : Boolean;
    MenuButton  : String;
    MenuRes     : String;
    constructor Create;
    procedure   Free;
    procedure   Clear;
    procedure   Del(sName : String);
    procedure   Get(sName : String);
    procedure   _Set(sName,Str : String);
    procedure   Activate(sName : String);
    procedure   TextCreate(sName : String; X,Y : Integer; Str : String);
    procedure   ButtonCreate(sName : String; X,Y,W,H : Integer; Str : String);
    procedure   EditCreate(sName : String; X,Y,W : Integer; Str : String);
    procedure   MemoCreate(sName : String; X,Y,W,H : Integer; Str : String);
    procedure   CheckCreate(sName : String; X,Y,W,H : Integer; C : Boolean; Str : String);
    procedure   ComboCreate(sName : String; X,Y,W : Integer);
    procedure   ListCreate(sName : String; X,Y,W,H : Integer);
    procedure   ComboListAdd(sName,Str : String);
    procedure   ComboListSelect(sName : String; Ind : Integer);
    procedure   ComboListClear(sName : String);
    procedure   ShapeCreate(sName : String; X,Y,W,H,ST,LT,LW,LC,FT,FC : Integer);
    procedure   ImageCreate(sName : String; X,Y,W,H : Integer);
    procedure   ImagePos(sName : String; X,Y : Integer; W:Integer=-1;H:Integer=-1);
    procedure   ImageLine(sName : String; X1,Y1,X2,Y2,C : Integer; W:Integer=1);
    procedure   ImageEllipse(sName:String;X1,Y1,X2,Y2,C : Integer; Fill:Boolean; W:Integer=1);
    procedure   ImageRectangle(sName:String;X1,Y1,X2,Y2,C : Integer; Fill:Boolean; W:Integer=1);
    procedure   ImagePix(sName : String; X,Y,C : Integer);
    procedure   ImagePixLine(sName : String; X,Y : Integer; Data : String);
    procedure   ImageFloodFill(sName : String; X,Y,C : Integer);
    procedure   ImageFile(sName : String; X,Y : Integer; FN : String);
    procedure   Test;
  end;

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

  // The main editor window's TMainMenu carries Ctrl+A/C/X/V/Z shortcuts, and
  // LCL's TApplication.IsShortcut falls back to the MainForm's menu for any key
  // the active (non-main) form doesn't claim -- so without this, Ctrl+A inside
  // a MENU EDIT/MEMO would run Select-All on the *script editor* instead of the
  // focused control. KeyPreview + this handler claim those keys for the edit
  // control first (also giving a plain Win32 TMemo the Ctrl+A it otherwise
  // lacks), so they never reach that fallback.
  KeyPreview:=True;

  OnClose:=MyFormClose;
  OnKeyDown:=MyFormKeyDown;
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
procedure TEuoMenuForm.MyFormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Application.Restore;
  TMenuObj(MenuObj).MenuButton:='CLOSED';
  // CloseAction deliberately left untouched, exactly as the original left its
  // Action parameter untouched -- the default (caHide) is correct: the form
  // must survive being closed via its own [X] button, since TMenuObj.Free is
  // what actually destroys it, not the close action.
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
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TMenuObj.Create;
begin
  inherited Create;
  Ctrls:=TStringList.Create;
  Form:=TEuoMenuForm.Create(nil);
  Form.MenuObj:=self;
  Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Free;
begin
  Clear;
  Ctrls.Free;
  Form.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Clear;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Ctrls.Count-1 do
    Ctrls.Objects[Cnt].Free;
  Ctrls.Clear;
  FontName:='Arial';
  FontAlign:=taLeftJustify;
  FontSize:=10;
  FontColor:=clBlack;
  FontBG:=clBtnFace;
  FontStyle:=[];
  FontTrans:=False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Del(sName : String);
var
  Cnt : Integer;
begin
  sName:=UpperCase(sName);
  for Cnt:=Ctrls.Count-1 downto 0 do
    if Ctrls[Cnt]=sName then
  begin
    Ctrls.Objects[Cnt].Free;
    Ctrls.Delete(Cnt);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Get(sName : String);
var
  Cnt  : Integer;
  Obj  : TObject;
begin
  MenuRes:='N/A';
  Cnt:=Ctrls.IndexOf(UpperCase(sName));
  if Cnt<0 then Exit;

  // TLabel deliberately excluded -- its text may contain embedded CRLFs
  // (see TextCreate's '$'->CRLF substitution), which MenuRes isn't meant to
  // carry. Matches the original exactly, including this omission.
  Obj:=Ctrls.Objects[Cnt];
  if Obj.ClassName='TEdit' then
    MenuRes:=TEdit(Obj).Text
  else if Obj.ClassName='TMemo' then
    // Fold the memo's line breaks back to '$' -- the same encoding MemoCreate
    // (and SysMsg) accept -- so MenuRes stays a single-line value.
    MenuRes:=ReplaceStr(ReplaceStr(TMemo(Obj).Text,#13#10,'$'),#10,'$')
  else if Obj.ClassName='TComboBox' then
    MenuRes:=IntToStr(TComboBox(Obj).Tag+1)
  else if Obj.ClassName='TListBox' then
    MenuRes:=IntToStr(TListBox(Obj).ItemIndex+1)
  else if Obj.ClassName='TCheckBox' then
    if TCheckBox(Obj).Checked then MenuRes:='-1'
    else MenuRes:='0';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj._Set(sName,Str : String);
var
  Cnt : Integer;
  Obj : TObject;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
  begin
    Obj:=Ctrls.Objects[Cnt];
    if Obj.ClassName='TEdit' then
      TEdit(Obj).Text:=Str
    else if Obj.ClassName='TMemo' then
      TMemo(Obj).Text:=ReplaceStr(Str,'$',#13#10)
    else if Obj.ClassName='TLabel' then  // "$" doesn't work here
      TLabel(Obj).Caption:=Str
    else if Obj.ClassName='TEuoMenuButton' then
      TEuoMenuButton(Obj).Caption:=Str
    else if Obj.ClassName='TCheckBox' then
      TCheckBox(Obj).Checked:=SToI64Def(Str,0)<>0;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Activate(sName : String);
var
  Cnt : Integer;
  Obj : TObject;
begin
  Cnt:=Ctrls.IndexOf(UpperCase(sName));
  if Cnt<0 then Exit;

  Obj:=Ctrls.Objects[Cnt];
  if (Obj.ClassName='TEdit')or(Obj.ClassName='TMemo')or
    (Obj.ClassName='TEuoMenuButton')or
    (Obj.ClassName='TComboBox')or(Obj.ClassName='TListBox')or
    (Obj.ClassName='TCheckBox') then
      Form.ActiveControl:=TWinControl(Obj);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.TextCreate(sName : String; X,Y : Integer; Str : String);
var
  NewLabel : TLabel;
begin
  NewLabel:=TLabel.Create(nil);
  NewLabel.Left:=X;
  NewLabel.Top:=Y;

  NewLabel.Font.Name:=FontName;
  NewLabel.Font.Size:=FontSize;
  NewLabel.Font.Color:=FontColor;
  NewLabel.Color:=FontBG;
  NewLabel.Transparent:=FontTrans;
  NewLabel.Font.Style:=FontStyle;
  NewLabel.Width:=0;
  NewLabel.Alignment:=FontAlign;
  // A Symbol-charset font (Wingdings/etc) must be explicitly told so via
  // Font.CharSet -- otherwise Windows GDI selects it as a normal font, which
  // has no glyph at all at the Private Use Area codepoints RemapForSymbolFont
  // produces below, rendering as the classic "missing glyph" empty box
  // rather than the intended icon. See RemapForSymbolFont's own comment.
  if IsSymbolFontName(FontName) then
    NewLabel.Font.CharSet:=SYMBOL_CHARSET;

  NewLabel.Caption:=RemapForSymbolFont(ReplaceStr(Str,'$',#13#10),FontName);
  NewLabel.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewLabel);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ButtonCreate(sName : String; X,Y,W,H : Integer; Str : String);
var
  NewButton : TEuoMenuButton;
begin
  NewButton:=TEuoMenuButton.Create(nil);
  NewButton.Left:=X;
  NewButton.Top:=Y;
  NewButton.Width:=W;
  NewButton.Height:=H;

  NewButton.Font.Name:=FontName;
  NewButton.Font.Size:=FontSize;
  NewButton.Font.Style:=FontStyle;
  NewButton.Font.Color:=FontColor;
  NewButton.Color:=FontBG;
  if IsSymbolFontName(FontName) then
    NewButton.Font.CharSet:=SYMBOL_CHARSET;
  NewButton.Caption:=RemapForSymbolFont(Str,FontName);
  NewButton.Parent:=Form;
  NewButton.OnClick:=MyButtonClick;

  Ctrls.AddObject(UpperCase(sName),NewButton);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.EditCreate(sName : String; X,Y,W : Integer; Str : String);
var
  NewEdit : TEdit;
begin
  NewEdit:=TEdit.Create(nil);
  NewEdit.Left:=X;
  NewEdit.Top:=Y;
  NewEdit.Width:=W;

  NewEdit.Font.Name:=FontName;
  NewEdit.Font.Size:=FontSize;
  NewEdit.Font.Color:=FontColor;
  NewEdit.Color:=FontBG;
  NewEdit.Font.Style:=FontStyle;
  NewEdit.Text:=Str;
  NewEdit.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewEdit);
end;

////////////////////////////////////////////////////////////////////////////////
// Not in the original EasyUO's MENU repertoire -- added for EasyUO Reforged.
// A multi-line counterpart to EDIT: a scrollable TMemo whose Str honors the
// same '$'->CRLF convention TEXT uses, so a script can drop a many-line block
// of text into a window the user can scroll, select, and copy out verbatim.
procedure TMenuObj.MemoCreate(sName : String; X,Y,W,H : Integer; Str : String);
var
  NewMemo : TMemo;
begin
  NewMemo:=TMemo.Create(nil);
  NewMemo.Left:=X;
  NewMemo.Top:=Y;
  NewMemo.Width:=W;
  NewMemo.Height:=H;

  NewMemo.Font.Name:=FontName;
  NewMemo.Font.Size:=FontSize;
  NewMemo.Font.Color:=FontColor;
  NewMemo.Color:=FontBG;
  NewMemo.Font.Style:=FontStyle;
  NewMemo.ScrollBars:=ssAutoBoth;
  NewMemo.WordWrap:=False;
  NewMemo.WantTabs:=False;
  NewMemo.Text:=ReplaceStr(Str,'$',#13#10);
  NewMemo.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewMemo);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.CheckCreate(sName : String; X,Y,W,H : Integer; C : Boolean; Str : String);
var
  NewCheck : TCheckBox;
begin
  NewCheck:=TCheckBox.Create(nil);
  // LCL's TCheckBox defaults AutoSize:=True (confirmed via component
  // source), unlike VCL's, which respects an explicitly-set small
  // Width/Height and clips an oversized caption against it. Without this, a
  // script whose caption text is too long to fit the declared box (e.g. one
  // that reuses the control's own internal name as a placeholder caption,
  // as real scripts do -- expecting it to stay invisible, clipped by a
  // tiny declared size) gets silently resized to fit instead of clipped,
  // making text visible that the original never showed. Explicitly disabled
  // to match VCL's behavior and respect the script's own declared bounds
  // exactly.
  NewCheck.AutoSize:=False;
  NewCheck.Left:=X;
  NewCheck.Top:=Y;
  NewCheck.Width:=W;
  NewCheck.Height:=H;
  NewCheck.Checked:=C;

  if FontAlign=taRightJustify then NewCheck.Alignment:=taLeftJustify
  else NewCheck.Alignment:=taRightJustify;
  NewCheck.Font.Name:=FontName;
  NewCheck.Font.Size:=FontSize;
  NewCheck.Font.Color:=FontColor;
  NewCheck.Color:=FontBG;
  NewCheck.Font.Style:=FontStyle;
  // LCL's TCheckBox has no WordWrap property (unlike VCL's) -- confirmed via
  // component source, not guessed. Cosmetic-only gap: a long caption simply
  // won't wrap within Width/Height any more; nothing else depends on this.
  if IsSymbolFontName(FontName) then
    NewCheck.Font.CharSet:=SYMBOL_CHARSET;
  NewCheck.Caption:=RemapForSymbolFont(Str,FontName);
  NewCheck.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewCheck);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ComboCreate(sName : String; X,Y,W : Integer);
var
  NewCombo : TComboBox;
begin
  NewCombo:=TComboBox.Create(nil);
  NewCombo.Left:=X;
  NewCombo.Top:=Y;
  NewCombo.Width:=W;

  NewCombo.Font.Name:=FontName;
  NewCombo.Font.Size:=FontSize;
  NewCombo.Font.Color:=FontColor;
  NewCombo.Color:=FontBG;
  NewCombo.Font.Style:=FontStyle;
  NewCombo.Style:=csDropDownList;
  NewCombo.Tag:=-1;
  NewCombo.OnSelect:=MyComboSelect;
  NewCombo.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewCombo);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ListCreate(sName : String; X,Y,W,H : Integer);
var
  NewList : TListBox;
begin
  NewList:=TListBox.Create(nil);
  NewList.Left:=X;
  NewList.Top:=Y;
  NewList.Width:=W;
  NewList.Height:=H;

  NewList.Font.Name:=FontName;
  NewList.Font.Size:=FontSize;
  NewList.Font.Color:=FontColor;
  NewList.Color:=FontBG;
  NewList.Font.Style:=FontStyle;
  NewList.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewList);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ComboListAdd(sName,Str : String);
var
  Cnt : Integer;
  Obj : TObject;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
  begin
    Obj:=Ctrls.Objects[Cnt];
    if Obj.ClassName='TListBox' then
      TListBox(Obj).Items.Add(Str)
    else if Obj.ClassName='TComboBox' then
      TComboBox(Obj).Items.Add(Str);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ComboListSelect(sName : String; Ind : Integer);
var
  Cnt : Integer;
  Obj : TObject;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
  begin
    Obj:=Ctrls.Objects[Cnt];
    if Obj.ClassName='TListBox' then
      TListBox(Obj).ItemIndex:=Ind-1
    else if Obj.ClassName='TComboBox' then
    begin
      TComboBox(Obj).ItemIndex:=Ind-1;
      TComboBox(Obj).Tag:=Ind-1;
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ComboListClear(sName : String);
var
  Cnt : Integer;
  Obj : TObject;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
  begin
    Obj:=Ctrls.Objects[Cnt];
    if Obj.ClassName='TListBox' then
      TListBox(Obj).Items.Clear
    else if Obj.ClassName='TComboBox' then
    begin
      TComboBox(Obj).Items.Clear;
      TComboBox(Obj).Tag:=-1;
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ShapeCreate(sName : String; X,Y,W,H,ST,LT,LW,LC,FT,FC : Integer);
var
  NewShape  : TShape;
begin
  NewShape:=TShape.Create(nil);
  NewShape.Left:=X;
  NewShape.Top:=Y;
  NewShape.Width:=W;
  NewShape.Height:=H;

  case ST of
    1: NewShape.Shape:=stCircle;
    2: NewShape.Shape:=stEllipse;
    4: NewShape.Shape:=stRoundRect;
    5: NewShape.Shape:=stRoundSquare;
    6: NewShape.Shape:=stSquare;
  else NewShape.Shape:=stRectangle;
  end;

  NewShape.Pen.Color:=LC;

  case LT of
    1: NewShape.Pen.Style:=psClear;
    2: NewShape.Pen.Style:=psDash;
    3: NewShape.Pen.Style:=psDashDot;
    4: NewShape.Pen.Style:=psDashDotDot;
    5: NewShape.Pen.Style:=psDot;
    6: NewShape.Pen.Style:=psInsideFrame;
  else NewShape.Pen.Style:=psSolid;
  end;

  NewShape.Pen.Width:=LW;

  NewShape.Brush.Color:=FC;

  case FT of
    1: NewShape.Brush.Style:=bsBDiagonal;
    2: NewShape.Brush.Style:=bsClear;
    3: NewShape.Brush.Style:=bsCross;
    4: NewShape.Brush.Style:=bsDiagCross;
    5: NewShape.Brush.Style:=bsFDiagonal;
    6: NewShape.Brush.Style:=bsHorizontal;
    8: NewShape.Brush.Style:=bsVertical;
  else NewShape.Brush.Style:=bsSolid;
  end;

  NewShape.Parent:=Form;

  Ctrls.AddObject(UpperCase(sName),NewShape);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageCreate(sName : String; X,Y,W,H : Integer);
var
  NewImage : TImage;
begin
  NewImage:=TImage.Create(nil);
  NewImage.Left:=X;
  NewImage.Top:=Y;
  NewImage.Width:=W;
  NewImage.Height:=H;

  NewImage.Transparent:=True;
  NewImage.Picture.Bitmap.TransparentColor:=$FEEEED;
  NewImage.Picture.Bitmap.PixelFormat:=pf32bit;
  NewImage.Picture.Bitmap.Height:=H;
  NewImage.Picture.Bitmap.Width:=W;
  NewImage.Canvas.Brush.Color:=$FEEEED;
  NewImage.Canvas.Rectangle(-10,-10,W+10,H+10);

  NewImage.Parent:=Form;
  Ctrls.AddObject(UpperCase(sName),NewImage);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImagePos(sName : String; X,Y : Integer; W:Integer=-1;H:Integer=-1);
var
  Cnt : Integer;
  Img : TImage;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Img:=TImage(Ctrls.Objects[Cnt]);
    Img.Left:=X;
    Img.Top:=Y;
    // Matches the original literally: both Width and Height are guarded by
    // W's own >=0 check, not H's -- not "fixed" here, see unit header comment.
    if W>=0 then Img.Width:=W;
    if W>=0 then Img.Height:=H;
    Img.Stretch:=True;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageLine(sName : String; X1,Y1,X2,Y2,C : Integer; W:Integer=1);
var
  Cnt : Integer;
  Cvs : TCanvas;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Cvs:=TImage(Ctrls.Objects[Cnt]).Canvas;
    Cvs.Pen.Color:=C;
    Cvs.Pen.Width:=W;
    Cvs.MoveTo(X1,Y1);
    Cvs.LineTo(X2,Y2);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageEllipse(sName:String;X1,Y1,X2,Y2,C : Integer; Fill:Boolean; W:Integer=1);
var
  Cnt : Integer;
  Cvs : TCanvas;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Cvs:=TImage(Ctrls.Objects[Cnt]).Canvas;
    Cvs.Pen.Color:=C;
    Cvs.Pen.Width:=W;
    Cvs.Brush.Color:=C;
    if Fill then Cvs.Brush.Style:=bsSolid
    else Cvs.Brush.Style:=bsClear;
    Cvs.Ellipse(X1,Y1,X2,Y2);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageRectangle(sName:String;X1,Y1,X2,Y2,C : Integer; Fill:Boolean; W:Integer=1);
var
  Cnt : Integer;
  Cvs : TCanvas;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Cvs:=TImage(Ctrls.Objects[Cnt]).Canvas;
    Cvs.Pen.Color:=C;
    Cvs.Pen.Width:=W;
    Cvs.Brush.Color:=C;
    if Fill then Cvs.Brush.Style:=bsSolid
    else Cvs.Brush.Style:=bsClear;
    Cvs.Rectangle(X1,Y1,X2,Y2);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImagePix(sName : String; X,Y,C : Integer);
var
  Cnt : Integer;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
      TImage(Ctrls.Objects[Cnt]).Canvas.Pixels[X,Y]:=C;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImagePixLine(sName : String; X,Y : Integer; Data : String);
type
  TPixel = packed Array[0..3] of Byte;
  TPixArray = packed Array[0..99999] of TPixel;
const
  Feed : Array[0..2] of Byte = ($FE,$EE,$ED);
var
  Cnt  : Integer;
  Cnt2 : Integer;
  Cnt3 : Integer;
  Pix  : ^TPixArray;
  X2   : Integer;
  sBuf : String;
  Bmp  : TBitmap;
  Img  : TImage;
  Skip : Boolean;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Img:=TImage(Ctrls.Objects[Cnt]);
    Bmp:=Img.Picture.Bitmap;

    if (Y<0)or(Y>=Img.Height) then Continue;
    X2:=X-1+Length(Data)div 3;
    if (X<0)or(X2>=Img.Width) then Continue;

    sBuf:=UpperCase(Data);
    Skip:=False;
    // LCL's TBitmap.ScanLine (unlike VCL's) must be bracketed by
    // Begin/EndUpdate -- see unit header comment.
    Bmp.BeginUpdate(True);
    try
      Pix:=Bmp.ScanLine[Y];
      for Cnt2:=X to X2 do
      begin
        Pix[Cnt2][3]:=0;
        for Cnt3:=2 downto 0 do
        case Byte(sBuf[3-Cnt3]) of
          65..90 : Pix[Cnt2][Cnt3]:=8*(Byte(sBuf[3-Cnt3])-65);
          49..54 : Pix[Cnt2][Cnt3]:=8*(Byte(sBuf[3-Cnt3])-23);
          57     : begin end;
          56     : Pix[Cnt2][Cnt3]:=Feed[Cnt3];
          else       begin Skip:=True; Break; end;
        end;
        if Skip then Break;
        Delete(sBuf,1,3);
      end;
    finally
      Bmp.EndUpdate;
    end;
    if Skip then Exit;

    Img.Invalidate; // replaces the original's "read Canvas.Pixels[0,0] back
                     // to force a repaint" hack -- see the migration plan's
                     // stated guidance for this exact spot.
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageFloodFill(sName : String; X,Y,C : Integer);
var
  Cnt : Integer;
  Cvs : TCanvas;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Cvs:=TImage(Ctrls.Objects[Cnt]).Canvas;
    Cvs.Brush.Color:=C;
    Cvs.FloodFill(X,Y,Cvs.Pixels[X,Y],fsSurface);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageFile(sName : String; X,Y : Integer; FN : String);
var
  Cnt : Integer;
  Pic : TPicture;
begin
  if not FileExists(FN) then Exit;
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
  begin
    Pic:=TPicture.Create;
    try
      try
        Pic.LoadFromFile(FN);
        TImage(Ctrls.Objects[Cnt]).Canvas.Draw(X,Y,Pic.Graphic);
      except end;
    finally
      Pic.Free;
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Test;
begin
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.MyButtonClick(Sender : TObject);
var
  Cnt : Integer;
begin
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls.Objects[Cnt]=Sender then
      MenuButton:=Ctrls[Cnt];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.MyComboSelect(Sender : TObject);
begin
  TComboBox(Sender).Tag:=TComboBox(Sender).ItemIndex;
end;

end.
