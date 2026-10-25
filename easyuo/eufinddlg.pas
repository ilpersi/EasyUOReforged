unit eufinddlg;

{
  New addition (not present in the original app): the editor's Find/Replace
  window. It replaces the LCL TFindDialog/TReplaceDialog pair the port first
  used (and the native Windows dialogs the original used before that): one
  window for both, built in code like the rest of the GUI (see main.pas's
  header comment). The searching itself is in eufind.pas.

  - Edit > Find (Ctrl+F) and Edit > Replace (Ctrl+H) open it with the
    selection or the word at the caret filled in (a # % ! * sigil in front
    of the word included); a selection over several lines switches the scope
    to Selection instead. F3 / Shift+F3 search again in / against the chosen
    direction, in the window and in the editor (main.pas's Find Next / Find
    Previous); Enter / Shift+Enter do the same in the window, Esc closes it.
  - While it is open, every match in the current script is highlighted
    (eufind.pas's SetFindHighlight -- not TSynEdit.SetHighlightSearch, which
    hangs on a regex like ^, see there) and the status line counts them
    ("3 of 12 matches"). Poll,
    called from main.pas's 100ms UpdateTimerTimer, redoes both when the
    tab, the text or the selection changed, so a tab switch or an edit
    never leaves them stale.
  - Find and Replace history (MaxHistory each) and the check boxes are kept
    in the registry next to the other settings (FindHistory, ReplaceHistory,
    FindOptions). Scope and direction start as Current script / Down.
  - A running script's editor is read-only (main.pas's UpdateTimerTimer):
    Replace leaves it alone and says so, Replace All skips it.
}

{$mode delphi}{$H+}

interface
uses SysUtils, Classes, Types, Controls, Forms, StdCtrls, ExtCtrls,
     LCLType, Registry, SynEdit, eufind;

type
  TEuoFindDialog = class(TForm)
  private
    FindLabel, ReplaceLabel, StatusLabel : TLabel;
    FindBox, ReplaceBox                  : TComboBox;
    FindBtn, ReplaceBtn, ReplaceAllBtn, CloseBtn : TButton;
    MatchCaseBox, WholeWordBox, RegExprBox, WrapBox, PromptBox : TCheckBox;
    ScopeGroup, DirGroup                 : TRadioGroup;
    FState       : TFindState;
    FHighlighted : TSynEdit;   // the editor whose matches are highlighted, if any
    FUpdating    : Boolean;    // filling in controls: no Refresh from their OnChange
    FPlaced      : Boolean;
    FSignature   : String;     // what Refresh last counted in, see Poll
    function  NewLabel(ACaption : String; X, Y : Integer) : TLabel;
    function  NewBox(X, Y, W : Integer) : TComboBox;
    function  NewButton(ACaption : String; X, Y : Integer; AOnClick : TNotifyEvent) : TButton;
    function  NewCheck(ACaption : String; X, Y : Integer) : TCheckBox;
    function  NewGroup(ACaption : String; X, Y, W : Integer; const AItems : array of String) : TRadioGroup;
    function  Settings : TFindSettings;
    function  Signature : String;
    function  IsEditor(Ed : TSynEdit) : Boolean;
    function  Ready(const S : TFindSettings) : Boolean;
    procedure SetHighlight(Ed : TSynEdit; const S : TFindSettings);
    procedure Refresh(const Note : String = ''; NoteOnly : Boolean = False);
    procedure Remember(const S : TFindSettings; WithReplace : Boolean);
    function  DoFind(Backwards : Boolean) : Boolean;
    procedure Prefill;
    procedure Open(FocusReplace : Boolean);
    procedure OptionChange(Sender : TObject);
    procedure FindClick(Sender : TObject);
    procedure ReplaceClick(Sender : TObject);
    procedure ReplaceAllClick(Sender : TObject);
    procedure CloseClick(Sender : TObject);
    procedure DialogKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
    procedure DialogClose(Sender : TObject; var CloseAction : TCloseAction);
  public
    constructor Create(AOwner : TComponent); override;
    procedure ShowFind;
    procedure ShowReplace;
    procedure FindAgain(Reverse : Boolean);
    procedure Poll;
    procedure LoadSettings(Reg : TRegistry);
    procedure SaveSettings(Reg : TRegistry);
  end;

implementation
uses RegExpr, SynEditTypes, main, insthandler;

type
  TSynEditArray = array of TSynEdit;

const
  RunningMsg = 'A running script can''t be changed';

////////////////////////////////////////////////////////////////////////////////
function Plural(N : Integer; const One, Many : String) : String;
begin
  if N=1 then Result:=One else Result:=Many;
