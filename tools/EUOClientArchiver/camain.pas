unit camain;

{
  Port addition: EUOClientArchiver's window, built entirely in code like the other GUIs (there is
  no .lfm). One small fixed form: the client folder and one line per client, the archive folder,
  an optional note, the Archive button, the log, and the list of the archives already in the
  archive folder. Everything it does is in caarchive.pas, which the test suite calls directly.

  The client lines and the list are refreshed when either folder changes (after 300 ms of no
  typing: each refresh hashes the clients and unpacks archives) and after archiving. Both folders
  are remembered under HKCU\Software\EasyUO Reforged\Client Archiver; the note is not.
}

{$mode delphi}{$H+}

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Registry, caarchive;

type
  TCaMainForm = class(TForm)
  private
    ClientEdit  : TEdit;
    ClientLines : TLabel;
    ArchiveEdit : TEdit;
    NoteEdit    : TEdit;
    ArchiveBtn  : TButton;
    Log         : TMemo;
    List        : TListView;
    Timer       : TTimer;
    Archivable  : Boolean;   // the client folder holds a client that can be archived
    Busy        : Boolean;
    Loading     : Boolean;

    function  NewLabel(const ACaption : String; X, Y : Integer) : TLabel;
    function  NewEdit(X, Y, W : Integer) : TEdit;
    function  NewButton(const ACaption : String; X, Y, W : Integer; AOnClick : TNotifyEvent) : TButton;
    procedure FolderChange(Sender : TObject);
    procedure TimerTick(Sender : TObject);
    procedure BrowseClientClick(Sender : TObject);
    procedure BrowseArchiveClick(Sender : TObject);
    procedure ArchiveClick(Sender : TObject);
    procedure LogLineAdded(Sender : TObject);
    procedure FormClose(Sender : TObject; var CloseAction : TCloseAction);
    function  Browse(const ATitle, Current : String; out Folder : String) : Boolean;
    procedure RefreshAll;
    procedure RefreshList;
    procedure UpdateButton;
    procedure LoadSettings;
    procedure SaveSettings;
  public
    constructor Create(AOwner : TComponent); override;
  end;

var
  CaMainForm : TCaMainForm;

implementation

const
  RegKey    = '\Software\EasyUO Reforged\Client Archiver';
  LineH     = 16;    // one client line, in 96 DPI pixels
  FormW     = 720;
  Margin    = 10;
  BrowseW   = 92;

////////////////////////////////////////////////////////////////////////////////
// Laid out in 96 DPI pixels, scaled like the fonts are (as easyuo\eufinddlg.pas does).
constructor TCaMainForm.Create(AOwner : TComponent);
var
  Y, EditW : Integer;
  L        : TLabel;

  procedure AddColumn(const ACaption : String; W : Integer);
  var
    C : TListColumn;
  begin
    C:=List.Columns.Add;
    C.Caption:=ACaption;
    C.Width:=Scale96ToForm(W);
  end;

