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

  - The window and button classes, the Symbol-font helpers and the MENU IMAGE primitives
    (image setup and drawing, per control) live in EuoMenuCommon.pas, shared with the 1.6
    MENU logic, and their deviations from menu.pas are documented there:
    TBitBtnWithColor replaced by TEuoMenuButton; TMenuForm's CreateParams(WS_EX_TOPMOST), the
    window's own taskbar button and HWND_TOPMOST re-applied after deactivation; SetTransparency
    through AlphaBlend. TMenuObj.MyFormClose is the original TMenuForm.MyFormClose, moved here
    because what closing the window means is MENU logic, not window plumbing.
  - MENU IMAGE FILE's TOleGraphic (COM/ActiveX image loader) is replaced with
    TPicture.LoadFromFile (BMP/PNG/JPEG/GIF natively), per the migration
    plan's own stated guidance for this exact spot.
  - MENU IMAGE bitmaps are 24bpp, not the original's 32bpp (ImageCreate/
    ImagePixLine). LCL's 32bpp bitmaps have an alpha channel that GDI drawing
    leaves at 0, and its colour-key transparency compares alpha too, so the
    $FEEEED key never matched and every image painted as an opaque block --
    hiding whatever was behind it (e.g. SOS Master's blue sea).
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
    RemapForSymbolFont's own comment (EuoMenuCommon.pas) for the full mapping.
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
  - Controls are parented to TEuoMenuForm.Surface, a borderless panel filling
    the client area, not to the form itself. TMenuObj's repaint coalescing (not
    in the original) holds painting with WM_SETREDRAW, which Windows implements
    by clearing WS_VISIBLE; held on the top-level window, that made the MENU
    window count as hidden for every burst -- its taskbar button blinked off and
    on with each update, and clicks went through it to the window below (the UO
    client). Held on a child window it does neither. See TMenuObj.BurstBegin.

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
  Windows, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  LCLType, LazUTF8, EuoConversion, EuoMenuCommon;

type
  TMenuObj      = class(TObject)
  private
    Ctrls       : TStringList;
    RedrawOff   : Boolean;     // WM_SETREDRAW(False) currently in force on Form
    BurstStart  : QWord;       // GetTickCount64 when RedrawOff was last set
    BurstTimer  : TTimer;      // fires once the command burst has gone quiet
    procedure   BurstTimerFire(Sender : TObject);
    procedure   AttachCtrl(C : TControl);
    procedure   MyButtonClick(Sender : TObject);
    procedure   MyComboSelect(Sender : TObject);
    procedure   MyFormClose(Sender: TObject; var CloseAction: TCloseAction);
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
    procedure   BurstBegin;
    procedure   BurstJoin;
    procedure   BurstFlush;
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

const
  BURST_QUIET_MS = 30;    // repaint once no MENU command arrived for this long
  BURST_MAX_MS   = 100;   // ...but never hold painting longer than this

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TMenuObj.Create;
begin
  inherited Create;
  Ctrls:=TStringList.Create;
  // Every key is stored and looked up already upper-cased (see the *Create
  // methods, Get and Activate), so IndexOf can use a plain ordinal compare
  // instead of the default locale-aware, case-insensitive one.
  Ctrls.CaseSensitive:=True;
  Ctrls.UseLocale:=False;
  Form:=TEuoMenuForm.Create(nil);
  Form.OnClose:=MyFormClose;
  BurstTimer:=TTimer.Create(nil);
  BurstTimer.Enabled:=False;
  BurstTimer.Interval:=BURST_QUIET_MS;
  BurstTimer.OnTimer:=BurstTimerFire;
  Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Free;
begin
  BurstTimer.Enabled:=False;
  BurstFlush;
  BurstTimer.Free;
  Clear;
  Ctrls.Free;
  Form.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
// Repaint coalescing. While a script streams MENU commands at an already
// visible window (typically CLEAR followed by a rebuild), painting is held off
// with WM_SETREDRAW so the user never sees a half-built frame, then released
// in one repaint once the commands go quiet (BURST_QUIET_MS after the last
// one) -- or after BURST_MAX_MS regardless, so a long-running build still
// shows progress. Everything here runs on the main thread (MenuProcSync).
// A window that is not shown yet is skipped: nothing is on screen to flicker.
// The hold goes on Form.Surface, never on the form: WM_SETREDRAW(False) works
// by clearing WS_VISIBLE, and a top-level window without it counts as hidden --
// its taskbar button blinked off and on with every burst, and clicks went
// through it to the window below (the UO client). A child window has no taskbar
// button, and a click on it while it is held lands on the form instead.
procedure TMenuObj.BurstBegin;
begin
  if not (Form.Visible and Form.Surface.HandleAllocated) then Exit;

  if not RedrawOff then
  begin
    SendMessage(Form.Surface.Handle,WM_SETREDRAW,0,0);
    RedrawOff:=True;
    BurstStart:=GetTickCount64;
  end
  else if GetTickCount64-BurstStart>BURST_MAX_MS then
  begin
    BurstFlush;
    Exit;
  end;

  // Restart the quiet-period timer.
  BurstTimer.Enabled:=False;
  BurstTimer.Enabled:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// For a command that changes one control in place: it extends a burst already