end;

////////////////////////////////////////////////////////////////////////////////
function Editors : TSynEditArray;
var
  i : Integer;
begin
  SetLength(Result,IH.Count);
  for i:=0 to IH.Count-1 do
    Result[i]:=IH.Syn[i];
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// Laid out in 96 DPI pixels, scaled to the screen's like the fonts are.
constructor TEuoFindDialog.Create(AOwner : TComponent);
begin
  inherited CreateNew(AOwner);
  FUpdating:=True;   // no Refresh from the OnChange of half-built controls
  Caption:='Find and Replace';
  BorderStyle:=bsDialog;
  BorderIcons:=[biSystemMenu];
  ShowInTaskBar:=stNever;
  PopupMode:=pmExplicit;
  PopupParent:=MainForm;   // stays above the editor without being topmost everywhere
  KeyPreview:=True;
  OnKeyDown:=DialogKeyDown;
  OnClose:=DialogClose;
  ClientWidth:=Scale96ToForm(440);
  ClientHeight:=Scale96ToForm(272);

  FindLabel:=NewLabel('&Find:',8,12);
  ReplaceLabel:=NewLabel('Re&place:',8,42);
  FindBox:=NewBox(70,8,254);
  ReplaceBox:=NewBox(70,38,254);
  FindLabel.FocusControl:=FindBox;
  ReplaceLabel.FocusControl:=ReplaceBox;

  FindBtn:=NewButton('Find &Next',334,7,FindClick);
  ReplaceBtn:=NewButton('R&eplace',334,37,ReplaceClick);
  ReplaceAllBtn:=NewButton('Replace &All',334,67,ReplaceAllClick);

  MatchCaseBox:=NewCheck('Match &case',8,72);
  WholeWordBox:=NewCheck('&Whole word',8,94);
  RegExprBox:=NewCheck('Re&gular expression',8,116);
  WrapBox:=NewCheck('W&rap around',170,72);
  PromptBox:=NewCheck('Pr&ompt on replace',170,94);
  WrapBox.Checked:=True;

  ScopeGroup:=NewGroup('Scope',8,142,424,['Current &script','Se&lection','All open scrip&ts']);
  DirGroup:=NewGroup('Direction',8,190,180,['&Down','&Up']);

  StatusLabel:=NewLabel('',8,244);
  StatusLabel.AutoSize:=False;
  StatusLabel.Width:=Scale96ToForm(318);
  StatusLabel.ShowAccelChar:=False;
  StatusLabel.ShowHint:=True;   // the full text of a long regex error
  CloseBtn:=NewButton('Close',334,240,CloseClick);

  ClearState(FState);
  FUpdating:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.NewLabel(ACaption : String; X, Y : Integer) : TLabel;
begin
  Result:=TLabel.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.Left:=Scale96ToForm(X);
  Result.Top:=Scale96ToForm(Y);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.NewBox(X, Y, W : Integer) : TComboBox;
begin
  Result:=TComboBox.Create(Self);
  Result.Parent:=Self;
  Result.Style:=csDropDown;
  Result.DropDownCount:=MaxHistory;
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(W),Result.Height);
  Result.OnChange:=OptionChange;
  Result.OnSelect:=OptionChange;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.NewButton(ACaption : String; X, Y : Integer; AOnClick : TNotifyEvent) : TButton;
begin
  Result:=TButton.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(98),Scale96ToForm(25));
  Result.OnClick:=AOnClick;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.NewCheck(ACaption : String; X, Y : Integer) : TCheckBox;
begin
  Result:=TCheckBox.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.Left:=Scale96ToForm(X);
  Result.Top:=Scale96ToForm(Y);
  Result.OnChange:=OptionChange;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.NewGroup(ACaption : String; X, Y, W : Integer;
  const AItems : array of String) : TRadioGroup;
var
  i : Integer;
begin
  Result:=TRadioGroup.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(W),Scale96ToForm(44));
  Result.Columns:=Length(AItems);
  for i:=0 to High(AItems) do
    Result.Items.Add(AItems[i]);
  Result.ItemIndex:=0;
  Result.OnClick:=OptionChange;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function TEuoFindDialog.Settings : TFindSettings;
begin
  Result:=Default(TFindSettings);
  Result.FindText:=FindBox.Text;
  Result.ReplaceText:=ReplaceBox.Text;
  Result.MatchCase:=MatchCaseBox.Checked;
  Result.WholeWord:=WholeWordBox.Checked;
  Result.RegExpr:=RegExprBox.Checked;
  Result.WrapAround:=WrapBox.Checked;
  Result.PromptOnReplace:=PromptBox.Checked;
  Result.Backwards:=DirGroup.ItemIndex=1;
  Result.Scope:=TFindScope(ScopeGroup.ItemIndex);
