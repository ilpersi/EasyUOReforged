unit eusearchpath;

{
  Port addition (not present in the original app): Tools > Search Folders, the folder list CALL
  and SQL OPEN search for a relative name they do not find in #CurPath (the lookup and its whole order are in
  parser\EuoSearchPath.pas). Built in code like the rest of the GUI (see main.pas's header comment),
  laid out like Windows' own "Edit environment variable" window for PATH: one folder per row, New,
  Edit, Browse..., Delete, Move Up, Move Down and Edit text... on the right, OK and Cancel below.

  - The list is kept in the registry (EuoSearchPath.ReadSavedSearchPath / WriteSavedSearchPath:
    \Software\EasyUO Reforged, value SearchPath, the folders separated by ';'). LoadEditorSearchPath reads
    it once at start into EditorSearchPath, which every tab's interpreter gets as SearchPath:
    insthandler.pas when a tab is made, main.pas for every tab after OK. A script that is running uses
    the new list from its next CALL or SQL OPEN. EUOCli reads the same value.
  - Rows are edited in place: New starts a row, F2, Edit or a double click edit one. A row left
    empty is dropped. Insert is New, Delete is Delete. Browse... puts the folder in an empty selected
    row, or adds it below the selection.
  - A folder that does not exist now is drawn grey: the lookup skips it. A relative folder starts from
    #CurPath, as the lookup takes it.
  - The top line says #CurPath comes first; the bottom line shows EUOPATH, which is searched
    after the list, so the whole order is in the window.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, Graphics, Dialogs, LCLType;

type
  TSearchFoldersDialog = class(TForm)
  private
    FTopLabel, FEnvLabel, FGreyLabel : TLabel;
    FList : TListView;
    FNewBtn, FEditBtn, FBrowseBtn, FDeleteBtn, FUpBtn, FDownBtn, FTextBtn : TButton;
    FOKBtn, FCancelBtn : TButton;
    function  NewButton(const ACaption : String; X, Y : Integer; AOnClick : TNotifyEvent) : TButton;
    function  NewLabel(X, Y, W, H : Integer) : TLabel;
    function  SelIndex : Integer;
    procedure Select(Index : Integer);
    procedure UpdateButtons;
    procedure DropEmpty;
    procedure DropEmptyAsync(Data : PtrInt);
    procedure ListSelectItem(Sender : TObject; Item : TListItem; Selected : Boolean);
    procedure EditorExit(Sender : TObject);
    procedure ListEdited(Sender : TObject; Item : TListItem; var AValue : String);
    procedure ListKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
    procedure ListDblClick(Sender : TObject);
    procedure ListResize(Sender : TObject);
    procedure ListDrawItem(Sender : TCustomListView; Item : TListItem;
                State : TCustomDrawState; var DefaultDraw : Boolean);
    procedure NewClick(Sender : TObject);
    procedure EditClick(Sender : TObject);
    procedure BrowseClick(Sender : TObject);
    procedure DeleteClick(Sender : TObject);
    procedure UpClick(Sender : TObject);
    procedure DownClick(Sender : TObject);
    procedure TextClick(Sender : TObject);
  public
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
    // The rows, from / to a ';' folder list (EuoSearchPath.SplitSearchPath / JoinSearchPath).
    procedure SetFolders(const Value : String);
    function  GetFolders : String;
    property  List : TListView read FList;
  end;

var
  // The saved folder list, as TEuoInterpreter.SearchPath takes it (see the header).
  EditorSearchPath : String = '';

// Reads EditorSearchPath from the registry.
procedure LoadEditorSearchPath;
// Shows the window with EditorSearchPath. On OK: saves the list, sets EditorSearchPath and returns True;
// the caller hands it to the tabs.
function  EditSearchFolders(AOwner : TComponent) : Boolean;

implementation

uses
  EuoSearchPath;

type
  TEditAccess = class(TCustomEdit);   // OnExit is protected in TCustomEdit

////////////////////////////////////////////////////////////////////////////////
procedure LoadEditorSearchPath;
begin
  EditorSearchPath:=ReadSavedSearchPath;
end;

////////////////////////////////////////////////////////////////////////////////
function EditSearchFolders(AOwner : TComponent) : Boolean;
var
  Dlg     : TSearchFoldersDialog;
  NewPath : String;
begin
  Result:=False;
  Dlg:=TSearchFoldersDialog.Create(AOwner);
  try
    Dlg.SetFolders(EditorSearchPath);
    if Dlg.ShowModal<>mrOK then Exit;
    NewPath:=Dlg.GetFolders;
  finally
    Dlg.Free;
  end;
  if not WriteSavedSearchPath(NewPath) then
    MessageDlg('The folder list could not be saved in the registry. It is used until EasyUO '+
      'Reforged closes.',mtWarning,[mbOK],0);
  EditorSearchPath:=NewPath;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// The folder a row stands for, as the lookup takes it: a relative one from #CurPath.
function FolderOf(const Entry : String) : String;
begin
  Result:=Trim(Entry);
  if (Result<>'') and not IsAbsoluteName(Result) then
    Result:=ExtractFilePath(ParamStr(0))+Result;
end;

////////////////////////////////////////////////////////////////////////////////
/// TSearchFoldersDialog /////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TSearchFoldersDialog.Create(AOwner : TComponent);
var
  Col : TListColumn;
  Env : String;
  i   : Integer;
begin
  inherited CreateNew(AOwner);
  Caption:='Search Folders';
  BorderStyle:=bsSizeable;
  BorderIcons:=[biSystemMenu];
  ShowInTaskBar:=stNever;
  Position:=poOwnerFormCenter;
  ClientWidth:=Scale96ToForm(580);
  ClientHeight:=Scale96ToForm(390);
  Constraints.MinWidth:=Scale96ToForm(420);
  Constraints.MinHeight:=Scale96ToForm(300);

  FTopLabel:=NewLabel(8,8,564,46);
  FTopLabel.Anchors:=[akLeft,akTop,akRight];
  FTopLabel.Caption:='call and sql open look for a name that is not a full path in the program '+
    'folder (#CurPath) first, then in these folders, from the top. In each folder they try the name '+
    'as written, then call adds .txt and .euo, and sql open adds .db and .sqlite.';

  FList:=TListView.Create(Self);
  FList.Parent:=Self;
  FList.SetBounds(Scale96ToForm(8),Scale96ToForm(58),Scale96ToForm(452),Scale96ToForm(218));
  FList.Anchors:=[akLeft,akTop,akRight,akBottom];
  FList.ViewStyle:=vsReport;
  FList.ShowColumnHeaders:=False;
  FList.ReadOnly:=False;   // rows are edited in place
  FList.RowSelect:=True;
  FList.HideSelection:=False;
  FList.MultiSelect:=False;
  Col:=FList.Columns.Add;
  Col.Caption:='Folder';
  FList.OnSelectItem:=ListSelectItem;
  FList.OnEdited:=ListEdited;
  // The in-place editor is a child control LCL makes with the list (customlistview.inc).
  for i:=0 to FList.ControlCount-1 do
    if FList.Controls[i] is TCustomListViewEditor then
      TEditAccess(FList.Controls[i]).OnExit:=EditorExit;
  FList.OnKeyDown:=ListKeyDown;
  FList.OnDblClick:=ListDblClick;
  FList.OnResize:=ListResize;
  FList.OnCustomDrawItem:=ListDrawItem;

  FNewBtn   :=NewButton('&New',472,58,NewClick);
  FEditBtn  :=NewButton('&Edit',472,88,EditClick);
  FBrowseBtn:=NewButton('&Browse...',472,118,BrowseClick);
  FDeleteBtn:=NewButton('&Delete',472,148,DeleteClick);
  FUpBtn    :=NewButton('Move &Up',472,184,UpClick);
  FDownBtn  :=NewButton('Move D&own',472,214,DownClick);
  FTextBtn  :=NewButton('Edit &text...',472,248,TextClick);

  FGreyLabel:=NewLabel(8,284,564,18);
  FGreyLabel.Anchors:=[akLeft,akRight,akBottom];
  FGreyLabel.Caption:='A grey folder does not exist and is skipped. A relative folder starts from '+
    'the program folder.';

  FEnvLabel:=NewLabel(8,306,564,34);
  FEnvLabel.Anchors:=[akLeft,akRight,akBottom];
  Env:=EnvEuoPath;
  if Trim(Env)='' then
    FEnvLabel.Caption:='Then in the folders of the EUOPATH environment variable, which is not set.'
  else
    FEnvLabel.Caption:='Then in the folders of the EUOPATH environment variable: '+Env;
  FEnvLabel.Hint:=FEnvLabel.Caption;
  FEnvLabel.ShowHint:=True;

  FOKBtn:=NewButton('OK',368,354,nil);
  FOKBtn.Anchors:=[akRight,akBottom];
  FOKBtn.Default:=True;
  FOKBtn.ModalResult:=mrOK;
  FCancelBtn:=NewButton('Cancel',472,354,nil);
  FCancelBtn.Anchors:=[akRight,akBottom];
  FCancelBtn.Cancel:=True;
  FCancelBtn.ModalResult:=mrCancel;

  ActiveControl:=FList;
  UpdateButtons;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TSearchFoldersDialog.Destroy;
begin
  Application.RemoveAsyncCalls(Self);   // a DropEmptyAsync still queued must not outlive the window
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
function TSearchFoldersDialog.NewButton(const ACaption : String; X, Y : Integer;
  AOnClick : TNotifyEvent) : TButton;
begin
  Result:=TButton.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(100),Scale96ToForm(25));
  Result.Anchors:=[akTop,akRight];
  Result.OnClick:=AOnClick;
