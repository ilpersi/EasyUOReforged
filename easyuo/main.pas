unit main;

{
  Ported from the original Delphi 7 easyuo\main.pas + main.dfm (1314 lines).
  TMainForm hosts the multi-tab TSynEdit editor, macro recorder, find/replace,
  and live variable-inspector tree.

  The entire form is built via CODE here, not from an .lfm -- the original
  main.dfm embeds an Icon and an ImageList as Delphi-format binary property
  streams (TIcon/TBitmap), and Delphi's binary streaming format for those types
  does not reliably translate to LCL's own streaming format (a well-known DFM-
  to-LFM conversion snag; Lazarus's own IDE has a dedicated converter for
  exactly this reason, which isn't available in this non-interactive port).
  Rather than risk a subtly-broken hand-translated .lfm, every control here is
  constructed and wired in code -- this already matches the migration plan's
  explicit instruction for SynHilite specifically ("wire up TSynUniSyn in code
  ... rather than dropping it on the form at design time"), just extended
  consistently to the whole form. The toolbar/menu image list's actual icon
  bitmaps WERE initially skipped for exactly this reason (assumed "not
  reconstructable from the DFM's binary stream" -- a reasonable-sounding
  assumption that turned out to be wrong once actually checked), with
  ToolBar.ShowCaptions turned on as a stopgap so buttons weren't blank. Both
  the ImageList.Bitmap and Icon.Data streams turned out to use fully standard,
  well-documented formats underneath (a BMP color strip + a 1bpp AND-mask, and
  a plain .ico, respectively -- see mainicons.pas's header comment for the
  full extraction story), so the real icons are restored via that unit, and
  ShowCaptions is back to its original default (False -- the original DFM
  never sets it, so the icon-only look this restores IS the authentic one,
  not a new stylistic choice).

  Two modernizations applied per the migration plan's explicit instructions:
  - Drag-and-drop uses TCustomForm.AllowDropFiles/OnDropFiles (confirmed present
    in lcl\forms.pp) instead of the original's manual WM_DROPFILES message
    handler + DragQueryFile/DragAcceptFiles calls.
  - ShellExecute/ShowMessage usages are otherwise unchanged (already the
    "standardized" form per the plan -- only insthandler.pas's raw MessageBox
    calls needed converting to MessageDlg, which was done there).

  ShortCut integer literals (e.g. 16474 for Ctrl+Z) are copied verbatim from
  the original DFM rather than re-derived from symbolic key names -- LCL's
  TShortCut uses the identical bit-encoding VCL does (low byte = virtual key
  code, bit14 ($4000) = Ctrl, bit15 ($8000) = Alt), so a direct literal copy
  preserves the exact same key combination without this port re-deriving (and
  risking mis-deriving) the encoding itself.

  Toolbar buttons dispatch via their own Tag+OnClick directly to
  MenuHandlerProc (the same mechanism the menu items use) rather than via
  TToolButton.MenuItem's auto-forwarding (which does exist in LCL) -- avoids
  any risk of a click double-dispatching if MenuItem-forwarding and an
  explicit OnClick were both wired to the same Tag.
}

{$mode delphi}{$H+}

interface
uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Types,
     LCLType, Dialogs, Menus, ComCtrls, ExtCtrls, ToolWin, ImgList, StdCtrls,
     SynEdit, SynEditMiscClasses, SynEditSearch, SynEditTypes, SynCompletion,
     SynMacroRecorder, SynEditHighlighter, SynUniHighlighter, ShellApi,
     Registry, vartree, access, ReforgedVersion, insthandler, mainicons, eusyntax,
     eucomplete, EuoScriptStack, EuoCallStackFormat;

type
  TMainForm = class(TForm)
  private
    procedure WMDropFiles(Sender: TObject; const FileNames: array of string);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure TabCtrlChange(Sender: TObject);
    procedure TabCtrlContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure MenuHandlerProc(Sender: TObject);
    procedure UpdateTimerTimer(Sender: TObject);
    procedure ToolButtonReopen(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FindDiagFind(Sender: TObject);
    procedure ReplaceDiagReplace(Sender: TObject);
    procedure CompletionExecute(Sender: TObject);
    procedure CompletionCodeCompletion(var Value: String; SourceValue: String;
                var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char;
                Shift: TShiftState);
    procedure CallStackListBoxDblClick(Sender: TObject);
    procedure BuildComponents;
    function  AddMenu(Parent : TMenuItem; ATag : Integer; ACaption : String;
                AShortCut : TShortCut = 0) : TMenuItem;
    function  AddSep(Parent : TMenuItem) : TMenuItem;
    function  AddTool(AHint, ACaption : String; ATag : Integer) : TToolButton;
    procedure AddToolSep;
  public
    MainMenu          : TMainMenu;
    File1,Edit1,Control1,ools1,Help1  : TMenuItem;
    Exit1,New1,Open1,Reopen1,Save1,SaveAs1,SaveAll1,Close1,CloseAll1 : TMenuItem;
    Cut1,Copy1,Paste1,Delete1,SelectAll1,Find1,Replace1,Undo1,Redo1 : TMenuItem;
    Start1,Pause1,Stop1,StopAll1,StepOver1,StepInto1,StepOut1 : TMenuItem;
    ToggleBreakpoint1,RunToCursor1,BreakpointCondition1,ClearBreakpoints1 : TMenuItem;
    CallStackPanel1 : TMenuItem;
    NewClient1,SwapToNextClient1,VarDump1,UserVars1,DontMoveCursor1 : TMenuItem;
    Help2,GoToWebsite1,About1 : TMenuItem;
    Undo2,Redo2,Cut2,Copy2,Paste2,Delete2,SelectAll2,Close2,CloseAll2 : TMenuItem;
    ToolBar           : TToolBar;
    ImageList         : TImageList;
    StatusBar         : TStatusBar;
    SynHilite         : TSynUniSyn;
    SynRec            : TSynMacroRecorder;
    Completion        : TSynCompletion;
    TabCtrl           : TTabControl;
    UpdateTimer       : TTimer;
    MidPanel          : TPanel;
    VarSplitter       : TSplitter;
    VarTreeView       : TTreeView;
    ClientPathDialog  : TOpenDialog;
    SynPopupMenu      : TPopupMenu;
    TabPopupMenu      : TPopupMenu;
    FindDiag          : TFindDialog;
    ReplaceDiag       : TReplaceDialog;
    ScrPanel          : TPanel;
    CallStackSplitter : TSplitter;
    CallStackListBox  : TListBox;
    ToolButton14, ToolButton15, ToolButton16, ToolButton24 : TToolButton;
    ToolButton4, ToolButton7, ToolButton8, ToolButton9      : TToolButton;
    constructor Create(AOwner : TComponent); override;
    procedure   FormCreate;
    procedure   FormDestroy(Sender: TObject);
    procedure   MenuHandler(Tag : Integer);
  end;

var
  MainForm   : TMainForm;
  IH         : TInstHandler;
  Reg        : TRegistry;
  UpdateCnt  : Cardinal = 0;

implementation
uses text;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TMainForm.Create(AOwner : TComponent);
var
  TempIcon : TIcon;
begin
  inherited CreateNew(AOwner);

  Left := 200;
  Top := 122;
  Width := 661;
  Height := 381;
  Caption := 'EasyUO Reforged ' + REFORGED_VERSION;
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQuery;

  TempIcon := LoadAppIcon; // see mainicons.pas -- the original window icon,
                            // restored from main.dfm's Icon.Data
  try
    Icon.Assign(TempIcon);
  finally
    TempIcon.Free;
  end;

  BuildComponents;

  AllowDropFiles := True;
  OnDropFiles := WMDropFiles;

  FormCreate;
end;

////////////////////////////////////////////////////////////////////////////////
function TMainForm.AddMenu(Parent : TMenuItem; ATag : Integer; ACaption : String;
  AShortCut : TShortCut) : TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := ACaption;
  Result.Tag := ATag;
  Result.ShortCut := AShortCut;
  Result.ImageIndex := TagToImageIndex(ATag);
  Result.OnClick := MenuHandlerProc;
  Parent.Add(Result);
end;

////////////////////////////////////////////////////////////////////////////////
function TMainForm.AddSep(Parent : TMenuItem) : TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := '-';
  Parent.Add(Result);
end;

////////////////////////////////////////////////////////////////////////////////
function TMainForm.AddTool(AHint, ACaption : String; ATag : Integer) : TToolButton;
begin
  Result := TToolButton.Create(Self);
  Result.Parent := ToolBar;
  Result.Hint := AHint;
  Result.Caption := ACaption;
  Result.ShowHint := True;
  Result.Tag := ATag;
  Result.ImageIndex := TagToImageIndex(ATag);
  Result.OnClick := MenuHandlerProc;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.AddToolSep;
var
  Sep : TToolButton;
begin
  Sep := TToolButton.Create(Self);
  Sep.Parent := ToolBar;
  Sep.Style := tbsSeparator;
  Sep.Width := 8;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.BuildComponents;
var
  MI        : TMenuItem;
  ReopenBtn : TToolButton;
begin
  ////////////////////////////////////////////////////////////////////////////
  MainMenu := TMainMenu.Create(Self);
  Menu := MainMenu;

  File1 := TMenuItem.Create(Self);
  File1.Caption := '&File';
  File1.Tag := 9;
  File1.OnClick := MenuHandlerProc;
  MainMenu.Items.Add(File1);
  New1     := AddMenu(File1, 1, '&New');
  Open1    := AddMenu(File1, 2, '&Open...');
  Reopen1  := TMenuItem.Create(Self);
  Reopen1.Caption := '&Reopen';
  File1.Add(Reopen1);
  AddSep(File1);
  Save1    := AddMenu(File1, 3, '&Save');
  SaveAs1  := AddMenu(File1, 4, 'Save &As...');
  SaveAll1 := AddMenu(File1, 5, 'Sa&ve All', 16467);
  Close1   := AddMenu(File1, 6, '&Close');
  CloseAll1:= AddMenu(File1, 7, 'Close A&ll');
  AddSep(File1);
  Exit1    := AddMenu(File1, 8, '&Exit');

  Edit1 := TMenuItem.Create(Self);
  Edit1.Caption := '&Edit';
  MainMenu.Items.Add(Edit1);
  Undo1      := AddMenu(Edit1, 20, '&Undo', 16474);
  Redo1      := AddMenu(Edit1, 21, 'R&edo');
  AddSep(Edit1);
  Cut1       := AddMenu(Edit1, 22, 'Cu&t', 16472);
  Copy1      := AddMenu(Edit1, 23, '&Copy', 16451);
  Paste1     := AddMenu(Edit1, 24, '&Paste', 16470);
  Delete1    := AddMenu(Edit1, 25, '&Delete');
  SelectAll1 := AddMenu(Edit1, 26, 'Select &All', 16449);
  AddSep(Edit1);
  Find1      := AddMenu(Edit1, 27, '&Find...', 16454);
  Replace1   := AddMenu(Edit1, 28, '&Replace...');

  Control1 := TMenuItem.Create(Self);
  Control1.Caption := '&Control';
  MainMenu.Items.Add(Control1);
  Start1    := AddMenu(Control1, 60, '&Start', 120);
  Pause1    := AddMenu(Control1, 61, '&Pause');
  Stop1     := AddMenu(Control1, 62, 'S&top');
  StopAll1  := AddMenu(Control1, 63, 'Stop &All');
  AddSep(Control1);
  StepOver1 := AddMenu(Control1, 64, 'Step &Over', 119);
  StepInto1 := AddMenu(Control1, 65, 'Step &Into', 118);
  StepOut1  := AddMenu(Control1, 66, 'Step O&ut', 117);
  AddSep(Control1);
  // New additions (not present in the original app): F4/F5 match classic
  // Delphi IDE debugging conventions (Toggle Breakpoint/Run to Cursor),
  // consistent with F6/F7/F8/F9 already following that same convention for
  // Step Out/Into/Over/Start above -- not an arbitrary new choice.
  ToggleBreakpoint1     := AddMenu(Control1, 200, 'Toggle &Breakpoint', 116);
  RunToCursor1          := AddMenu(Control1, 201, 'R&un to Cursor', 115);
  BreakpointCondition1  := AddMenu(Control1, 202, 'Breakpoint &Condition...');
  ClearBreakpoints1     := AddMenu(Control1, 203, 'C&lear All Breakpoints');
  AddSep(Control1);
  // New addition (not present in the original app): a live call-stack panel.
  // Tag continues the same "new debug features get tags far outside every
  // original range" convention as the breakpoint block above (200-203).
  CallStackPanel1 := AddMenu(Control1, 210, 'Show Call &Stack');

  ools1 := TMenuItem.Create(Self);
  ools1.Caption := '&Tools';
  MainMenu.Items.Add(ools1);
  NewClient1        := AddMenu(ools1, 81, '&New Client', 49230);
  SwapToNextClient1 := AddMenu(ools1, 82, '&Swap To Next Client', 49235);
  VarDump1          := AddMenu(ools1, 83, '&VarDump');
  UserVars1         := AddMenu(ools1, 85, '&Manage VarList');
  AddSep(ools1);
  DontMoveCursor1   := AddMenu(ools1, 84, '&Don''t Move Cursor');
  DontMoveCursor1.Checked := True;

  Help1 := TMenuItem.Create(Self);
  Help1.Caption := '&Help';
  MainMenu.Items.Add(Help1);
  Help2        := AddMenu(Help1, 100, '&Help...', 112);
  GoToWebsite1 := AddMenu(Help1, 101, '&Website...');
  AddSep(Help1);
  About1       := AddMenu(Help1, 102, '&About...');

  ////////////////////////////////////////////////////////////////////////////
  ImageList := TImageList.Create(Self);
  LoadToolbarIcons(ImageList); // see mainicons.pas -- real icons restored
                                // from the original DFM's binary streams

  ////////////////////////////////////////////////////////////////////////////
  ToolBar := TToolBar.Create(Self);
  ToolBar.Parent := Self;
  ToolBar.Align := alTop;
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 25;
  ToolBar.Flat := True;
  // ShowCaptions left at its default (False) -- matches the original DFM,
  // which never sets it; icon-only is the authentic look, now that
  // LoadToolbarIcons above gives every button a real icon to show instead.
  ToolBar.Images := ImageList;

  AddTool('New', '&New', 1);
  AddTool('Open', '&Open...', 2);
  ReopenBtn := AddTool('Reopen', '&Reopen', 9);
  ReopenBtn.OnMouseDown := ToolButtonReopen;
  AddToolSep;
  ToolButton4 := AddTool('Save', '&Save', 3);
  AddTool('Close', '&Close', 6);
  AddToolSep;
  ToolButton7 := AddTool('Cut', 'Cu&t', 22);
  ToolButton8 := AddTool('Copy', '&Copy', 23);
  ToolButton9 := AddTool('Paste', '&Paste', 24);
  AddToolSep;
  AddTool('Find', '&Find...', 27);
  AddTool('Replace', '&Replace...', 28);
  AddToolSep;
  ToolButton14 := AddTool('Start', '&Start', 60);
  ToolButton15 := AddTool('Pause', '&Pause', 61);
  ToolButton16 := AddTool('Stop', 'S&top', 62);
  AddTool('Stop All', 'Stop &All', 63);
  AddToolSep;
  AddTool('New Client', '&New Client', 81);
  ToolButton24 := AddTool('Swap To Next Client', '&Swap To Next Client', 82);
  AddToolSep;
  AddTool('Help', '&Help...', 100);
  AddTool('Go To Website', '&Website...', 101);

  ////////////////////////////////////////////////////////////////////////////
  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.Align := alBottom;
  with StatusBar.Panels do
  begin
    Add.Width := 70; Items[0].Alignment := taCenter;
    Add.Width := 70; Items[1].Alignment := taCenter;
    Add.Width := 40; Items[2].Alignment := taCenter;
    Add.Width := 70; Items[3].Alignment := taCenter;
    Add.Width := 40; Items[4].Alignment := taCenter;
    Add.Width := 50;
  end;

  ////////////////////////////////////////////////////////////////////////////
  TabPopupMenu := TPopupMenu.Create(Self);
  TabPopupMenu.Images := ImageList;
  Close2    := TMenuItem.Create(Self);
  Close2.Caption := '&Close';
  Close2.Tag := 6;
  Close2.OnClick := MenuHandlerProc;
  TabPopupMenu.Items.Add(Close2);
  CloseAll2 := TMenuItem.Create(Self);
  CloseAll2.Caption := 'Close &All';
  CloseAll2.Tag := 7;
  CloseAll2.OnClick := MenuHandlerProc;
  TabPopupMenu.Items.Add(CloseAll2);

  TabCtrl := TTabControl.Create(Self);
  TabCtrl.Parent := Self;
  TabCtrl.Align := alClient;
  TabCtrl.HotTrack := True;
  TabCtrl.PopupMenu := TabPopupMenu;
  TabCtrl.OnChange := TabCtrlChange;
  TabCtrl.OnContextPopup := TabCtrlContextPopup;

  MidPanel := TPanel.Create(Self);
  MidPanel.Parent := TabCtrl;
  MidPanel.Align := alClient;
  MidPanel.BevelOuter := bvNone;

  VarTreeView := TTreeView.Create(Self);
  VarTreeView.Parent := MidPanel;
  VarTreeView.Align := alRight;
  VarTreeView.Width := 217;
  VarTreeView.HideSelection := False;
  VarTreeView.Indent := 19;

  VarSplitter := TSplitter.Create(Self);
  VarSplitter.Parent := MidPanel;
  VarSplitter.Align := alRight;

  ScrPanel := TPanel.Create(Self);
  ScrPanel.Parent := MidPanel;
  ScrPanel.Align := alClient;
  ScrPanel.BevelOuter := bvNone;

  ////////////////////////////////////////////////////////////////////////////
  // New addition (not present in the original app): a live call-stack panel.
  // Parented to ScrPanel (not MidPanel) so it's automatically shared across
  // every tab's TSynEdit the same way ScrPanel itself already is (see
  // insthandler.pas's CreateSyn: every tab's editor gets
  // Parent:=MainForm.ScrPanel with Align:=alClient) -- an alBottom sibling
  // here shrinks whichever editor is currently visible with no per-tab
  // bookkeeping needed. Hidden by default (Visible:=False here, restored
  // from the registry in FormCreate) so this doesn't change any existing
  // user's screen layout unless they opt in via Control > Show Call Stack.
  CallStackListBox := TListBox.Create(Self);
  CallStackListBox.Parent := ScrPanel;
  CallStackListBox.Align := alBottom;
  CallStackListBox.Height := 90;
  CallStackListBox.Visible := False;
  CallStackListBox.OnDblClick := CallStackListBoxDblClick;

  CallStackSplitter := TSplitter.Create(Self);
  CallStackSplitter.Parent := ScrPanel;
  CallStackSplitter.Align := alBottom;
  CallStackSplitter.Visible := False;

  ////////////////////////////////////////////////////////////////////////////
  SynPopupMenu := TPopupMenu.Create(Self);
  SynPopupMenu.Images := ImageList;
  Undo2 := TMenuItem.Create(Self); Undo2.Caption:='&Undo'; Undo2.Tag:=20; Undo2.ShortCut:=16474; Undo2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(Undo2);
  Redo2 := TMenuItem.Create(Self); Redo2.Caption:='R&edo'; Redo2.Tag:=21; Redo2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(Redo2);
  MI := TMenuItem.Create(Self); MI.Caption:='-'; SynPopupMenu.Items.Add(MI);
  Cut2 := TMenuItem.Create(Self); Cut2.Caption:='Cu&t'; Cut2.Tag:=22; Cut2.ShortCut:=16472; Cut2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(Cut2);
  Copy2 := TMenuItem.Create(Self); Copy2.Caption:='&Copy'; Copy2.Tag:=23; Copy2.ShortCut:=16451; Copy2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(Copy2);
  Paste2 := TMenuItem.Create(Self); Paste2.Caption:='&Paste'; Paste2.Tag:=24; Paste2.ShortCut:=16470; Paste2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(Paste2);
  Delete2 := TMenuItem.Create(Self); Delete2.Caption:='&Delete'; Delete2.Tag:=25; Delete2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(Delete2);
  SelectAll2 := TMenuItem.Create(Self); SelectAll2.Caption:='Select &All'; SelectAll2.Tag:=26; SelectAll2.ShortCut:=16449; SelectAll2.OnClick:=MenuHandlerProc; SynPopupMenu.Items.Add(SelectAll2);

  ////////////////////////////////////////////////////////////////////////////
  SynHilite := TSynUniSyn.Create(Self);
  SynRec := TSynMacroRecorder.Create(Self);
  SynRec.RecordShortCut := 24658;
  SynRec.PlaybackShortCut := 24656;
  // No standalone TSynEditSearch here: this SynEdit version's SearchReplace is
  // self-contained (see insthandler.pas's CreateSyn comment).

  // New addition (not present in the original Delphi 7 app at all): script
  // keyword/#variable/user-variable autocomplete. TSynCompletion is a single
  // shared instance, same pattern as SynHilite/SynRec above -- each tab's
  // SynEdit is registered with it via AddEditor (see insthandler.pas's
  // CreateSyn), and it tracks which one currently has focus on its own
  // (TLazSynMultiEditPlugin, confirmed by reading syneditplugins.pas -- no
  // manual "switch active editor on tab change" wiring needed here). Default
  // trigger is Ctrl+Space, the component's own default, left unchanged since
  // this feature has no original behavior to match.
  Completion := TSynCompletion.Create(Self);
  Completion.OnExecute := CompletionExecute;
  Completion.OnCodeCompletion := CompletionCodeCompletion;

  UpdateTimer := TTimer.Create(Self);
  UpdateTimer.Enabled := False;
  UpdateTimer.Interval := 100;
  UpdateTimer.OnTimer := UpdateTimerTimer;

  ClientPathDialog := TOpenDialog.Create(Self);
  ClientPathDialog.DefaultExt := 'exe';
  ClientPathDialog.FileName := 'client.exe';
  ClientPathDialog.Filter := 'Client Executable (*.exe)|*.exe|All Files|*.*';
  ClientPathDialog.Options := [ofFileMustExist,ofEnableSizing];
  ClientPathDialog.Title := 'Please select client.exe in your UO folder';

  FindDiag := TFindDialog.Create(Self);
  FindDiag.OnFind := FindDiagFind;

  ReplaceDiag := TReplaceDialog.Create(Self);
  ReplaceDiag.OnFind := FindDiagFind;
  ReplaceDiag.OnReplace := ReplaceDiagReplace;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.FormCreate;
begin
  Reg:=TRegistry.Create;
  Reg.OpenKey('\Software\EasyUO',True);

  // New addition (not present in the original app): restore the call-stack
  // panel's shown/hidden state. TRegistry.ReadBool raises on a missing value
  // (confirmed directly against fcl-registry's source -- it does not
  // silently default), hence the ValueExists guard, matching vartree.pas's
  // own defensive pattern for the same reason.
  CallStackPanel1.Checked := Reg.ValueExists('CallStackVisible') and Reg.ReadBool('CallStackVisible');
  CallStackListBox.Visible := CallStackPanel1.Checked;
  CallStackSplitter.Visible := CallStackPanel1.Checked;

  // EUOSyn.hlr (copied verbatim from the original) can't be loaded directly:
  // it uses the original Delphi-era UniHighlighter's file schema (Keywords/
  // word/Set/Rule/Scheme/CopyRight tags, colors packed into one Attributes=
  // "R,G;Style" string), while this Lazarus-bundled SynUniHighlighter
  // recognizes a different, more minimal tag vocabulary (KW/W instead of
  // Keywords/word, colors as separate Fore/Back/Style child tags, no Set/
  // Rule/Scheme/CopyRight at all) -- loading the original file raises
  // immediately. Rather than convert the file to the new (thinly-documented)
  // schema, eusyntax.pas drives the same TSynRange/TSynSymbolGroup object
  // model the file loader itself uses internally, built directly in code
  // from EUOSyn.hlr's actual keyword/color/range data -- see that unit's own
  // header for the full story, including the two narrow, deliberate,
  // cosmetic-only gaps versus the original.
  BuildEUOHighlighter(SynHilite);

  IH:=TInstHandler.Create;                                 // Create instance handler
  VarTreeFormCreate;                                       // Initialize VarTree
  VarTreeLoad('');                                          //
  UpdateTimer.Enabled:=True;                                // Enable Updatetimer
  UpdateTimerTimer(nil);
  OnDestroy := FormDestroy;

  if ParamStr(1)<>'' then                                  // Check CmdLine
    if IH.Reopen(ParamStr(1)) then                          //
  begin                                                     //
    MainForm.WindowState:=wsMinimized;                      //
    MenuHandler(60);                                        //
  end;                                                      //

  Caption:='EasyUO Reforged '+REFORGED_VERSION;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.WMDropFiles(Sender: TObject; const FileNames: array of string);
begin
  if Length(FileNames)>0 then
    IH.Reopen(FileNames[0]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.FormDestroy(Sender: TObject);
begin
  VarTreeFormClose;                                        // Finalize VarTree
  IH.Free;                                                  // Free instance handler
  Reg.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=IH.CloseAll;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.TabCtrlChange(Sender: TObject);
begin
  IH.SwitchTo(TabCtrl.TabIndex);
  // New addition (not present in the original app): refresh the call-stack
  // panel (and everything else UpdateTimerTimer already updates) right away
  // rather than waiting up to 100ms -- CExec/CSyn just changed identity to
  // the newly-switched-to tab's own. Mirrors FormCreate's own immediate
  // UpdateTimerTimer(nil) call right after setup, for the same reason.
  UpdateTimerTimer(nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.TabCtrlContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
begin
  if MousePos.Y>20 then Handled:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.FindDiagFind(Sender: TObject);
var
  Diag : TFindDialog;
  Opt  : TSynSearchOptions;
begin
  Diag:=TFindDialog(Sender);

  Opt:=[];
  if not(frDown in Diag.Options) then
    Include(Opt,ssoBackwards);
  if frMatchCase in Diag.Options then
    Include(Opt,ssoMatchCase);
  if frWholeWord in Diag.Options then
    Include(Opt,ssoWholeWord);

  if CSyn.SearchReplace(Diag.FindText,'',Opt)=0 then
    ShowMessage('No matches found!');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.ReplaceDiagReplace(Sender: TObject);
var
  Opt : TSynSearchOptions;
begin
  Opt:=[ssoReplace,ssoSelectedOnly];
  if frMatchCase in ReplaceDiag.Options then
    Include(Opt,ssoMatchCase);
  if frWholeWord in ReplaceDiag.Options then
    Include(Opt,ssoWholeWord);

  if frReplaceAll in ReplaceDiag.Options then
  begin
    Include(Opt,ssoReplaceAll);
    Include(Opt,ssoPrompt);
  end;

  if CSyn.SearchReplace(ReplaceDiag.FindText,ReplaceDiag.ReplaceText,Opt)=0 then
    ShowMessage('No matches found!');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.CompletionExecute(Sender: TObject);
begin
  // See eucomplete.pas's header comment for what goes into this list and why
  // it's rebuilt fresh on every trigger rather than cached. CurrentEditor is
  // only exposed on TheForm, not on TSynCompletion itself (confirmed by
  // reading syncompletion.pas's class declarations, not assumed).
  BuildCompletionList(Completion.ItemList, TSynEdit(Completion.TheForm.CurrentEditor));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.CompletionCodeCompletion(var Value: String; SourceValue: String;
  var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
begin
  // Widens SourceStart left by one when accepting a #/%/*!-prefixed value
  // right after its own sigil -- otherwise the sigil ends up duplicated on
  // insertion. See eucomplete.pas's header comment for the full reasoning.
  AdjustCompletionSpan(TSynEdit(Completion.TheForm.CurrentEditor), Value, SourceStart);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.ToolButtonReopen(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  IH.BuildReopenMenu(Reopen1);
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.MenuHandlerProc(Sender: TObject);
begin
  MenuHandler(TComponent(Sender).Tag);                     // Forward proc
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.MenuHandler(Tag : Integer);
var
  Cnt  : Integer;
  sBuf : String;
begin
  case Tag of
    01 : IH.New;
    02 : IH.Open;
    03 : IH.Save;
    04 : IH.SaveAs;
    05 : IH.SaveAll;
    06 : IH.Close;
    07 : IH.CloseAll;
    08 : Close;
    09 : IH.BuildReopenMenu(Reopen1);
    20 : CSyn.Undo;
    21 : CSyn.Redo;
    22 : CSyn.CutToClipboard;
    23 : CSyn.CopyToClipboard;
    24 : CSyn.PasteFromClipboard;
    25 : CSyn.ClearSelection;
    26 : CSyn.SelectAll;
    27 : FindDiag.Execute;
    28 : ReplaceDiag.Execute;
    60 : begin
           if CExec.Parser.UOSel.Cnt<1 then
           begin
             ShowMessage('No supported UO client found!');
             Exit;
           end;
           MarkOK:=True;
           if CExec.State=STOP then CExec.LoadScript(CSyn.Text);
           CExec.State:=PLAY;
         end;
    61 : CExec.State:=PAUSE;
    62 : CExec.State:=STOP;
    63 : for Cnt:=0 to IH.Count-1 do
           IH.Exec[Cnt].State:=STOP;
    64 : begin
           MarkOK:=True;
           if CExec.State=STOP then CExec.LoadScript(CSyn.Text);
           CExec.State:=STEPOVER;
         end;
    65 : begin
           MarkOK:=True;
           if CExec.State=STOP then CExec.LoadScript(CSyn.Text);
           CExec.State:=STEPINTO;
         end;
    66 : begin
           MarkOK:=True;
           if CExec.State=STOP then CExec.LoadScript(CSyn.Text);
           CExec.State:=STEPOUT;
         end;
    81 : if not CExec.Parser.UOCmd.OpenClient(CExec.State=STOP) then
           if ClientPathDialog.Execute then
             ShellExecute(0,'open',PChar(ClientPathDialog.FileName),'','',SW_SHOW);
    82 : with CExec.Parser.UOSel do
           SelectClient(Nr+1);
    83 : begin
           TextForm.Caption:='VarDump';
           TextForm.TextMemo.Text:=CExec.GetVarDump;
           TextForm.ShowModal;
         end;
    84 : begin
           DontMoveCursor1.Checked:=not DontMoveCursor1.Checked;
           MCDefault:=not DontMoveCursor1.Checked;
         end;
    85 : begin
           TextForm.Caption:='Manage VarList';
           TextForm.TextMemo.Text:=Identifiers;
           if TextForm.ShowModal=mrOK then
           begin
             Identifiers:=TextForm.TextMemo.Text;
             VarTreeLoad(Identifiers);
           end;
         end;
   100 : ShellExecute(0,'open','http://wiki.easyuo.com','','',SW_SHOW);
   101 : ShellExecute(0,'open','http://www.easyuo.com','','',SW_SHOW);
   102 : ShowMessage('EasyUO Reforged '+REFORGED_VERSION+#13#10#13#10+
           'A community port of EasyUO (originally by Cheffe) to Lazarus/'+
           'Free Pascal.'+#13#10+
           'https://github.com/lpersichetti/EasyUOReforged');

    // New additions (not present in the original app): breakpoint debugging
    // support. Tags deliberately far outside every range the original ever
    // used (1-9, 20-28, 60-66, 81-85, 100-102), so there is no risk of ever
    // colliding with a real ported feature's Tag.
   200 : begin // Toggle Breakpoint
           CExec.ToggleBreakpoint(CSyn.CaretY);
           CSyn.InvalidateLine(CSyn.CaretY);
         end;
   201 : begin // Run to Cursor
           if CExec.Parser.UOSel.Cnt<1 then
           begin
             ShowMessage('No supported UO client found!');
             Exit;
           end;
           MarkOK:=True;
           if CExec.State=STOP then CExec.LoadScript(CSyn.Text);
           CExec.RunToLine(CSyn.CaretY);
         end;
   202 : begin // Breakpoint Condition...
           sBuf:=InputBox('Breakpoint Condition',
             'Condition for line '+IntToStr(CSyn.CaretY)+' (e.g. %i > 10 -- leave empty for an unconditional breakpoint):',
             CExec.BreakpointCondition(CSyn.CaretY));
           CExec.SetBreakpointCondition(CSyn.CaretY,sBuf);
           CSyn.InvalidateLine(CSyn.CaretY);
         end;
   203 : begin // Clear All Breakpoints
           CExec.ClearAllBreakpoints;
           CSyn.Invalidate;
         end;
   210 : begin // Toggle Call Stack panel
           CallStackPanel1.Checked := not CallStackPanel1.Checked;
           CallStackListBox.Visible := CallStackPanel1.Checked;
           CallStackSplitter.Visible := CallStackPanel1.Checked;
           Reg.WriteBool('CallStackVisible',CallStackPanel1.Checked);
         end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// LCL's SynEdit has no GotoLineAndCenter (VCL SynEdit had one); composed here
// from CaretY/TopLine/LinesInWindow, all of which do exist, to the same effect.
procedure GotoLineAndCenter(Editor : TSynEdit; Line : Integer);
begin
  Editor.CaretY := Line;
  Editor.TopLine := Line - Editor.LinesInWindow div 2;
end;

////////////////////////////////////////////////////////////////////////////////
// New addition (not present in the original app): navigate to a call-stack
// entry's line on double-click. Deliberately restricted to the INNERMOST
// call level's own entries (that level's GOSUB frames plus its own file
// frame) -- an outer, different-file frame's line number only makes sense
// against THAT frame's own script text (see EuoCallStackFormat.pas's header
// comment), which isn't necessarily open in any tab, so acting on it here
// would risk jumping to the wrong line in the wrong file. Outer entries
// remain visible in the list for context; they're just not click-navigable
// in this first cut.
procedure TMainForm.CallStackListBoxDblClick(Sender: TObject);
var
  Idx, InnermostCount : Integer;
  Line : PtrUInt;
begin
  Idx:=CallStackListBox.ItemIndex;
  if Idx<0 then Exit;

  InnermostCount:=CExec.Parser.ScrList.SubCount(Integer(CExec.Parser.ScrList.CallLevel))+1;
  if Idx>=InnermostCount then Exit; // outer, different-file frame -- see comment above

  Line:=PtrUInt(CallStackListBox.Items.Objects[Idx]);
  if (Line<1) or (Line>Cardinal(CSyn.Lines.Count)) then Exit;

  GotoLineAndCenter(CSyn,Line);
  CSyn.InvalidateLine(Line);
  CSyn.SetFocus;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.UpdateTimerTimer(Sender: TObject);
var
  PL,PAU,
  STO,STEPS,
  SEL        : Boolean;
  i1,i2      : Integer;
  Cnt        : Integer;
  Frames     : TStringList;
  ErrMsg     : String;
begin
  Inc(UpdateCnt);

  (***Update WndList***)
  for Cnt:=0 to IH.Count-1 do
    with IH.Exec[Cnt] do
  begin
    if Parser.UOSel.Nr=0 then State:=STOP;

    if (Parser.UOSel.Nr=0)and(Parser.UOSel.Cnt>0) then
      Parser.UOSel.SelectClient(1);

    // A command that raised an uncaught exception on this tab's background thread
    // (see EuoExecutor.pas's TExeThread.Execute) already forced State to STOP -- this
    // just surfaces what happened instead of leaving the tab looking like it silently
    // stopped for no reason. LastError MUST be cleared BEFORE ShowMessage, not after --
    // ShowMessage runs its own local modal message loop, which still pumps this same
    // ~100ms timer (Windows delivers WM_TIMER to any active message loop, not just the
    // outermost one), so a naive "show it, then clear it" ordering lets that re-entrant
    // tick see LastError still set and pop ANOTHER ShowMessage on top of the one still
    // open -- a real bug hit directly: an unbounded cascade of stacked dialogs that
    // eventually crashed the app. Clearing first (into a local copy) means a re-entrant
    // tick during the modal call sees an already-empty LastError and does nothing.
    if LastError<>'' then
    begin
      ErrMsg:=LastError;
      LastError:='';
      ShowMessage('Script tab '+IntToStr(Cnt+1)+' stopped: '+ErrMsg);
    end;
  end;

  {***Update VarList***}
  if UpdateCnt mod 2=0 then VarTreeRefresh;
  if UpdateCnt mod 10=0 then
    for Cnt:=0 to IH.Count-1 do
  begin
    IH.Exec[Cnt].GetVar('#jindex');
  end;

  (***Update Controller Toolbar/Menubar***)
  PL:=False;
  PAU:=False;
  STO:=False;
  STEPS:=False;
  case CExec.State of
    PLAY  : begin
              PL:=False;
              PAU:=True;
              STO:=True;
              STEPS:=True;
            end;
    PAUSE : begin
              PL:=True;
              PAU:=False;
              STO:=True;
              STEPS:=True;
            end;
    STOP  : begin
              PL:=True;
              PAU:=False;
              STO:=False;
              STEPS:=True;
            end;
    STEPOVER,
    STEPINTO,
    STEPOUT:begin
              PL:=False;
              PAU:=True;
              STO:=True;
              STEPS:=False;
            end;
  end;
  SEL:=True;
  if CSyn.Lines.Count<2 then
    if CSyn.Text='' then
  begin
    PL:=False;
    STEPS:=False;
    SEL:=False;
  end;
  Start1.Enabled:=PL;
  ToolButton14.Enabled:=PL;
  Pause1.Enabled:=PAU;
  ToolButton15.Enabled:=PAU;
  Stop1.Enabled:=STO;
  ToolButton16.Enabled:=STO;
  StepOver1.Enabled:=STEPS;
  StepInto1.Enabled:=STEPS;
  StepOut1.Enabled:=STEPS;

  (***Update Edit Toolbar/Menubar***)
  Undo1.Enabled:=CSyn.CanUndo;
  Redo1.Enabled:=CSyn.CanRedo;
  Cut1.Enabled:=Length(CSyn.SelText)>0; // SynEdit has no SelLength; equivalent to the original's intent
  ToolButton7.Enabled:=Cut1.Enabled;
  Copy1.Enabled:=Length(CSyn.SelText)>0;
  ToolButton8.Enabled:=Copy1.Enabled;
  Paste1.Enabled:=CSyn.CanPaste;
  ToolButton9.Enabled:=Paste1.Enabled;
  Delete1.Enabled:=Length(CSyn.SelText)>0;
  SelectAll1.Enabled:=SEL;
  Undo2.Enabled:=Undo1.Enabled;
  Redo2.Enabled:=Redo1.Enabled;
  Cut2.Enabled:=Cut1.Enabled;
  Copy2.Enabled:=Copy1.Enabled;
  Paste2.Enabled:=Paste1.Enabled;
  Delete2.Enabled:=Delete1.Enabled;
  SelectAll2.Enabled:=SelectAll1.Enabled;

  (***Update File Toolbar/Menubar***)
  Save1.Enabled:=CSyn.Modified;
  ToolButton4.Enabled:=Save1.Enabled;
  SaveAs1.Enabled:=CSyn.Modified;

  (***Update Tools Toolbar/Menubar***)
  SwapToNextClient1.Enabled:=CExec.Parser.UOSel.Cnt>1;
  ToolButton24.Enabled:=SwapToNextClient1.Enabled;

  (***Update Macro Recorder***)
  if SynRec.Editor<>CSyn then
  begin
    SynRec.Stop;
    SynRec.Editor:=CSyn;
  end;

  (***Update Editor Window***)
  CSyn.ReadOnly:=CExec.State<>STOP;

  (***Update LineMark in Pause Mode***)
  if (CExec.State=PAUSE) and MarkOK then
    if CExec.Paused then
  begin
    MarkOK:=False;
    CSyn.InvalidateLine(MarkLine);
    // BreakLine (new -- see EuoExecutor.pas) is >=0 specifically when this
    // pause was caused by a breakpoint, in which case CurLine still holds
    // the PREVIOUS line (the breakpointed line hasn't run yet, on purpose --
    // that's the whole point of pausing there); CurLine+1 is the right mark
    // for every other kind of pause (Step*), exactly as before.
    if CExec.BreakLine>=0 then MarkLine:=CExec.BreakLine
    else MarkLine:=CExec.CurLine+1;
    CSyn.InvalidateLine(MarkLine);
    GotoLineAndCenter(CSyn,MarkLine);
  end;
  if (CExec.State<>PAUSE) and (MarkLine>-1) then
  begin
    CSyn.InvalidateLine(MarkLine);
    MarkLine:=-1;
  end;

  (***Update Call Stack panel***)
  // New addition (not present in the original app). Gated on the panel
  // actually being visible, matching this codebase's general care about the
  // 100ms timer's cost (e.g. VarTreeRefresh's own UpdateCnt-based
  // throttling nearby). Refreshed on every tick while genuinely paused
  // (not just once via MarkOK, unlike the line-mark update above) -- the
  // list is small and the app is idle anyway while paused, so the extra
  // work is unmeasurable; simpler and more directly correct than trying to
  // detect "did the stack actually change" itself. Cleared (not left
  // stale) the moment the script leaves PAUSE.
  if CallStackListBox.Visible then
  begin
    if (CExec.State=PAUSE) and CExec.Paused then
    begin
      Frames:=FormatCallStack(CExec.Parser.ScrList,MarkLine);
      try
        CallStackListBox.Items.Assign(Frames);
      finally
        Frames.Free;
      end;
    end
    else if CallStackListBox.Items.Count>0 then
      CallStackListBox.Items.Clear;
  end;

  (***Update Statusbar***)
  StatusBar.Panels[0].Text:=IntToStr(CSyn.CaretY)+': '+IntToStr(CSyn.CaretX);

  i1:=StrToIntDef(CExec.GetVar('#charposx'),-1);
  i2:=StrToIntDef(CExec.GetVar('#charposy'),-1);
  StatusBar.Panels[1].Text:=IntToStr(i1)+'/'+IntToStr(i2);
  StatusBar.Panels[2].Text:=IntToStr(i1 mod 8)+','+IntToStr(i2 mod 8);
  StatusBar.Panels[3].Text:=CExec.GetVar('#cursorx')+'/'+CExec.GetVar('#cursory');
  StatusBar.Panels[4].Text:=IntToStr(CExec.Parser.UOSel.Nr)+'|'+IntToStr(CExec.Parser.UOSel.Cnt);
end;

////////////////////////////////////////////////////////////////////////////////
end.