end;

////////////////////////////////////////////////////////////////////////////////
// Everything the count and the highlight depend on, besides the controls.
function TEuoFindDialog.Signature : String;
var
  i     : Integer;
  Stamp : Int64;
begin
  Stamp:=0;
  for i:=0 to IH.Count-1 do
    Inc(Stamp,IH.Syn[i].ChangeStamp);
  Result:=Format('%p|%d|%d|%d,%d|%d,%d',[Pointer(CSyn),IH.Count,Stamp,
            CSyn.BlockBegin.X,CSyn.BlockBegin.Y,CSyn.BlockEnd.X,CSyn.BlockEnd.Y]);
end;

////////////////////////////////////////////////////////////////////////////////
// FHighlighted may be a closed tab's editor by now.
function TEuoFindDialog.IsEditor(Ed : TSynEdit) : Boolean;
var
  i : Integer;
begin
  Result:=False;
  for i:=0 to IH.Count-1 do
    if IH.Syn[i]=Ed then Exit(True);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.Ready(const S : TFindSettings) : Boolean;
var
  Msg : String;
begin
  Result:=(S.FindText<>'') and CheckPattern(S,Msg);
  if not Result then Refresh;
end;

////////////////////////////////////////////////////////////////////////////////
// Only while the window is open, and never with a bad regex: the highlight
// runs its own search on every paint.
procedure TEuoFindDialog.SetHighlight(Ed : TSynEdit; const S : TFindSettings);
begin
  if (FHighlighted<>nil) and (FHighlighted<>Ed) and IsEditor(FHighlighted) then
    SetFindHighlight(FHighlighted,'',[]);
  FHighlighted:=Ed;
  if Ed=nil then Exit;
  if Visible and (S.FindText<>'') then
    SetFindHighlight(Ed,S.FindText,SynOptions(S)-[ssoBackwards])
  else
    SetFindHighlight(Ed,'',[]);
end;

////////////////////////////////////////////////////////////////////////////////
// Highlight and count for the current controls; Note is added after the
// count ("3 of 12 matches, wrapped to the top"), or stands alone.
procedure TEuoFindDialog.Refresh(const Note : String; NoteOnly : Boolean);
var
  S        : TFindSettings;
  Msg, Txt : String;
  N, Idx   : Integer;
  Counted  : Boolean;
begin
  S:=Settings;
  if not CheckPattern(S,Msg) then
  begin
    SetHighlight(nil,S);
    Txt:='Invalid regular expression: '+Msg;
  end
  else
  begin
    SetHighlight(CSyn,S);
    Txt:='';
    Counted:=False;
    if S.FindText<>'' then
    begin
      N:=CountMatches(Editors,IH.Cur,S,FState,Idx);
      if (S.Scope=fsSelection) and not HasRange(FState,CSyn) then
        Txt:='Select the text to search in first'
      else if N=0 then
        Txt:='No matches'
      else
      begin
        Counted:=True;
        if Idx>0 then
          Txt:=Format('%d of %d %s',[Idx,N,Plural(N,'match','matches')])
        else
          Txt:=Format('%d %s',[N,Plural(N,'match','matches')]);
      end;
    end;
    if NoteOnly then
      Txt:=Note
    else if Counted and (Note<>'') then
      Txt:=Txt+', '+Note;
  end;
  StatusLabel.Caption:=Txt;
  StatusLabel.Hint:=Txt;
  FSignature:=Signature;
end;

////////////////////////////////////////////////////////////////////////////////
// Called by main.pas's UpdateTimerTimer while the window is open.
procedure TEuoFindDialog.Poll;
begin
  if Signature<>FSignature then
    Refresh;
end;

////////////////////////////////////////////////////////////////////////////////
// Deleting the history entry the box is showing can blank the box: put the
// text back if so.
procedure TEuoFindDialog.Remember(const S : TFindSettings; WithReplace : Boolean);

  procedure Add(Box : TComboBox; const Txt : String);
  begin
    if Txt='' then Exit;
    AddToHistory(Box.Items,Txt);
    if Box.Text<>Txt then
    begin
      Box.Text:=Txt;
      Box.SelStart:=Length(Txt);
    end;
  end;

begin
  FUpdating:=True;
  try
    Add(FindBox,S.FindText);
    if WithReplace then Add(ReplaceBox,S.ReplaceText);
  finally
    FUpdating:=False;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindDialog.DoFind(Backwards : Boolean) : Boolean;