end;

////////////////////////////////////////////////////////////////////////////////
function TSearchFoldersDialog.NewLabel(X, Y, W, H : Integer) : TLabel;
begin
  Result:=TLabel.Create(Self);
  Result.Parent:=Self;
  Result.AutoSize:=False;
  Result.WordWrap:=True;
  Result.ShowAccelChar:=False;   // folder names may have an &
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(W),Scale96ToForm(H));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.SetFolders(const Value : String);
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    SplitSearchPath(Value,L);
    FList.Items.BeginUpdate;
    try
      FList.Items.Clear;
      for i:=0 to L.Count-1 do FList.Items.Add.Caption:=L[i];
    finally
      FList.Items.EndUpdate;
    end;
  finally
    L.Free;
  end;
  if FList.Items.Count>0 then Select(0) else UpdateButtons;
end;

////////////////////////////////////////////////////////////////////////////////
function TSearchFoldersDialog.GetFolders : String;
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    for i:=0 to FList.Items.Count-1 do L.Add(FList.Items[i].Caption);
    Result:=JoinSearchPath(L);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TSearchFoldersDialog.SelIndex : Integer;
begin
  if FList.Selected=nil then Result:=-1 else Result:=FList.Selected.Index;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.Select(Index : Integer);
begin
  if (Index>=0) and (Index<FList.Items.Count) then
  begin
    FList.Selected:=FList.Items[Index];
    FList.ItemFocused:=FList.Selected;
    FList.Selected.MakeVisible(False);
  end
  else FList.Selected:=nil;
  UpdateButtons;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.UpdateButtons;
