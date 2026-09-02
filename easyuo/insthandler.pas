unit insthandler;

{
  Ported from the original Delphi 7 easyuo\insthandler.pas. TInstHandler owns one
  TSynEdit + one TExecutor per open script tab.

  One modernization applied per the migration plan's explicit instruction:
  "Standardize dialogs: Dialogs.MessageDlg for anything needing a Yes/No/Cancel
  result (replacing raw MessageBox calls in insthandler.pas...)". Both raw
  MessageBox calls (in SynReplaceText and Close) are replaced with MessageDlg;
  the exact case-branch behavior (which result does what, including that Close's
  original only special-cased IDYES/IDCANCEL and let IDNO fall through to "close
  without saving") is preserved.

  Everything else -- SynList/ExecList bookkeeping, Reopen's MRU-list registry
  persistence, CreateSyn's exact TSynEdit.Options set -- is ported unchanged.
  `executor` is now `EuoExecutor` (this migration's port, same TExecutor/
  TExeThread class names, per the plan's parser\ naming convention).
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, Classes, Graphics, Controls, Dialogs, Menus, SynEdit,
     SynEditTypes, SynEditMarks, SynGutterBase, LazUTF8, LConvEncoding,
     EuoExecutor;

type
  TInstHandler  = class(TObject)
  private
    SynList     : TStringList;
    ExecList    : TList;
    NewCnt      : Integer;
    function    CreateSyn : TSynEdit;
    function    GetSyn(Ind : Integer) : TSynEdit;
    function    GetExec(Ind : Integer) : TExecutor;
    procedure   SynLineColors(S: TObject; Line: Integer; var Special: Boolean; var FG, BG: TColor);
    procedure   SynReplaceText(Sender: TObject; const ASearch, AReplace: String; Line, Column: Integer; var Action: TSynReplaceAction);
    procedure   SynGutterClick(Sender: TObject; X, Y, Line: Integer; Mark: TSynEditMark);
  public
    Cur         : Integer;
    constructor Create;
    procedure   Free;
    function    Count : Integer;
    procedure   SwitchTo(Ind : Integer);
    procedure   New;
    procedure   Open;
    function    Reopen(FN : String) : Boolean;
    procedure   BuildReopenMenu(Parent : TMenuItem);
    procedure   ReopenHandler(Sender : TObject);
    function    Save : Boolean;
    function    SaveAs : Boolean;
    procedure   SaveAll;
    function    Close : Boolean;
    function    CloseAll : Boolean;
    property    Syn[Ind : Integer] : TSynEdit read GetSyn;
    property    Exec[Ind : Integer] : TExecutor read GetExec;
  end;

  function CSyn  : TSynEdit;
  function CFN   : String;
  function CExec : TExecutor;

const
  STOP     = 0;
  PLAY     = 1;
  PAUSE    = 2;
  STEPINTO = 3;
  STEPOVER = 4;
  STEPOUT  = 5;

var
  MarkOK     : Boolean = False;
  MarkLine   : Integer = -1;
  ReopenList : TStringList;

implementation
uses main;

const ReopenNr = 8;

////////////////////////////////////////////////////////////////////////////////
// Added during this migration -- not needed by the original VCL/Delphi 7 app,
// which read script files as raw ANSI bytes throughout (matching how they
// were almost certainly authored: this tool predates UTF-8 becoming the
// default save encoding in most text editors). LCL's SynEdit renders text as
// Unicode and expects well-formed UTF-8 from Lines; a script file containing
// a raw high-byte ANSI/CP1252 character (e.g. one selecting a Wingdings icon
// glyph by character code -- confirmed live: the character a real script
// used was byte $D1, not valid UTF-8 on its own) never displays at all,
// because that lone invalid byte doesn't form a valid UTF-8 character for
// SynEdit's Unicode-aware paint/character-boundary logic to render.
//
// Reads the file's raw bytes and only converts them (CP1252->UTF-8) if
// they're NOT already valid UTF-8, so an already-UTF-8 script (or a plain
// old all-ASCII one, valid UTF-8 by definition) passes through completely
// unchanged. This keeps SynEdit.Lines always holding well-formed UTF-8,
// letting it render any character in the source correctly regardless of
// which encoding the file was actually saved in.
function LoadScriptFileAsUTF8(const FN : String) : String;
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result,FS.Size);
    if FS.Size>0 then
      FS.ReadBuffer(Result[1],FS.Size);
  finally
    FS.Free;
  end;

  if FindInvalidUTF8Codepoint(PChar(Result),Length(Result))>=0 then
    Result:=CP1252ToUTF8(Result);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TInstHandler.Create;
begin
  SynList:=TStringList.Create;
  ExecList:=TList.Create;
  ReopenList:=TStringList.Create;
  Cur:=-1;
  NewCnt:=0;
  New;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.Free;
var
  Cnt : Integer;
begin
  ReopenList.Free;
  for Cnt:=0 to ExecList.Count-1 do
  begin
    Exec[Cnt].Free;
    Syn[Cnt].Free;
  end;
  ExecList.Free;
  SynList.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.SynLineColors(S: TObject; Line: Integer; var Special: Boolean; var FG, BG: TColor);
var
  Ind : Integer;
begin
  if (MarkLine>=0) and (Line=MarkLine) then
  begin
    // Current execution line (Step*/breakpoint pause) always wins over a
    // breakpoint-line color on the same line -- otherwise a breakpoint you
    // just stopped AT would show its own "has a breakpoint" color instead
    // of the more useful "execution is paused here" one.
    Special:=True;
    FG:=clWindow;
    BG:=clNavy;
    Exit;
  end;

  // New addition (not present in the original app): breakpoints. S is
  // whichever tab's TSynEdit is asking -- find its matching TExecutor via
  // the same SynList/ExecList index pairing GetSyn/GetExec already use.
  Ind:=SynList.IndexOfObject(TObject(S));
  if (Ind>=0) and Exec[Ind].HasBreakpoint(Line) then
  begin
    Special:=True;
    FG:=clWindow;
    BG:=$00A0A0FF; // light red/pink -- distinct from the navy current-line color
    Exit;
  end;

  Special:=False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.SynReplaceText(Sender: TObject; const ASearch, AReplace: String; Line, Column: Integer; var Action: TSynReplaceAction);
begin
  case MessageDlg('Replace this match?', mtConfirmation, [mbYes,mbNo,mbCancel], 0) of
    mrYes : Action:=raReplace;
    mrNo  : Action:=raSkip;
    else    Action:=raCancel;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// New addition (not present in the original app): click the gutter to
// toggle a plain breakpoint on that line. Conditional breakpoints and Run
// to Cursor are on the editor's right-click menu instead (see main.pas) --
// this is deliberately a single, low-friction action for the common case.
procedure TInstHandler.SynGutterClick(Sender: TObject; X, Y, Line: Integer; Mark: TSynEditMark);
var
  Ed  : TObject;
  Ind : Integer;
begin
  // Line<1 is a real, separate call path (TSynGutterPartBase's own generic
  // click handling, confirmed by reading syngutterbase.pp/syngutter.pp
  // directly) that never carries a real line number -- only TSynGutter's
  // own click path (Sender here) does, so this also happens to sidestep
  // needing to know that other Sender's exact type at all.
  if Line<1 then Exit;
  if not (Sender is TSynGutterBase) then Exit;
  Ed:=TObject(TSynGutterBase(Sender).SynEdit);

  Ind:=SynList.IndexOfObject(Ed);
  if Ind<0 then Exit;
  Exec[Ind].ToggleBreakpoint(Line);
  TSynEdit(Ed).InvalidateLine(Line);
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.CreateSyn : TSynEdit;
begin
  Result:=TSynEdit.Create(nil);
  // TCustomSynEdit.Create only calls SetDefaultKeystrokes when it has a
  // non-nil Owner (see synedit.pp: "if assigned(Owner) and not
  // (csLoading in Owner.ComponentState) then SetDefaultKeystrokes"). This
  // editor is deliberately created with Owner=nil -- its lifetime is managed
  // manually via SynList/TInstHandler.Free, not by an owner's auto-free --
  // so without this explicit call it has NO key bindings at all: no
  // Backspace/Delete, no Home/End, nothing. Confirmed by reading the
  // component source, not guessed.
  Result.SetDefaultKeystrokes;
  Result.Visible:=False;
  Result.Align:=alClient;
  Result.WantTabs:=True;
  Result.TabWidth:=2;
  Result.RightEdge:=-1;

  Result.ParentColor:=False;
  Result.Color:=clWindow;

  // Was False (matching the original, which never showed a gutter at all)
  // until this migration added breakpoints: click-to-toggle needs a real,
  // clickable gutter area, and line numbers are genuinely useful for
  // debugging too (correlating with GOTO targets, error messages, etc.),
  // so this is a deliberate, visible UI change, not an accidental one.
  Result.Gutter.Visible:=True;
  Result.OnGutterClick:=SynGutterClick;

  Result.Options:=[eoAltSetsColumnMode,eoAutoIndent,eoGroupUndo,
    eoScrollByOneLess,eoScrollPastEol,eoShowScrollHint,eoSmartTabDelete,
    eoSmartTabs,eoTabIndent,eoTabsToSpaces,eoTrimTrailingSpaces];

  // No SearchEngine property to assign here: this SynEdit version's
  // SearchReplace is self-contained (no external TSynEditSearch dependency,
  // unlike the original VCL SynEdit) -- confirmed via source, not guessed.
  Result.OnReplaceText:=SynReplaceText;
  Result.Highlighter:=MainForm.SynHilite;
  Result.OnSpecialLineColors:=SynLineColors;
  Result.PopupMenu:=MainForm.SynPopupMenu;

  // Registers this editor with the shared autocomplete component (see
  // main.pas's BuildComponents) -- it tracks which registered editor
  // currently has focus on its own (TLazSynMultiEditPlugin), so this is the
  // only wiring a new tab's editor needs for Ctrl+Space completion to work.
  MainForm.Completion.AddEditor(Result);

  Result.Parent:=MainForm.ScrPanel;
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.GetSyn(Ind : Integer) : TSynEdit;
begin
  Result:=TSynEdit(SynList.Objects[Ind]);
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.GetExec(Ind : Integer) : TExecutor;
begin
  Result:=ExecList[Ind];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.SwitchTo(Ind : Integer);
begin
  Syn[Ind].Visible:=True;
  if (Cur>-1)and(Cur<>Ind) then
    Syn[Cur].Visible:=False;

  MainForm.TabCtrl.TabIndex:=Ind;
  Cur:=Ind;

  if MainForm.Visible then
    MainForm.ActiveControl:=Syn[Ind];
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.Count : Integer;
begin
  Result:=ExecList.Count;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.New;
var
  ExecObj : TExecutor;
begin
  SynList.AddObject('',CreateSyn);

  ExecObj:=TExecutor.Create(MainForm.Handle);
  ExecList.Add(ExecObj);

  Inc(NewCnt);
  MainForm.TabCtrl.Tabs.Add('new'+IntToStr(NewCnt));
  SwitchTo(Count-1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.Open;
var
  OpenDiag : TOpenDialog;
  FN       : String;
begin
  OpenDiag:=TOpenDialog.Create(MainForm);
  OpenDiag.DefaultExt:='txt';
  OpenDiag.Filter:='Scripts (*.txt; *.euo)|*.txt; *.euo|All Files (*.*)|*.*';
  OpenDiag.Options:=[ofFileMustExist,ofEnableSizing];
  OpenDiag.Title:='Open Script';
  FN:='';
  if OpenDiag.Execute then FN:=OpenDiag.FileName;
  OpenDiag.Free;
  if FN='' then Exit;

  Reopen(FN);
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.Reopen(FN : String) : Boolean;
var
  SynEdit : TSynEdit;
  ExecObj : TExecutor;
  Cnt     : Integer;
begin
  Result:=False;
  if not FileExists(FN) then Exit;
  Result:=True;

  SynEdit:=CreateSyn;
  SynEdit.Lines.Text:=LoadScriptFileAsUTF8(FN);
  SynList.AddObject(FN,SynEdit);

  ExecObj:=TExecutor.Create(MainForm.Handle);
  ExecList.Add(ExecObj);

  MainForm.TabCtrl.Tabs.Add(ExtractFileName(FN));
  SwitchTo(Count-1);

  if (Count<3)and(SynList[0]='')and not Syn[0].Modified then
  begin
    Cur:=0;
    Close;
  end;

  ReopenList.Text:=Reg.ReadString('Reopen');
  Cnt:=ReopenList.IndexOf(FN);
  if Cnt>=0 then
    ReopenList.Delete(Cnt);
  ReopenList.Insert(0,FN);
  while ReopenList.Count>ReopenNr do
    ReopenList.Delete(ReopenNr);
  Reg.WriteString('Reopen',ReopenList.Text);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.BuildReopenMenu(Parent : TMenuItem);
var
  Cnt : Integer;
  MI  : TMenuItem;
begin
  while Parent.Count>0 do
    Parent.Items[0].Free;
  ReopenList.Text:=Reg.ReadString('Reopen');
  for Cnt:=0 to ReopenList.Count-1 do
  begin
    MI:=TMenuItem.Create(Parent);
    MI.OnClick:=ReopenHandler;
    MI.Caption:='&'+IntToStr(Cnt+1)+' '+ReopenList[Cnt];
    MI.Tag:=73590+Cnt;
    Parent.Add(MI);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.ReopenHandler(Sender : TObject);
begin
  IH.Reopen(ReopenList[TMenuItem(Sender).Tag-73590]);
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.Save : Boolean;
begin
  if SynList[Cur]='' then
  begin
    Result:=SaveAs;
    Exit;
  end;
  Syn[Cur].Lines.SaveToFile(SynList[Cur]);
  Syn[Cur].Modified:=False;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.SaveAs : Boolean;
var
  SaveDiag : TSaveDialog;
  FN       : String;
begin
  SaveDiag:=TSaveDialog.Create(MainForm);
  SaveDiag.DefaultExt:='txt';
  SaveDiag.Filter:='Scripts (*.txt)|*.txt;*.euo|All Files (*.*)|*.*';
  SaveDiag.Options:=[ofPathMustExist,ofEnableSizing];
  SaveDiag.Title:='Save '+MainForm.TabCtrl.Tabs[Cur]+' As';
  FN:='';
  if SaveDiag.Execute then FN:=SaveDiag.FileName;
  SaveDiag.Free;

  Result:=FN<>'';
  if FN='' then Exit;

  Syn[Cur].Lines.SaveToFile(FN);
  Syn[Cur].Modified:=False;
  SynList[Cur]:=FN;
  MainForm.TabCtrl.Tabs[Cur]:=ExtractFileName(FN);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TInstHandler.SaveAll;
var
  Cnt     : Integer;
begin
  for Cnt:=Count-1 downto 0 do
  begin
    Cur:=Cnt;
    if not CSyn.Modified then Continue;
    if not Save then Break;
  end;
  Cur:=MainForm.TabCtrl.TabIndex;
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.Close : Boolean;
var
  OldCur : Integer;
begin
  Result:=False;
  if Syn[Cur].Modified then
  case MessageDlg('Save changes to '+MainForm.TabCtrl.Tabs[Cur]+'?',
    mtConfirmation, [mbYes,mbNo,mbCancel], 0) of
    mrYes : if not Save then Exit;
    mrCancel : Exit;
  end;
  Result:=True;

  if Cur=MainForm.TabCtrl.TabIndex then
  begin
    OldCur:=Cur;
    if Cur>0 then SwitchTo(Cur-1)
    else if Count<2 then New
    else SwitchTo(1);
    Cur:=OldCur;
  end;

  Exec[Cur].Free;
  ExecList.Delete(Cur);
  Syn[Cur].Free;
  SynList.Delete(Cur);
  MainForm.TabCtrl.Tabs.Delete(Cur);

  Cur:=MainForm.TabCtrl.TabIndex;
end;

////////////////////////////////////////////////////////////////////////////////
function TInstHandler.CloseAll : Boolean;
var
  Cnt     : Integer;
begin
  // Fixed: the original computed Result as "Cnt<0" after the loop, relying on
  // the for-downto loop variable landing on -1 once it runs to completion
  // without a Break. Confirmed via a standalone test: FPC leaves Cnt at 0 (the
  // last in-range value), not -1, after a normal (non-Break) exit from
  // "for Cnt:=N downto 0 do" -- a genuine Delphi/FPC codegen difference, not a
  // logic bug in the original. Under FPC this made CloseAll always return
  // False even when every tab closed successfully, which made
  // FormCloseQuery's CanClose always False -- the window could never close.
  // Rewritten with an explicit flag expressing the same intent ("were all
  // tabs closed without the user cancelling") without depending on loop-
  // variable-after-completion behavior at all.
  Result:=True;
  for Cnt:=Count-1 downto 0 do
  begin
    Cur:=Cnt;
    if not Close then
    begin
      Result:=False;
      Break;
    end;
  end;
  Cur:=MainForm.TabCtrl.TabIndex;
end;

////////////////////////////////////////////////////////////////////////////////
function CSyn : TSynEdit;
begin
  Result:=IH.Syn[IH.Cur];
end;

////////////////////////////////////////////////////////////////////////////////
function CFN : String;
begin
  Result:=IH.SynList[IH.Cur];
end;

////////////////////////////////////////////////////////////////////////////////
function CExec : TExecutor;
begin
  Result:=IH.Exec[IH.Cur];
end;

////////////////////////////////////////////////////////////////////////////////
end.