var
  S    : TFindSettings;
  Hit  : TFindHit;
  Note : String;
begin
  Result:=False;
  S:=Settings;
  S.Backwards:=Backwards;
  if not Ready(S) then Exit;
  Remember(S,False);
  Result:=FindNext(Editors,IH.Cur,S,FState,Hit);
  Note:='';
  if Result then
  begin
    if Hit.Index<>IH.Cur then MainForm.ShowTab(Hit.Index);
    IH.Syn[Hit.Index].EnsureCursorPosVisible;
    if Hit.Wrapped then
      if S.Scope=fsAllScripts then Note:='wrapped around'
      else if Backwards then Note:='wrapped to the bottom'
      else Note:='wrapped to the top';
  end
  else if not S.WrapAround then
    if Backwards then Note:='no more above' else Note:='no more below';
  Refresh(Note);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.Prefill;
var
  Ed     : TSynEdit;
  P      : TPoint;
  X1, X2 : Integer;
  L, W   : String;
begin
  Ed:=CSyn;
  W:='';
  if Ed.SelAvail then
  begin
    if Ed.BlockBegin.Y<>Ed.BlockEnd.Y then
    begin
      ScopeGroup.ItemIndex:=Ord(fsSelection);
      Exit;
    end;
    W:=Ed.SelText;
  end
  else
  begin
    P:=Ed.LogicalCaretXY;
    if (P.Y<1) or (P.Y>Ed.Lines.Count) then Exit;
    Ed.GetWordBoundsAtRowCol(P,X1,X2);
    if X2<=X1 then Exit;
    L:=Ed.Lines[P.Y-1];
    if (X1>1) and (L[X1-1] in ['#','%','!','*']) then Dec(X1);
    W:=Copy(L,X1,X2-X1);
  end;
  if W='' then Exit;
  if RegExprBox.Checked then W:=QuoteRegExprMetaChars(W);
  FindBox.Text:=W;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.Open(FocusReplace : Boolean);
var
  R : TRect;
begin
  FUpdating:=True;
  try
    Prefill;
  finally
    FUpdating:=False;
  end;
  // first time: the top right of the editor, where it covers the least code
  if not FPlaced then
  begin
    R:=MainForm.BoundsRect;
    Left:=R.Right-Width-Scale96ToForm(40);
    Top:=R.Top+Scale96ToForm(90);
    FPlaced:=True;
  end;
  Show;
  MakeFullyVisible;
  if FocusReplace and (FindBox.Text<>'') then
  begin
    ReplaceBox.SetFocus;
    ReplaceBox.SelectAll;
  end
  else
  begin
    FindBox.SetFocus;
    FindBox.SelectAll;
  end;
  Refresh;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.ShowFind;
begin
  Open(False);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.ShowReplace;
begin
  Open(True);
end;

////////////////////////////////////////////////////////////////////////////////
// Edit > Find Next / Find Previous: works with the window closed too.
procedure TEuoFindDialog.FindAgain(Reverse : Boolean);
begin
  if FindBox.Text='' then
  begin
    ShowFind;
    Exit;
  end;
  if not DoFind((DirGroup.ItemIndex=1) xor Reverse) and not Visible then
    Beep;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoFindDialog.OptionChange(Sender : TObject);
begin
  if not FUpdating then Refresh;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.FindClick(Sender : TObject);
begin
  DoFind(DirGroup.ItemIndex=1);
end;

////////////////////////////////////////////////////////////////////////////////
// Replaces the match Find Next selected, then finds the next one; with no
// match selected yet, the first click only finds.
procedure TEuoFindDialog.ReplaceClick(Sender : TObject);
var
  S : TFindSettings;
begin
  S:=Settings;
  if not Ready(S) then Exit;
  Remember(S,True);
  if CExec.State<>STOP then
  begin
    Refresh(RunningMsg,True);
    Exit;
  end;
  ReplaceCurrent(CSyn,S,FState);
  DoFind(S.Backwards);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.ReplaceAllClick(Sender : TObject);
var
  S, One                        : TFindSettings;
  i, Lo, Hi, Idx                : Integer;
  Total, Scripts, Skipped, N    : Integer;
  Cancelled                     : Boolean;
  Ed                            : TSynEdit;
  Note                          : String;