var
  i : Integer;
begin
  i:=SelIndex;
  FEditBtn.Enabled:=i>=0;
  FDeleteBtn.Enabled:=i>=0;
  FUpBtn.Enabled:=i>0;
  FDownBtn.Enabled:=(i>=0) and (i<FList.Items.Count-1);
end;

////////////////////////////////////////////////////////////////////////////////
// Rows left empty go (a New row given no folder, an edit that cleared one). When the selected
// row goes, the one above it is selected.
procedure TSearchFoldersDialog.DropEmpty;
var
  i, Sel : Integer;
begin
  Sel:=SelIndex;
  for i:=FList.Items.Count-1 downto 0 do
    if Trim(FList.Items[i].Caption)='' then
    begin
      FList.Items.Delete(i);
      if Sel>=i then Dec(Sel);
    end;
  if Sel>=FList.Items.Count then Sel:=FList.Items.Count-1;
  if (Sel<0) and (FList.Items.Count>0) then Sel:=0;
  Select(Sel);
end;

procedure TSearchFoldersDialog.DropEmptyAsync(Data : PtrInt);
begin
  if not FList.IsEditing then DropEmpty;
end;

////////////////////////////////////////////////////////////////////////////////
// Esc on an edit gives no OnEdited: LCL hides its editor and gives the list the focus back, which
// is not an Enter of the list (the focus never left it). A New row left empty that way goes from
// here, once the edit is over.
procedure TSearchFoldersDialog.EditorExit(Sender : TObject);
begin
  Application.QueueAsyncCall(DropEmptyAsync,0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.ListSelectItem(Sender : TObject; Item : TListItem; Selected : Boolean);
begin
  UpdateButtons;
end;

////////////////////////////////////////////////////////////////////////////////
// The edit is not over yet when this runs, so an emptied row is dropped once it is.
procedure TSearchFoldersDialog.ListEdited(Sender : TObject; Item : TListItem; var AValue : String);
begin
  AValue:=Trim(AValue);
  if AValue='' then Application.QueueAsyncCall(DropEmptyAsync,0);
  FList.Invalidate;   // grey or not, for the new text
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.ListKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
begin
  if Shift<>[] then Exit;
  case Key of
    VK_INSERT : NewClick(nil);
    VK_DELETE : if FDeleteBtn.Enabled then DeleteClick(nil);
    VK_F2     : if FEditBtn.Enabled then EditClick(nil);
  else
    Exit;
  end;
  Key:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.ListDblClick(Sender : TObject);
begin
  if FEditBtn.Enabled then EditClick(nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.ListResize(Sender : TObject);
begin
  if FList.Columns.Count>0 then
    FList.Columns[0].Width:=FList.ClientWidth-Scale96ToForm(4);
end;

////////////////////////////////////////////////////////////////////////////////
// LCL's win32 list view hands Canvas.Font.Color to the control as the text colour (see euwatch.pas).
procedure TSearchFoldersDialog.ListDrawItem(Sender : TCustomListView; Item : TListItem;
  State : TCustomDrawState; var DefaultDraw : Boolean);
var
  F : String;
begin
  F:=FolderOf(Item.Caption);
  if (F<>'') and not DirectoryExists(F) then Sender.Canvas.Font.Color:=clGrayText
  else Sender.Canvas.Font.Color:=clWindowText;
  DefaultDraw:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.NewClick(Sender : TObject);
var
  Item : TListItem;
begin
  DropEmpty;
  Item:=FList.Items.Add;
  Item.Caption:='';
  Select(Item.Index);
  FList.SetFocus;
  Item.EditCaption;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.EditClick(Sender : TObject);
begin
  if FList.Selected=nil then Exit;
  FList.SetFocus;
  FList.Selected.EditCaption;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.BrowseClick(Sender : TObject);
var
  Dlg  : TSelectDirectoryDialog;
  Item : TListItem;
  F    : String;
begin
  Dlg:=TSelectDirectoryDialog.Create(Self);
  try
    Dlg.Title:='Choose a search folder';
    Dlg.Options:=[ofPathMustExist,ofEnableSizing];
    F:='';
    if FList.Selected<>nil then F:=FolderOf(FList.Selected.Caption);
    if (F='') or not DirectoryExists(F) then F:=ExtractFilePath(ParamStr(0));
    Dlg.InitialDir:=F;
    if not Dlg.Execute then Exit;
    F:=ExcludeTrailingPathDelimiter(Dlg.FileName);
  finally
    Dlg.Free;
  end;
  if F='' then Exit;

  if (FList.Selected<>nil) and (Trim(FList.Selected.Caption)='') then
    Item:=FList.Selected
  else begin
    DropEmpty;
    if FList.Selected=nil then Item:=FList.Items.Add
    else Item:=FList.Items.Insert(FList.Selected.Index+1);
  end;
  Item.Caption:=F;
  Select(Item.Index);
  FList.Invalidate;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.DeleteClick(Sender : TObject);
var
  i : Integer;
begin
  i:=SelIndex;
  if i<0 then Exit;
  FList.Items.Delete(i);
  if i>=FList.Items.Count then i:=FList.Items.Count-1;
  Select(i);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.UpClick(Sender : TObject);
var
  i : Integer;
  S : String;
begin
  DropEmpty;
  i:=SelIndex;
  if i<1 then Exit;
  S:=FList.Items[i-1].Caption;
  FList.Items[i-1].Caption:=FList.Items[i].Caption;
  FList.Items[i].Caption:=S;
  Select(i-1);
  FList.Invalidate;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.DownClick(Sender : TObject);
var
  i : Integer;
  S : String;
begin
  DropEmpty;
  i:=SelIndex;
  if (i<0) or (i>=FList.Items.Count-1) then Exit;
  S:=FList.Items[i+1].Caption;
  FList.Items[i+1].Caption:=FList.Items[i].Caption;
  FList.Items[i].Caption:=S;
  Select(i+1);
  FList.Invalidate;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSearchFoldersDialog.TextClick(Sender : TObject);
var
  S : String;
begin
  S:=GetFolders;
  if InputQuery('Search Folders','The folders, separated by ;',S) then SetFolders(S);
end;

end.