// running, so a rebuild that also sets values still repaints once, but does not
// start one -- there is no half-built frame to hide.
procedure TMenuObj.BurstJoin;
begin
  if RedrawOff then BurstBegin;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.BurstFlush;
begin
  BurstTimer.Enabled:=False;
  if not RedrawOff then Exit;
  RedrawOff:=False;
  if not Form.Surface.HandleAllocated then Exit;
  SendMessage(Form.Surface.Handle,WM_SETREDRAW,1,0);
  RedrawWindow(Form.Surface.Handle,nil,0,
    RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN or RDW_UPDATENOW);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.BurstTimerFire(Sender : TObject);
begin
  BurstFlush;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.AttachCtrl(C : TControl);
begin
  // Every *Create method fully configures its control while it is still
  // parent-less and only then calls this, so the one place the form can
  // react is here. Holding auto-sizing off around the insert makes the
  // form/children re-layout once when released rather than once per
  // intermediate step of the parenting.
  Form.DisableAutoSizing;
  try
    C.Parent:=Form.Surface;
  finally
    Form.EnableAutoSizing;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.Clear;
var
  Cnt : Integer;
begin
  // Same idea as AttachCtrl: free the whole set under one auto-size hold.
  Form.DisableAutoSizing;
  try
    for Cnt:=0 to Ctrls.Count-1 do
      Ctrls.Objects[Cnt].Free;
  finally
    Form.EnableAutoSizing;
  end;
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
  AttachCtrl(NewLabel);

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
  AttachCtrl(NewButton);
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
  AttachCtrl(NewEdit);

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
  AttachCtrl(NewMemo);

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
  AttachCtrl(NewCheck);

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
  AttachCtrl(NewCombo);

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
  AttachCtrl(NewList);

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

  AttachCtrl(NewShape);

  Ctrls.AddObject(UpperCase(sName),NewShape);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageCreate(sName : String; X,Y,W,H : Integer);
var
  NewImage : TImage;
begin
  NewImage:=NewMenuImage(W,H);   // EuoMenuCommon: 24 bpp, $FEEEED key
  NewImage.Left:=X;
  NewImage.Top:=Y;

  AttachCtrl(NewImage);
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
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
      MenuImageLine(TImage(Ctrls.Objects[Cnt]),X1,Y1,X2,Y2,C,W);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageEllipse(sName:String;X1,Y1,X2,Y2,C : Integer; Fill:Boolean; W:Integer=1);
var
  Cnt : Integer;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
      MenuImageEllipse(TImage(Ctrls.Objects[Cnt]),X1,Y1,X2,Y2,C,Fill,W);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageRectangle(sName:String;X1,Y1,X2,Y2,C : Integer; Fill:Boolean; W:Integer=1);
var
  Cnt : Integer;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
      MenuImageRectangle(TImage(Ctrls.Objects[Cnt]),X1,Y1,X2,Y2,C,Fill,W);
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
      MenuImagePix(TImage(Ctrls.Objects[Cnt]),X,Y,C);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImagePixLine(sName : String; X,Y : Integer; Data : String);
type
  TPixel = packed Array[0..2] of Byte;   // 24bpp -- see ImageCreate
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
    // (False, not True: "canvas only" updates are discarded when the canvas
    // already holds the bitmap -- always the case here, ImageCreate paints on it.)
    Bmp.BeginUpdate(False);
    try
      Pix:=Bmp.ScanLine[Y];
      for Cnt2:=X to X2 do
      begin
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

    InvalidateImageMask(Img);
    Img.Invalidate; // replaces the original's "read Canvas.Pixels[0,0] back
                     // to force a repaint" hack -- see the migration plan's
                     // stated guidance for this exact spot.
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageFloodFill(sName : String; X,Y,C : Integer);
var
  Cnt : Integer;
begin
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
      MenuImageFloodFill(TImage(Ctrls.Objects[Cnt]),X,Y,C);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.ImageFile(sName : String; X,Y : Integer; FN : String);
var
  Cnt : Integer;
begin
  if not FileExists(FN) then Exit;
  sName:=UpperCase(sName);
  for Cnt:=0 to Ctrls.Count-1 do
    if Ctrls[Cnt]=sName then
    if Ctrls.Objects[Cnt].ClassName='TImage' then
      MenuImageFile(TImage(Ctrls.Objects[Cnt]),X,Y,FN);
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

////////////////////////////////////////////////////////////////////////////////
procedure TMenuObj.MyFormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Application.Restore;
  MenuButton:='CLOSED';
  // CloseAction deliberately left untouched, exactly as the original left its
  // Action parameter untouched -- the default (caHide) is correct: the form
  // must survive being closed via its own [X] button, since TMenuObj.Free is
  // what actually destroys it, not the close action.
end;

end.