begin
  inherited CreateNew(AOwner);
  Loading:=True;
  Caption:='EasyUO Reforged Client Archiver';
  BorderStyle:=bsSingle;
  BorderIcons:=[biSystemMenu,biMinimize];
  Position:=poScreenCenter;
  OnClose:=FormClose;
  EditW:=FormW-3*Margin-BrowseW;

  Y:=Margin;
  L:=NewLabel('&Client folder (the one with client.exe):',Margin,Y);
  ClientEdit:=NewEdit(Margin,Y+18,EditW);
  L.FocusControl:=ClientEdit;
  NewButton('&Browse...',FormW-Margin-BrowseW,Y+17,BrowseW,BrowseClientClick);

  Y:=Y+50;
  ClientLines:=NewLabel('',Margin,Y);
  ClientLines.AutoSize:=False;
  ClientLines.ShowAccelChar:=False;
  ClientLines.WordWrap:=False;
  ClientLines.Font.Name:='Consolas';
  ClientLines.Font.Size:=9;
  ClientLines.SetBounds(Scale96ToForm(Margin),Scale96ToForm(Y),Scale96ToForm(FormW-2*Margin),
    Scale96ToForm(LineH*Length(ClientNames)+4));

  Y:=Y+LineH*Length(ClientNames)+12;
  L:=NewLabel('A&rchive folder (any folder; created when needed):',Margin,Y);
  ArchiveEdit:=NewEdit(Margin,Y+18,EditW);
  L.FocusControl:=ArchiveEdit;
  NewButton('Br&owse...',FormW-Margin-BrowseW,Y+17,BrowseW,BrowseArchiveClick);

  Y:=Y+50;
  L:=NewLabel('&Note (optional, goes into the .txt of each archive written now):',Margin,Y);
  NoteEdit:=NewEdit(Margin,Y+18,EditW);
  L.FocusControl:=NoteEdit;
  ArchiveBtn:=NewButton('&Archive',FormW-Margin-BrowseW,Y+17,BrowseW,ArchiveClick);

  Y:=Y+52;
  Log:=TMemo.Create(Self);
  Log.Parent:=Self;
  Log.ReadOnly:=True;
  Log.WordWrap:=False;
  Log.ScrollBars:=ssAutoBoth;
  Log.Font.Name:='Consolas';
  Log.Font.Size:=9;
  Log.SetBounds(Scale96ToForm(Margin),Scale96ToForm(Y),Scale96ToForm(FormW-2*Margin),Scale96ToForm(110));

  Y:=Y+120;
  NewLabel('Archived builds in the archive folder:',Margin,Y);
  List:=TListView.Create(Self);
  List.Parent:=Self;
  List.ViewStyle:=vsReport;
  List.ReadOnly:=True;
  List.RowSelect:=True;
  List.HideSelection:=False;
  List.SetBounds(Scale96ToForm(Margin),Scale96ToForm(Y+18),Scale96ToForm(FormW-2*Margin),Scale96ToForm(180));
  AddColumn('Archive',190);
  AddColumn('Version',95);
  AddColumn('PE stamp',70);
  AddColumn('Relocatable',75);
  AddColumn('Archived (UTC)',125);
  AddColumn('Note',139);

  ClientWidth:=Scale96ToForm(FormW);
  ClientHeight:=Scale96ToForm(Y+18+180+Margin);

  Timer:=TTimer.Create(Self);
  Timer.Enabled:=False;
  Timer.Interval:=300;
  Timer.OnTimer:=TimerTick;

  LoadSettings;
  ClientEdit.OnChange:=FolderChange;
  ArchiveEdit.OnChange:=FolderChange;
  Loading:=False;
  RefreshAll;
end;

////////////////////////////////////////////////////////////////////////////////
function TCaMainForm.NewLabel(const ACaption : String; X, Y : Integer) : TLabel;
begin
  Result:=TLabel.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.Left:=Scale96ToForm(X);
  Result.Top:=Scale96ToForm(Y);
end;

function TCaMainForm.NewEdit(X, Y, W : Integer) : TEdit;
begin
  Result:=TEdit.Create(Self);
  Result.Parent:=Self;
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(W),Result.Height);
end;

function TCaMainForm.NewButton(const ACaption : String; X, Y, W : Integer;
  AOnClick : TNotifyEvent) : TButton;
begin
  Result:=TButton.Create(Self);
  Result.Parent:=Self;
  Result.Caption:=ACaption;
  Result.SetBounds(Scale96ToForm(X),Scale96ToForm(Y),Scale96ToForm(W),Scale96ToForm(25));
  Result.OnClick:=AOnClick;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCaMainForm.FolderChange(Sender : TObject);
begin
  if Loading then Exit;
  Timer.Enabled:=False;   // restarts the 300 ms
  Timer.Enabled:=True;
  UpdateButton;
end;

procedure TCaMainForm.TimerTick(Sender : TObject);
begin
  Timer.Enabled:=False;
  RefreshAll;
end;

// One line per client, or the folder's error in red, then the list and the button.
procedure TCaMainForm.RefreshAll;
var
  Infos   : TClientInfos;
  Err     : String;
  Text    : String;
  Arch    : String;
  Cnt     : Integer;
  OldCur  : TCursor;
begin
  OldCur:=Screen.Cursor;
  Screen.Cursor:=crHourGlass;
  try
    Arch:=Trim(ArchiveEdit.Text);
    Archivable:=False;
    if Trim(ClientEdit.Text)='' then
    begin
      ClientLines.Font.Color:=clGrayText;
      ClientLines.Caption:='Pick the folder that holds the clients.';
    end
    else if FindClients(Trim(ClientEdit.Text),Infos,Err) then
    begin
      Text:='';
      for Cnt:=0 to High(Infos) do
      begin
        if Cnt>0 then Text:=Text+LineEnding;
        Text:=Text+DescribeClient(Infos[Cnt],ArchivedStatus(Infos[Cnt],Arch));
        if CanArchive(Infos[Cnt]) then Archivable:=True;
      end;
      ClientLines.Font.Color:=clWindowText;
      ClientLines.Caption:=Text;
    end
    else
    begin
      ClientLines.Font.Color:=clRed;
      ClientLines.Caption:=Err;
    end;
    RefreshList;
  finally
    Screen.Cursor:=OldCur;
  end;
  UpdateButton;
end;

procedure TCaMainForm.RefreshList;
var
  Builds : TArchivedBuilds;
  Cnt    : Integer;
  Item   : TListItem;
