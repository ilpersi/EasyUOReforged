unit euwatch;

{
  Port addition (not present in the original app): the Watches panel, in the bottom panel between
  the call stack and the Output panel. EasyUO 1.42 had watches and showed how variables changed while
  stepping; the 1.5 source this port comes from had dropped both. What it lists, in what order, and
  what counts as changed is parser\EuoVarUsage.pas; this unit is the panel. MainForm (main.pas) gives
  it a parent panel and calls Poll from its timer. It is shown unless the user hid it (Control > Show
  Watches, kept in the registry as WatchesVisible).

  - The list has two columns, Name and Value. Its rows: a grey "Watches" row (with how many, or how to
    add one, in its Value column), the tab's watches in the order they were added, a grey "Script
    variables" row (with how many), then every variable the script uses: the
    ones written in it (EuoScriptVarNames, rescanned once the text has stayed the same for
    WatchQuietPolls polls, as the outline waits) and the % and ! variables the run has made
    (TEuoInterpreter.GetUserVarNames), in EuoMergeVarNames' order. Values come from TExecutor.GetVar,
    as the variable tree's do.
  - Changes: at each new pause of the tab's run -- a step, a breakpoint, the PAUSE command -- the rows
    whose value differs from the previous pause's show their name and value in red, and their hint gives the old
    value. TExecutor.RunNo and LinesRun tell a new pause from the same pause seen again, and a new run
    (nothing is red at its first pause). Red stays while a step runs and goes when the script plays on
    or stops. A watch added or a value set while paused goes into the baseline, so it does not turn red
    by itself.
  - Each editor's watches, and what the panel keeps for it, are in a TEuoWatchState the editor owns
    (as insthandler's TJumpHistory), so they go with the tab. LoadWatches / SaveWatches keep a saved
    script's list in the registry, under WatchesKey, one value per script: its full path as the value
    name (value names ignore case), the names separated by spaces as the data (EuoWatchesToText).
    \Software\EasyUO is left alone: the original EasyUO shares it.
  - The rows are updated in place, never cleared, so the list keeps its scroll position and does not
    flicker. The colours are set in OnCustomDrawItem (the Name column) and OnCustomDrawSubItem (the
    Value column): LCL's win32 list view hands Canvas.Font.Color to the control as the text colour
    (win32wscustomlistview.inc).
  - Right-click menu: Add Watch..., Watch (a script variable), Remove Watch, Clear Watches, Copy Name,
    Copy Value, Set Value... Keys: Insert adds, Delete removes, Enter or a double click sets the value.
  - Lists (the LIST command): while the run has any, a grey "Lists" row (with how many) and one row per
    list follow the script variables (TEuoInterpreter.GetListNames). A list row's value is its count and
    values, "3: iron | gold | agapite", cut at ListSummaryMax characters; it turns red like a variable,
    through the same TEuoVarChanges keyed ListKeyPrefix+name (a space, which no variable name holds).
    Enter, a double click or Edit Values... opens the MENU designer's lines dialog (eulinesdialog.pas):
    one value per line, and OK replaces the run's list (TEuoInterpreter.SetListValues) at any time, as
    Set Value does for a variable; empty lines at the end are dropped, and no lines forgets the list.
  - It holds the editor with FreeNotification, so closing a tab never leaves it a dead pointer; the
    tab's executor is freed together with its editor, so it is dropped at the same time.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, Menus, Graphics, Forms, LCLType,
  SynEdit, EuoExecutor, EuoVarUsage;

type
  TEuoWatchesChanged = procedure(Ed : TSynEdit) of object;

  TEuoWatchRowKind = (wrkHeader, wrkWatch, wrkScript, wrkList);

  // One editor's watches, and what the panel keeps for it. Owned by the editor.
  TEuoWatchState = class(TComponent)
  public
    Watches   : TStringList;     // in the order they were added
    Written   : TStringList;     // the variables written in the script
    Stamp     : Int64;           // the ChangeStamp Written was scanned from; -1 never
    SeenStamp : Int64;           // the last ChangeStamp Poll saw
    Quiet     : Integer;         // polls since SeenStamp changed
    Changes   : TEuoVarChanges;
    HaveRun   : Boolean;         // SeenRun/SeenLines are a run's
    SeenRun   : Cardinal;
    SeenLines : Cardinal;
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
  end;

  TEuoWatchView = class(TComponent)
  private
    FList      : TListView;
    FMenu      : TPopupMenu;
    FAddItem, FWatchItem, FRemoveItem, FClearItem,
    FCopyNameItem, FCopyValueItem, FSetItem, FEditItem : TMenuItem;
    FEd        : TSynEdit;
    FExec      : TExecutor;
    FSysNames  : TStringList;    // the interpreter's '#' names, without '#'
    FNames     : TStringList;    // the rows' names ('' for a grey row), Objects = the kind
    FValues    : TStringList;    // the rows' values
    FHeaders   : TStringList;    // the grey rows' Name text, by row (others '')
    FChangeSig : String;         // which rows were red when last drawn
    FOnWatchesChanged : TEuoWatchesChanged;
    procedure SetEditor(Ed : TSynEdit);
    function  State : TEuoWatchState;
    procedure ScanStatic(St : TEuoWatchState);
    procedure ShowRows;
    function  SelectedRow : Integer;
    procedure Changed(Ed : TSynEdit);
    procedure ListDrawItem(Sender : TCustomListView; Item : TListItem;
                State : TCustomDrawState; var DefaultDraw : Boolean);
    procedure ListDrawSubItem(Sender : TCustomListView; Item : TListItem; SubItem : Integer;
                State : TCustomDrawState; var DefaultDraw : Boolean);
    procedure ListShowHint(Sender : TObject; HintInfo : PHintInfo);
    procedure ListKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
    procedure ListDblClick(Sender : TObject);
    procedure ListResize(Sender : TObject);
    procedure MenuPopup(Sender : TObject);
    procedure AddClick(Sender : TObject);
    procedure WatchClick(Sender : TObject);
    procedure RemoveClick(Sender : TObject);
    procedure ClearClick(Sender : TObject);
    procedure CopyNameClick(Sender : TObject);
    procedure CopyValueClick(Sender : TObject);
    procedure SetClick(Sender : TObject);
    procedure EditListClick(Sender : TObject);
    function  ListSummary(const Name : String) : String;
  protected
    procedure Notification(AComponent : TComponent; Operation : TOperation); override;
  public
    constructor Create(AOwner : TComponent; AParent : TWinControl); reintroduce;
    destructor  Destroy; override;
    // From the timer: follows Ed's text and Exec's run (see the header).
    procedure Poll(Ed : TSynEdit; Exec : TExecutor);
    // Rescans Ed's text and reads every value now.
    procedure Refresh(Ed : TSynEdit; Exec : TExecutor);
    // Adds Name (trimmed) to Ed's watches. False, and nothing added, when Name is not one variable
    // name; True when it is, also when it was a watch already.
    function  AddWatch(Ed : TSynEdit; const Name : String) : Boolean;
    procedure RemoveWatch(Ed : TSynEdit; const Name : String);
    procedure ClearWatches(Ed : TSynEdit);
    // Asks for a name and adds it; Default is the text offered. True when a watch was added
    // (or was one already).
    function  AskAndAddWatch(Ed : TSynEdit; const Default : String) : Boolean;
    // Sets the variable of row Row to Value in the tab's run, as Set Value does.
    procedure SetRowValue(Row : Integer; const Value : String);
    // The rows (see the header).
    function  RowCount : Integer;
    function  RowKind(Row : Integer) : TEuoWatchRowKind;
    function  RowName(Row : Integer) : String;     // '' for a grey row
    function  RowValue(Row : Integer) : String;
    function  RowText(Row : Integer) : String;     // what the Name column shows
    function  RowChanged(Row : Integer; out Old : String) : Boolean;
    function  RowHint(Row : Integer) : String;
    // The name the change logic knows row Row by: the variable, or ListKeyPrefix+name for a list.
    function  RowKey(Row : Integer) : String;
    // Replaces the values of the list of row Row in the tab's run, as Edit Values does after OK.
    procedure SetRowList(Row : Integer; Values : TStrings);
    property List   : TListView read FList;
    property Editor : TSynEdit read FEd;
    property OnWatchesChanged : TEuoWatchesChanged read FOnWatchesChanged write FOnWatchesChanged;
  end;

// Ed's watches (its TEuoWatchState, made on first use).
function  WatchStateOf(Ed : TSynEdit) : TEuoWatchState;
// Ed's watches from / to the registry, for the script saved at Path (see the header).
procedure LoadWatches(Ed : TSynEdit; const Path : String);
procedure SaveWatches(Ed : TSynEdit; const Path : String);

const
  WatchesKey      = '\Software\EasyUO Reforged\Watches';
  WatchQuietPolls = 2;   // polls (200 ms each) the text stays the same before a rescan
  ListKeyPrefix   = 'list ';
  ListSummaryMax  = 200;

implementation

uses
  Registry, Clipbrd, Dialogs, EuoScriptWords, eulinesdialog;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoWatchState.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  Watches:=TStringList.Create;
  Written:=TStringList.Create;
  Stamp:=-1;
  SeenStamp:=-1;
  Changes:=TEuoVarChanges.Create;
end;

destructor TEuoWatchState.Destroy;
begin
  Changes.Free;
  Written.Free;
  Watches.Free;
  inherited;
end;

////////////////////////////////////////////////////////////////////////////////
function WatchStateOf(Ed : TSynEdit) : TEuoWatchState;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Ed.ComponentCount-1 do
    if Ed.Components[Cnt] is TEuoWatchState then
  begin
    Result:=TEuoWatchState(Ed.Components[Cnt]);
    Exit;
  end;
  Result:=TEuoWatchState.Create(Ed);
end;

////////////////////////////////////////////////////////////////////////////////
procedure LoadWatches(Ed : TSynEdit; const Path : String);
var
  R : TRegistry;
  S : String;
  St : TEuoWatchState;
begin
  if Path='' then Exit;
  S:='';
  R:=TRegistry.Create;
  try
    if R.OpenKeyReadOnly(WatchesKey) then
      if R.GetDataType(ExpandFileName(Path))=rdString then
        S:=R.ReadString(ExpandFileName(Path));
  except
    S:='';
  end;
  R.Free;
  St:=WatchStateOf(Ed);
  St.Watches.Clear;
  EuoWatchesFromText(S,St.Watches);
end;

////////////////////////////////////////////////////////////////////////////////
procedure SaveWatches(Ed : TSynEdit; const Path : String);
var
  R  : TRegistry;
  St : TEuoWatchState;
begin
  if Path='' then Exit;
  St:=WatchStateOf(Ed);
  R:=TRegistry.Create;
  try
    try
      if St.Watches.Count=0 then
      begin
        if R.OpenKey(WatchesKey,False) then
          if R.ValueExists(ExpandFileName(Path)) then
            R.DeleteValue(ExpandFileName(Path));
      end
      else if R.OpenKey(WatchesKey,True) then
        R.WriteString(ExpandFileName(Path),EuoWatchesToText(St.Watches));
    except
      // a registry that cannot be written loses the list at the next start, nothing more
    end;
  finally
    R.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function IndexOfText(List : TStrings; const S : String) : Integer;
begin
  for Result:=0 to List.Count-1 do
    if CompareText(List[Result],S)=0 then Exit;
  Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoWatchView //////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoWatchView.Create(AOwner : TComponent; AParent : TWinControl);

  function AddItem(const Caption : String; Handler : TNotifyEvent) : TMenuItem;
  begin
    Result:=TMenuItem.Create(Self);
    Result.Caption:=Caption;
    Result.OnClick:=Handler;
    FMenu.Items.Add(Result);
  end;

var
  Col : TListColumn;
begin
  inherited Create(AOwner);
  FSysNames:=TStringList.Create;
  FNames:=TStringList.Create;
  FValues:=TStringList.Create;
  FHeaders:=TStringList.Create;

  FMenu:=TPopupMenu.Create(Self);
  FMenu.OnPopup:=MenuPopup;
  FAddItem:=AddItem('&Add Watch...',AddClick);
  FWatchItem:=AddItem('&Watch',WatchClick);
  FRemoveItem:=AddItem('&Remove Watch',RemoveClick);
  FClearItem:=AddItem('C&lear Watches',ClearClick);
  AddItem('-',nil);
  FCopyNameItem:=AddItem('Copy &Name',CopyNameClick);
  FCopyValueItem:=AddItem('Copy &Value',CopyValueClick);
  FSetItem:=AddItem('&Set Value...',SetClick);
  FEditItem:=AddItem('&Edit Values...',EditListClick);

  FList:=TListView.Create(Self);
  FList.Parent:=AParent;
  FList.Align:=alClient;
  FList.ViewStyle:=vsReport;
  FList.ReadOnly:=True;
  FList.RowSelect:=True;
  FList.HideSelection:=False;
  FList.ToolTips:=False;
  FList.ShowHint:=True;
  FList.PopupMenu:=FMenu;
  Col:=FList.Columns.Add;
  Col.Caption:='Name';
  Col.Width:=140;
  Col:=FList.Columns.Add;
  Col.Caption:='Value';
  Col.Width:=200;
  FList.OnCustomDrawItem:=ListDrawItem;
  FList.OnCustomDrawSubItem:=ListDrawSubItem;
  FList.OnShowHint:=ListShowHint;
  FList.OnKeyDown:=ListKeyDown;
  FList.OnDblClick:=ListDblClick;
  FList.OnResize:=ListResize;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TEuoWatchView.Destroy;
begin
  SetEditor(nil);
  FHeaders.Free;
  FValues.Free;
  FNames.Free;
  FSysNames.Free;
  inherited;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.Notification(AComponent : TComponent; Operation : TOperation);
begin
  inherited;
  if (Operation=opRemove) and (AComponent=FEd) then
  begin
    FEd:=nil;
    FExec:=nil;
    FNames.Clear;
    FValues.Clear;
    FHeaders.Clear;
    if not (csDestroying in ComponentState) then
      FList.Items.Clear;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.SetEditor(Ed : TSynEdit);
begin
  if Ed=FEd then Exit;
  if FEd<>nil then FEd.RemoveFreeNotification(Self);
  FEd:=Ed;
  if FEd<>nil then FEd.FreeNotification(Self);
  FChangeSig:='';
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchView.State : TEuoWatchState;
begin
  Result:=WatchStateOf(FEd);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ScanStatic(St : TEuoWatchState);
begin
  if (FSysNames.Count=0) and (FExec<>nil) then
    FExec.Parser.GetVariableNames(FSysNames);
  St.Written.Clear;
  if FSysNames.Count>0 then EuoScriptVarNames(FEd.Lines,FSysNames,St.Written)
  else EuoScriptVarNames(FEd.Lines,nil,St.Written);
  St.Stamp:=FEd.ChangeStamp;
  St.SeenStamp:=St.Stamp;
  St.Quiet:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.Poll(Ed : TSynEdit; Exec : TExecutor);
var
  St : TEuoWatchState;
  S  : Int64;
begin
  if Ed<>FEd then
  begin
    Refresh(Ed,Exec);
    Exit;
  end;
  FExec:=Exec;
  if FEd=nil then Exit;

  St:=State;
  S:=FEd.ChangeStamp;
  if (St.Stamp=-1) then ScanStatic(St)
  else if S<>St.Stamp then
  begin
    if S<>St.SeenStamp then
    begin
      St.SeenStamp:=S;
      St.Quiet:=0;
    end
    else Inc(St.Quiet);
    if St.Quiet>=WatchQuietPolls then ScanStatic(St);
  end;
  ShowRows;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.Refresh(Ed : TSynEdit; Exec : TExecutor);
begin
  SetEditor(Ed);
  FExec:=Exec;
  if FEd=nil then
  begin
    FNames.Clear;
    FValues.Clear;
    FHeaders.Clear;
    FList.Items.Clear;
    Exit;
  end;
  ScanStatic(State);
  ShowRows;
end;

////////////////////////////////////////////////////////////////////////////////
// Builds the rows, reads the values, runs the change logic (see the header), and shows them.
procedure TEuoWatchView.ShowRows;
var
  St       : TEuoWatchState;
  Runtime  : TStringList;
  Script   : TStringList;
  Names    : TStringList;   // every variable once, for the change logic
  Values   : TStringList;
  Details  : TStringList;   // the grey rows' Value text, by row
  Cnt, i   : Integer;
  SelName  : String;
  SelKind  : TObject;
  Sel      : Integer;
  Sig, Old : String;
  Item     : TListItem;
  Text     : String;
  Grow     : Boolean;
  Lists    : TStringList;
  Key      : String;

  procedure AddRow(Kind : TEuoWatchRowKind; const Name, Header : String; const Detail : String = '');
  begin
    FNames.AddObject(Name,TObject(PtrUInt(Ord(Kind))));
    FHeaders.Add(Header);
    Details.Add(Detail);
  end;

begin
  St:=State;

  Sel:=SelectedRow;
  SelName:='';
  SelKind:=nil;
  if Sel>=0 then
  begin
    SelName:=FNames[Sel];
    SelKind:=FNames.Objects[Sel];
  end;

  Runtime:=TStringList.Create;
  Script:=TStringList.Create;
  Names:=TStringList.Create;
  Values:=TStringList.Create;
  Details:=TStringList.Create;
  Lists:=TStringList.Create;
  try
    if FExec<>nil then FExec.Parser.GetUserVarNames(Runtime);
    EuoMergeVarNames(St.Written,Runtime,Script);

    FNames.Clear;
    FHeaders.Clear;
    if St.Watches.Count=0 then
      AddRow(wrkHeader,'','Watches','none: Ctrl+F5 adds the variable at the cursor')
    else AddRow(wrkHeader,'','Watches',IntToStr(St.Watches.Count));
    for Cnt:=0 to St.Watches.Count-1 do
      AddRow(wrkWatch,St.Watches[Cnt],'');
    AddRow(wrkHeader,'','Script variables',IntToStr(Script.Count));
    for Cnt:=0 to Script.Count-1 do
      AddRow(wrkScript,Script[Cnt],'');
    if FExec<>nil then FExec.Parser.GetListNames(Lists);
    if Lists.Count>0 then
    begin
      AddRow(wrkHeader,'','Lists',IntToStr(Lists.Count));
      for Cnt:=0 to Lists.Count-1 do
        AddRow(wrkList,Lists[Cnt],'');
    end;

    // values, each variable read once; a grey row shows its detail
    FValues.Clear;
    for Cnt:=0 to FNames.Count-1 do
    begin
      if FNames[Cnt]='' then
      begin
        FValues.Add(Details[Cnt]);
        Continue;
      end;
      Key:=RowKey(Cnt);
      i:=IndexOfText(Names,Key);
      if i>=0 then
      begin
        FValues.Add(Values[i]);
        Continue;
      end;
      if FExec=nil then Text:=EuoUnsetValue
      else if RowKind(Cnt)=wrkList then Text:=ListSummary(FNames[Cnt])
      else Text:=FExec.GetVar(FNames[Cnt]);
      Names.Add(Key);
      Values.Add(Text);
      FValues.Add(Text);
    end;

    // the change logic
    if FExec<>nil then
    begin
      if (FExec.State=PAUSE) and FExec.Paused then
      begin
        if (not St.HaveRun) or (St.SeenRun<>FExec.RunNo) then
        begin
          St.Changes.NewRun(Names,Values);
          St.HaveRun:=True;
          St.SeenRun:=FExec.RunNo;
          St.SeenLines:=FExec.LinesRun;
        end
        else if St.SeenLines<>FExec.LinesRun then
        begin
          St.Changes.NewPause(Names,Values);
          St.SeenLines:=FExec.LinesRun;
        end;
      end
      else if FExec.State in [PLAY,STOP] then
        St.Changes.ClearChanges;
    end;
  finally
    Lists.Free;
    Details.Free;
    Values.Free;
    Names.Free;
    Script.Free;
    Runtime.Free;
  end;

  // the list, updated in place
  Sig:='';
  Grow:=FList.Items.Count<>FNames.Count;
  if Grow then FList.Items.BeginUpdate;
  try
    while FList.Items.Count<FNames.Count do
    begin
      Item:=FList.Items.Add;
      Item.SubItems.Add('');
    end;
    while FList.Items.Count>FNames.Count do
      FList.Items.Delete(FList.Items.Count-1);
    for Cnt:=0 to FNames.Count-1 do
    begin
      Item:=FList.Items[Cnt];
      Text:=RowText(Cnt);
      if Item.Caption<>Text then Item.Caption:=Text;
      if Item.SubItems.Count=0 then Item.SubItems.Add('');
      if Item.SubItems[0]<>FValues[Cnt] then Item.SubItems[0]:=FValues[Cnt];
      if RowChanged(Cnt,Old) then Sig:=Sig+IntToStr(Cnt)+',';
    end;
  finally
    if Grow then FList.Items.EndUpdate;
  end;

  // the selected row follows its variable
  if Sel>=0 then
  begin
    i:=-1;
    for Cnt:=0 to FNames.Count-1 do
      if (FNames.Objects[Cnt]=SelKind) and (CompareText(FNames[Cnt],SelName)=0) then
      begin
        i:=Cnt;
        Break;
      end;
    if (i>=0) and (i<>Sel) then FList.Selected:=FList.Items[i];
  end;

  if Sig<>FChangeSig then
  begin
    FChangeSig:=Sig;
    FList.Invalidate;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchView.RowCount : Integer;
begin
  Result:=FNames.Count;
end;

function TEuoWatchView.RowKind(Row : Integer) : TEuoWatchRowKind;
begin
  Result:=TEuoWatchRowKind(PtrUInt(FNames.Objects[Row]));
end;

function TEuoWatchView.RowName(Row : Integer) : String;
begin
  Result:=FNames[Row];
end;

function TEuoWatchView.RowValue(Row : Integer) : String;
begin
  Result:=FValues[Row];
end;

function TEuoWatchView.RowText(Row : Integer) : String;
begin
  if RowKind(Row)=wrkHeader then Result:=FHeaders[Row]
  else Result:=FNames[Row];
end;

function TEuoWatchView.RowChanged(Row : Integer; out Old : String) : Boolean;
begin
  Old:='';
  Result:=False;
  if (FEd=nil) or (Row<0) or (Row>=FNames.Count) or (RowKind(Row)=wrkHeader) then Exit;
  Result:=State.Changes.IsChanged(RowKey(Row),Old);
end;

function TEuoWatchView.RowKey(Row : Integer) : String;
begin
  if RowKind(Row)=wrkList then Result:=ListKeyPrefix+FNames[Row]
  else Result:=FNames[Row];
end;

function TEuoWatchView.RowHint(Row : Integer) : String;
var
  Old : String;
begin
  Result:='';
  if (Row<0) or (Row>=FNames.Count) or (RowKind(Row)=wrkHeader) then Exit;
  if RowChanged(Row,Old) then Result:='Was: '+Old+LineEnding+'Now: '+FValues[Row]
  else if RowKind(Row)=wrkList then Result:='List '+FNames[Row]+': '+FValues[Row]+LineEnding+
    'Enter or a double click edits its values.'
  else Result:=FNames[Row]+': '+FValues[Row];
end;

////////////////////////////////////////////////////////////////////////////////
// A list row's value: "3: iron | gold | agapite", cut at ListSummaryMax characters.
function TEuoWatchView.ListSummary(const Name : String) : String;
var
  V   : TStringList;
  Cnt : Integer;
begin
  V:=TStringList.Create;
  try
    FExec.Parser.GetListValues(Name,V);
    Result:=IntToStr(V.Count)+':';
    for Cnt:=0 to V.Count-1 do
    begin
      if Cnt>0 then Result:=Result+' |';
      Result:=Result+' '+V[Cnt];
      if Length(Result)>ListSummaryMax then
      begin
        Result:=Copy(Result,1,ListSummaryMax)+#$E2#$80#$A6;   // UTF-8 ellipsis
        Break;
      end;
    end;
  finally
    V.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchView.SelectedRow : Integer;
begin
  Result:=-1;
  if FList.Selected<>nil then Result:=FList.Selected.Index;
  if Result>=FNames.Count then Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.Changed(Ed : TSynEdit);
begin
  if Assigned(FOnWatchesChanged) then FOnWatchesChanged(Ed);
  if (Ed=FEd) and (FEd<>nil) then ShowRows;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchView.AddWatch(Ed : TSynEdit; const Name : String) : Boolean;
var
  St : TEuoWatchState;
  N  : String;
begin
  N:=Trim(Name);
  Result:=IsVar(N);
  if not Result or (Ed=nil) then Exit;
  St:=WatchStateOf(Ed);
  if IndexOfText(St.Watches,N)>=0 then Exit;
  St.Watches.Add(N);
  // already in the baseline when the script uses it; otherwise its value now goes in
  if (Ed=FEd) and (FExec<>nil) and (IndexOfText(FNames,N)<0) then
    St.Changes.Remember(N,FExec.GetVar(N));
  Changed(Ed);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.RemoveWatch(Ed : TSynEdit; const Name : String);
var
  St : TEuoWatchState;
  i  : Integer;
begin
  if Ed=nil then Exit;
  St:=WatchStateOf(Ed);
  i:=IndexOfText(St.Watches,Name);
  if i<0 then Exit;
  St.Watches.Delete(i);
  Changed(Ed);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ClearWatches(Ed : TSynEdit);
var
  St : TEuoWatchState;
begin
  if Ed=nil then Exit;
  St:=WatchStateOf(Ed);
  if St.Watches.Count=0 then Exit;
  St.Watches.Clear;
  Changed(Ed);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchView.AskAndAddWatch(Ed : TSynEdit; const Default : String) : Boolean;
var
  S : String;
begin
  Result:=False;
  if Ed=nil then Exit;
  S:=Default;
  if not InputQuery('Add Watch','Variable (%name, !name, *name or #name):',S) then Exit;
  if Trim(S)='' then Exit;
  Result:=AddWatch(Ed,S);
  if not Result then
    ShowMessage('"'+Trim(S)+'" is not a variable name. A watch is one variable: '+
      '%name, !name, *name or #name.');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.SetRowValue(Row : Integer; const Value : String);
begin
  if (FExec=nil) or (FEd=nil) or (Row<0) or (Row>=FNames.Count) or (RowKind(Row) in [wrkHeader,wrkList]) then
    Exit;
  FExec.SetVar(FNames[Row],Value);
  State.Changes.Remember(FNames[Row],FExec.GetVar(FNames[Row]));
  ShowRows;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.SetRowList(Row : Integer; Values : TStrings);
var
  L : TStringList;
begin
  if (FExec=nil) or (FEd=nil) or (Row<0) or (Row>=FNames.Count) or (RowKind(Row)<>wrkList) then Exit;
  L:=TStringList.Create;
  try
    L.Assign(Values);
    while (L.Count>0) and (L[L.Count-1]='') do L.Delete(L.Count-1);
    FExec.Parser.SetListValues(FNames[Row],L);
  finally
    L.Free;
  end;
  State.Changes.Remember(RowKey(Row),ListSummary(FNames[Row]));
  ShowRows;
end;

////////////////////////////////////////////////////////////////////////////////
// The Name column: grey for a grey row, red (as its value) for a row that changed.
procedure TEuoWatchView.ListDrawItem(Sender : TCustomListView; Item : TListItem;
  State : TCustomDrawState; var DefaultDraw : Boolean);
var
  Old : String;
begin
  DefaultDraw:=True;
  if (Item.Index<FNames.Count) and (RowKind(Item.Index)=wrkHeader) then
    Sender.Canvas.Font.Color:=clGrayText
  else if RowChanged(Item.Index,Old) then
    Sender.Canvas.Font.Color:=clRed;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ListDrawSubItem(Sender : TCustomListView; Item : TListItem;
  SubItem : Integer; State : TCustomDrawState; var DefaultDraw : Boolean);
var
  Old : String;
begin
  DefaultDraw:=True;
  if (Item.Index<FNames.Count) and (RowKind(Item.Index)=wrkHeader) then
    Sender.Canvas.Font.Color:=clGrayText
  else if (SubItem=1) and RowChanged(Item.Index,Old) then
    Sender.Canvas.Font.Color:=clRed;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ListShowHint(Sender : TObject; HintInfo : PHintInfo);
var
  Item : TListItem;
begin
  HintInfo^.HintStr:='';
  Item:=FList.GetItemAt(HintInfo^.CursorPos.X,HintInfo^.CursorPos.Y);
  if Item=nil then Exit;
  HintInfo^.HintStr:=RowHint(Item.Index);
  HintInfo^.CursorRect:=Item.DisplayRect(drBounds);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ListKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
begin
  if Shift<>[] then Exit;
  case Key of
    VK_DELETE : RemoveClick(nil);
    VK_INSERT : AddClick(nil);
    VK_RETURN : SetClick(nil);
  else
    Exit;
  end;
  Key:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ListDblClick(Sender : TObject);
begin
  SetClick(nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.ListResize(Sender : TObject);
var
  W : Integer;
begin
  if FList.Columns.Count<2 then Exit;
  W:=FList.ClientWidth-FList.Columns[0].Width-4;
  if W<60 then W:=60;
  FList.Columns[1].Width:=W;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.MenuPopup(Sender : TObject);
var
  Row  : Integer;
  Kind : TEuoWatchRowKind;
begin
  Row:=SelectedRow;
  if Row>=0 then Kind:=RowKind(Row) else Kind:=wrkHeader;
  FAddItem.Enabled:=FEd<>nil;
  FWatchItem.Visible:=Kind=wrkScript;
  FWatchItem.Enabled:=(Kind=wrkScript) and (IndexOfText(State.Watches,FNames[Row])<0);
  FRemoveItem.Enabled:=Kind=wrkWatch;
  FClearItem.Enabled:=(FEd<>nil) and (State.Watches.Count>0);
  FCopyNameItem.Enabled:=Kind<>wrkHeader;
  FCopyValueItem.Enabled:=Kind<>wrkHeader;
  FSetItem.Visible:=Kind<>wrkList;
  FSetItem.Enabled:=(Kind<>wrkHeader) and (FExec<>nil);
  FEditItem.Visible:=Kind=wrkList;
  FEditItem.Enabled:=(Kind=wrkList) and (FExec<>nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchView.AddClick(Sender : TObject);
var
  Row : Integer;
  Def : String;
begin
  Def:='';
  Row:=SelectedRow;
  if (Row>=0) and (RowKind(Row)=wrkScript) then Def:=FNames[Row];
  AskAndAddWatch(FEd,Def);
end;

procedure TEuoWatchView.WatchClick(Sender : TObject);
var
  Row : Integer;
begin
  Row:=SelectedRow;
  if (Row>=0) and (RowKind(Row)=wrkScript) then AddWatch(FEd,FNames[Row]);
end;

procedure TEuoWatchView.RemoveClick(Sender : TObject);
var
  Row : Integer;
begin
  Row:=SelectedRow;
  if (Row>=0) and (RowKind(Row)=wrkWatch) then RemoveWatch(FEd,FNames[Row]);
end;

procedure TEuoWatchView.ClearClick(Sender : TObject);
begin
  ClearWatches(FEd);
end;

procedure TEuoWatchView.CopyNameClick(Sender : TObject);
var
  Row : Integer;
begin
  Row:=SelectedRow;
  if (Row>=0) and (RowKind(Row)<>wrkHeader) then Clipboard.AsText:=FNames[Row];
end;

procedure TEuoWatchView.CopyValueClick(Sender : TObject);
var
  Row : Integer;
begin
  Row:=SelectedRow;
  if (Row>=0) and (RowKind(Row)<>wrkHeader) then Clipboard.AsText:=FValues[Row];
end;

procedure TEuoWatchView.SetClick(Sender : TObject);
var
  Row : Integer;
  S   : String;
begin
  Row:=SelectedRow;
  if (Row<0) or (RowKind(Row)=wrkHeader) or (FExec=nil) then Exit;
  if RowKind(Row)=wrkList then
  begin
    EditListClick(Sender);
    Exit;
  end;
  S:=FValues[Row];
  if InputQuery('Set Variable',FNames[Row]+':',S) then SetRowValue(Row,S);
end;

procedure TEuoWatchView.EditListClick(Sender : TObject);
var
  Row  : Integer;
  Name : String;
  L    : TStringList;
begin
  Row:=SelectedRow;
  if (Row<0) or (RowKind(Row)<>wrkList) or (FExec=nil) then Exit;
  Name:=FNames[Row];
  L:=TStringList.Create;
  try
    FExec.Parser.GetListValues(Name,L);
    if not EditLines('Values of list '+Name,'One value per line, in order.',L) then Exit;
    // the rows may have moved while the dialog was open: find the list's row again
    Row:=FNames.Count-1;
    while (Row>=0) and not ((RowKind(Row)=wrkList) and (CompareText(FNames[Row],Name)=0)) do Dec(Row);
    if Row>=0 then SetRowList(Row,L)
    else begin
      FExec.Parser.SetListValues(Name,L);   // the script forgot it meanwhile: it comes back
      ShowRows;
    end;
  finally
    L.Free;
  end;
end;

end.