begin
  S:=Settings;
  if not Ready(S) then Exit;
  Remember(S,True);
  One:=S;
  if S.Scope=fsAllScripts then
  begin
    One.Scope:=fsScript;
    Lo:=0;
    Hi:=IH.Count-1;
  end
  else
  begin
    Lo:=IH.Cur;
    Hi:=IH.Cur;
  end;
  Total:=0;
  Scripts:=0;
  Skipped:=0;
  for i:=Lo to Hi do
  begin
    Ed:=IH.Syn[i];
    if CountMatches([Ed],0,One,FState,Idx)=0 then Continue;
    if IH.Exec[i].State<>STOP then
    begin
      Inc(Skipped);
      Continue;
    end;
    // a prompt has to show the match it asks about
    if S.PromptOnReplace and (i<>IH.Cur) then MainForm.ShowTab(i);
    N:=ReplaceAllIn(Ed,One,FState,Cancelled);
    if N>0 then
    begin
      Inc(Total,N);
      Inc(Scripts);
    end;
    if Cancelled then Break;
  end;

  Note:='';
  if (S.Scope<>fsAllScripts) and (Skipped>0) then
    Note:=RunningMsg
  else if (Total>0) or (Skipped>0) then
  begin
    Note:=Format('Replaced %d',[Total]);
    if S.Scope=fsAllScripts then
      Note:=Note+Format(' in %d %s',[Scripts,Plural(Scripts,'script','scripts')]);
    if Skipped>0 then
      Note:=Note+Format(', %d running %s skipped',[Skipped,Plural(Skipped,'script','scripts')]);
  end;
  Refresh(Note,Note<>'');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.CloseClick(Sender : TObject);
begin
  Close;
end;

////////////////////////////////////////////////////////////////////////////////
// KeyPreview: these keys work whichever control has the focus -- except
// Enter on a button (that button's own click) and Enter/Esc in an open
// history list (pick / close the list).
procedure TEuoFindDialog.DialogKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);

  function ListOpen : Boolean;
  begin
    Result:=(ActiveControl is TComboBox) and TComboBox(ActiveControl).DroppedDown;
  end;

begin
  case Key of
    VK_ESCAPE :
      if not ListOpen then
      begin
        Key:=0;
        Close;
      end;
    VK_RETURN :
      if not ListOpen and not (ActiveControl is TButton) then
      begin
        Key:=0;
        DoFind((DirGroup.ItemIndex=1) xor (ssShift in Shift));
      end;
    VK_F3 :
      begin
        Key:=0;
        DoFind((DirGroup.ItemIndex=1) xor (ssShift in Shift));
      end;
    VK_F :
      if Shift=[ssCtrl] then
      begin
        Key:=0;
        FindBox.SetFocus;
        FindBox.SelectAll;
      end;
    VK_H :
      if Shift=[ssCtrl] then
      begin
        Key:=0;
        ReplaceBox.SetFocus;
        ReplaceBox.SelectAll;
      end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.DialogClose(Sender : TObject; var CloseAction : TCloseAction);
begin
  CloseAction:=caHide;
  SetHighlight(nil,Settings);
  SaveSettings(Reg);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.LoadSettings(Reg : TRegistry);
var
  Bits : Integer;
begin
  FUpdating:=True;
  try
    if Reg.ValueExists('FindHistory') then
      FindBox.Items.Text:=Reg.ReadString('FindHistory');
    if Reg.ValueExists('ReplaceHistory') then
      ReplaceBox.Items.Text:=Reg.ReadString('ReplaceHistory');
    if FindBox.Items.Count>0 then FindBox.Text:=FindBox.Items[0];
    if ReplaceBox.Items.Count>0 then ReplaceBox.Text:=ReplaceBox.Items[0];
    if Reg.ValueExists('FindOptions') then
    begin
      Bits:=Reg.ReadInteger('FindOptions');
      MatchCaseBox.Checked:=Bits and 1<>0;
      WholeWordBox.Checked:=Bits and 2<>0;
      RegExprBox.Checked:=Bits and 4<>0;
      WrapBox.Checked:=Bits and 8<>0;
      PromptBox.Checked:=Bits and 16<>0;
    end;
  finally
    FUpdating:=False;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindDialog.SaveSettings(Reg : TRegistry);
var
  Bits : Integer;
begin
  Bits:=0;
  if MatchCaseBox.Checked then Bits:=Bits or 1;
  if WholeWordBox.Checked then Bits:=Bits or 2;
  if RegExprBox.Checked   then Bits:=Bits or 4;
  if WrapBox.Checked      then Bits:=Bits or 8;
  if PromptBox.Checked    then Bits:=Bits or 16;
  Reg.WriteInteger('FindOptions',Bits);
  Reg.WriteString('FindHistory',FindBox.Items.Text);
  Reg.WriteString('ReplaceHistory',ReplaceBox.Items.Text);
end;

end.