begin
  Builds:=ListArchivedBuilds(Trim(ArchiveEdit.Text));
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    for Cnt:=0 to High(Builds) do
    begin
      Item:=List.Items.Add;
      Item.Caption:=Builds[Cnt].ZipName;
      Item.SubItems.Add(Builds[Cnt].Version);
      Item.SubItems.Add(Builds[Cnt].Stamp);
      Item.SubItems.Add(Builds[Cnt].Relocatable);
      Item.SubItems.Add(StringReplace(Builds[Cnt].Archived,' UTC','',[]));   // the header says UTC
      Item.SubItems.Add(Builds[Cnt].Note);
    end;
  finally
    List.Items.EndUpdate;
  end;
end;

procedure TCaMainForm.UpdateButton;
begin
  ArchiveBtn.Enabled:=Archivable and (Trim(ArchiveEdit.Text)<>'') and not Busy;
end;

////////////////////////////////////////////////////////////////////////////////
function TCaMainForm.Browse(const ATitle, Current : String; out Folder : String) : Boolean;
var
  Dlg : TSelectDirectoryDialog;
begin
  Dlg:=TSelectDirectoryDialog.Create(Self);
  try
    Dlg.Title:=ATitle;
    if (Trim(Current)<>'') and DirectoryExists(Trim(Current)) then Dlg.InitialDir:=Trim(Current);
    Result:=Dlg.Execute;
    if Result then Folder:=Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TCaMainForm.BrowseClientClick(Sender : TObject);
var
  Folder : String;
begin
  if not Browse('Client folder',ClientEdit.Text,Folder) then Exit;
  ClientEdit.Text:=Folder;
  Timer.Enabled:=False;
  RefreshAll;
end;

procedure TCaMainForm.BrowseArchiveClick(Sender : TObject);
var
  Folder : String;
begin
  if not Browse('Archive folder',ArchiveEdit.Text,Folder) then Exit;
  ArchiveEdit.Text:=Folder;
  Timer.Enabled:=False;
  RefreshAll;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCaMainForm.ArchiveClick(Sender : TObject);
var
  Arch, Git : String;
begin
  if Timer.Enabled then   // a folder was edited a moment ago: look at it first
  begin
    Timer.Enabled:=False;
    RefreshAll;
    if not ArchiveBtn.Enabled then Exit;
  end;
  Arch:=Trim(ArchiveEdit.Text);
  Git:=FindGitFolder(Arch);
  if (Git<>'') and (MessageDlg('Archive folder in a git repository',
       'The archive folder is inside the git repository at'+LineEnding+Git+LineEnding+LineEnding+
       'Client executables must never be committed, and *.zip files are not git-ignored. '+
       'Write the archives there anyway?',mtWarning,[mbYes,mbNo],0,mbNo)<>mrYes) then
    Exit;

  SaveSettings;
  Busy:=True;
  UpdateButton;
  Screen.Cursor:=crHourGlass;
  try
    if Log.Lines.Count>0 then Log.Lines.Add('');
    ArchiveAll(Trim(ClientEdit.Text),Arch,NoteEdit.Text,Log.Lines,LogLineAdded);
  finally
    Screen.Cursor:=crDefault;
    Busy:=False;
    RefreshAll;
  end;
end;

// Shows each client's line as soon as it is logged (about a second apart).
procedure TCaMainForm.LogLineAdded(Sender : TObject);
begin
  Log.SelStart:=Length(Log.Lines.Text);
  Log.Update;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCaMainForm.FormClose(Sender : TObject; var CloseAction : TCloseAction);
begin
  SaveSettings;
end;

procedure TCaMainForm.LoadSettings;
var
  R : TRegistry;
begin
  R:=TRegistry.Create;
  try
    R.RootKey:=HKEY_CURRENT_USER;
    if not R.OpenKeyReadOnly(RegKey) then Exit;
    if R.ValueExists('ClientFolder') then ClientEdit.Text:=R.ReadString('ClientFolder');
    if R.ValueExists('ArchiveFolder') then ArchiveEdit.Text:=R.ReadString('ArchiveFolder');
  finally
    R.Free;
  end;
end;

procedure TCaMainForm.SaveSettings;
var
  R : TRegistry;
begin
  R:=TRegistry.Create;
  try
    try
      R.RootKey:=HKEY_CURRENT_USER;
      if R.OpenKey(RegKey,True) then
      begin
        R.WriteString('ClientFolder',Trim(ClientEdit.Text));
        R.WriteString('ArchiveFolder',Trim(ArchiveEdit.Text));
      end;
    except
      // a setting that cannot be saved is not worth an error box
    end;
  finally
    R.Free;
  end;
end;

end.
