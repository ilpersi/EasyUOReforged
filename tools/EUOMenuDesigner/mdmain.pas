unit mdmain;

{
  Port addition: the MENU Designer's main window (docs/menu-designer.md, section 9), built
  entirely in code like easyuo\main.pas -- there is no .lfm.

  Left: the palette (one button per row of MdTypeRows) and the structure tree. Centre: one tab
  per form, each a TMdFormView hosting the form as TMdEngine builds it. Right: the inspector.
  Bottom: the script (TSynEdit with the editor's own highlighter, TSynEUOSyn) and the
  messages. Every change to the model goes through BeforeChange (an undo snapshot) and
  AfterChange (the form built again, the script written again, the views refreshed).
}

{$mode delphi}{$H+}

interface
uses
  Windows, SysUtils, Classes, Math, Graphics, Controls, Forms, Dialogs, Menus, ComCtrls, ExtCtrls,
  StdCtrls, Buttons, Clipbrd, LCLIntf, LCLType, Registry, SynEdit, SynEditTypes, ReforgedVersion,
  eufoldsyn,
  mainicons, mdicons, mdtypes, mdmodel, mdgenerate, mdimport, mdfile, mdengine, mdcanvas, mdgeometry,
  mdinspector;

type
  TMdMainForm = class(TForm)
  private
    MainMenu    : TMainMenu;
    Images      : TImageList;    // the menu's and the toolbar's icons (mdicons)
    PaletteImgs : TImageList;    // the palette's
    ToolBar     : TToolBar;
    StatusBar   : TStatusBar;
    LeftPanel   : TPanel;
    Palette     : TPanel;
    Tree        : TTreeView;
    Pages       : TPageControl;
    Inspector   : TMdInspector;
    BottomPanel : TPanel;
    Syn         : TSynEdit;
    SynHilite   : TSynEUOSyn;
    SynHeader   : TLabel;
    Messages    : TListBox;
    Timer       : TTimer;
    PreviewBtn  : TToolButton;
    GridItem    : TMenuItem;
    SnapGridItem: TMenuItem;
    SnapEdgeItem: TMenuItem;
    PreviewItem : TMenuItem;

    Doc         : TMdDocument;
    Engine      : TMdEngine;
    Sel         : TList;
    Views       : TList;
    UndoStack   : TList;
    RedoStack   : TList;
    FileName    : String;
    Modified    : Boolean;
    Foreign     : TStringList;   // the loaded file's lines a save would delete
    Dropped     : Integer;       // the loaded file's MENU lines the importer left out
    LoadReport  : TStringList;
    ShowsSource : Boolean;       // the script pane shows the text as loaded, not as generated
    Preview     : TMdPreview;
    Snap        : TMdSnap;
    ShowGrid    : Boolean;
    Updating    : Boolean;

    function    AddMenu(Parent : TMenuItem; ATag : Integer; const ACaption : String;
                  AShortCut : TShortCut = 0) : TMenuItem;
    procedure   AddTool(ATag : Integer; const ACaption, AHint : String);
    procedure   BuildComponents;
    procedure   BuildPalette;
    procedure   MenuHandlerProc(Sender : TObject);
    procedure   MenuQueued(Data : PtrInt);
    procedure   MenuHandler(Tag : Integer);
    procedure   PaletteClick(Sender : TObject);
    procedure   ViewPlaced(Sender : TObject);
    procedure   ViewSelect(Sender : TObject);
    procedure   PageChange(Sender : TObject);
    procedure   TreeChange(Sender : TObject; Node : TTreeNode);
    procedure   TreeDragOver(Sender, Source : TObject; X, Y : Integer; State : TDragState;
                  var Accept : Boolean);
    procedure   TreeDragDrop(Sender, Source : TObject; X, Y : Integer);
    procedure   MessagesDblClick(Sender : TObject);
    procedure   SynChange(Sender : TObject);
    procedure   TimerTick(Sender : TObject);
    procedure   ShowMessageText(const S : String);
    procedure   FormCloseQuery(Sender : TObject; var CanClose : Boolean);
    procedure   FormKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);

    procedure   BeforeChange(Sender : TObject);
    procedure   ClearHistory;
    procedure   AfterChange(F : TMdComponent);
    procedure   SetDocument(NewDoc : TMdDocument);
    procedure   RebuildTabs;
    procedure   RebuildTree;
    procedure   RefreshViews;
    procedure   SelectionChanged;
    procedure   WriteScript;
    procedure   ShowWarnings;
    procedure   UpdateTitle;
    procedure   UpdateStatus;
    function    ActiveView : TMdFormView;
    function    ViewOf(F : TMdComponent) : TMdFormView;
    function    ConfirmDiscard : Boolean;
    procedure   LoadText(Lines : TStrings; const FromFile : String);
    procedure   DoNew;
    procedure   DoOpen;
    function    DoSave(AskName : Boolean) : Boolean;
    procedure   DoPaste;
    procedure   DoApply;
    procedure   DoUndo(Redo : Boolean);
    procedure   DoDelete;
    procedure   DoAlign(Op : TMdAlignOp);
    procedure   DoZOrder(Front : Boolean);
    procedure   DoNewForm;
    procedure   DoMoveForm(Delta : Integer);
    procedure   DoGridSize;
    procedure   TogglePreview;
    procedure   LoadSettings;
    procedure   SaveSettings;
  public
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
  end;

var
  MdMainForm : TMdMainForm;

implementation

const
  TAG_NEW = 1; TAG_OPEN = 2; TAG_SAVE = 3; TAG_SAVEAS = 4; TAG_PASTE = 5; TAG_EXIT = 6;
  TAG_UNDO = 10; TAG_REDO = 11; TAG_DELETE = 12; TAG_SELALL = 13;
  TAG_NEWFORM = 20; TAG_DELFORM = 21; TAG_FORMLEFT = 22; TAG_FORMRIGHT = 23;
  TAG_ALIGN = 30;   // + Ord(TMdAlignOp)
  TAG_FRONT = 50; TAG_BACK = 51;
  TAG_GRID = 60; TAG_SNAPGRID = 61; TAG_SNAPEDGE = 62; TAG_GRIDSIZE = 63; TAG_PREVIEW = 64;
  TAG_HELP = 70; TAG_ABOUT = 71;
  TAG_APPLY = 80;

  MaxUndo  = 100;
  DocsUrl  = 'https://ilpersi.github.io/EasyUOReforged/designer/';
  RegKey   = '\Software\EasyUO Reforged\MENU Designer';

  AlignCaptions : array[TMdAlignOp] of String = ('Align &left edges', 'Align &right edges',
    'Align &top edges', 'Align &bottom edges', 'Align &centres across', 'Align centres &down',
    'Centre in parent across', 'Centre in parent down', '&Spread across', 'Spread &down',
    'Same &width', 'Same &height', 'Same si&ze');

// A command's icon in mdicons (-1: none). The View toggles have none, so their check shows.
function TagIcon(ATag : Integer) : Integer;
begin
  case ATag of
    TAG_NEW      : Result:=Ord(icNewDesign);
    TAG_OPEN     : Result:=Ord(icOpen);
    TAG_SAVE     : Result:=Ord(icSave);
    TAG_SAVEAS   : Result:=Ord(icSaveAs);
    TAG_PASTE    : Result:=Ord(icPaste);
    TAG_EXIT     : Result:=Ord(icExit);
    TAG_UNDO     : Result:=Ord(icUndo);
    TAG_REDO     : Result:=Ord(icRedo);
    TAG_DELETE   : Result:=Ord(icDelete);
    TAG_SELALL   : Result:=Ord(icSelectAll);
    TAG_NEWFORM  : Result:=Ord(icNewForm);
    TAG_DELFORM  : Result:=Ord(icDeleteForm);
    TAG_FORMLEFT : Result:=Ord(icMoveLeft);
    TAG_FORMRIGHT: Result:=Ord(icMoveRight);
    TAG_ALIGN..TAG_ALIGN+Ord(High(TMdAlignOp)) :
                   Result:=Ord(icAlignLeft)+ATag-TAG_ALIGN;   // in TMdAlignOp's order
    TAG_FRONT    : Result:=Ord(icFront);
    TAG_BACK     : Result:=Ord(icBack);
    TAG_GRIDSIZE : Result:=Ord(icGridSize);
    TAG_PREVIEW  : Result:=Ord(icPreview);
    TAG_HELP     : Result:=Ord(icHelp);
    TAG_ABOUT    : Result:=Ord(icAbout);
  else             Result:=-1;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TMdMainForm.Create(AOwner : TComponent);
var
  Ico : TIcon;
begin
  inherited CreateNew(AOwner);
  Left:=120;
  Top:=80;
  Width:=1200;
  Height:=780;
  Position:=poScreenCenter;
  KeyPreview:=True;
  OnCloseQuery:=FormCloseQuery;
  OnKeyDown:=FormKeyDown;
  Ico:=LoadAppIcon;
  try
    Icon.Assign(Ico);
  finally
    Ico.Free;
  end;
  Sel:=TList.Create;
  Views:=TList.Create;
  UndoStack:=TList.Create;
  RedoStack:=TList.Create;
  Foreign:=TStringList.Create;
  LoadReport:=TStringList.Create;
  Snap:=DefaultSnap;
  ShowGrid:=True;
  LoadSettings;
  BuildComponents;
  Engine:=TMdEngine.Create;
  SetDocument(TMdDocument.Create);
  Modified:=False;
  if (ParamCount>0) and FileExists(ParamStr(1)) then
  begin
    FileName:=ExpandFileName(ParamStr(1));
    Foreign.Clear;
    LoadReport.Clear;
    LoadText(nil,FileName);
  end;
  UpdateTitle;
end;

destructor TMdMainForm.Destroy;
var
  Cnt : Integer;
begin
  Application.RemoveAsyncCalls(Self);
  Preview.Free;
  for Cnt:=0 to UndoStack.Count-1 do TObject(UndoStack[Cnt]).Free;
  for Cnt:=0 to RedoStack.Count-1 do TObject(RedoStack[Cnt]).Free;
  UndoStack.Free;
  RedoStack.Free;
  inherited Destroy;   // the views go with their tabs, before the engine frees the forms
  Engine.Free;
  Doc.Free;
  Views.Free;
  Sel.Free;
  Foreign.Free;
  LoadReport.Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TMdMainForm.AddMenu(Parent : TMenuItem; ATag : Integer; const ACaption : String;
  AShortCut : TShortCut) : TMenuItem;
begin
  Result:=TMenuItem.Create(Self);
  Result.Caption:=ACaption;
  Result.Tag:=ATag;
  Result.ShortCut:=AShortCut;
  Result.ImageIndex:=TagIcon(ATag);
  if ATag<>0 then Result.OnClick:=MenuHandlerProc;
  Parent.Add(Result);
end;

procedure TMdMainForm.AddTool(ATag : Integer; const ACaption, AHint : String);
var
  B : TToolButton;
begin
  B:=TToolButton.Create(Self);
  B.Parent:=ToolBar;
  B.Left:=ToolBar.Width;   // LCL appends a button placed past the last one
  if ATag<0 then
  begin
    B.Style:=tbsSeparator;
    B.Width:=8;
    Exit;
  end;
  B.Caption:=ACaption;
  B.Hint:=AHint;
  B.Tag:=ATag;
  B.ImageIndex:=TagIcon(ATag);
  B.OnClick:=MenuHandlerProc;
  if ATag=TAG_PREVIEW then PreviewBtn:=B;
end;

procedure TMdMainForm.BuildComponents;
var
  M, Sub   : TMenuItem;
  Op       : TMdAlignOp;
  Split    : TSplitter;
  RightPan : TPanel;
  L        : TLabel;
  Head     : TPanel;
  Apply    : TButton;
begin
  Images:=TImageList.Create(Self);
  LoadMdIcons(Images);
  MainMenu:=TMainMenu.Create(Self);
  MainMenu.Images:=Images;
  Menu:=MainMenu;

  M:=AddMenu(MainMenu.Items,0,'&File');
  AddMenu(M,TAG_NEW,'&New design',ShortCut(VK_N,[ssCtrl]));
  AddMenu(M,TAG_OPEN,'&Open...',ShortCut(VK_O,[ssCtrl]));
  AddMenu(M,TAG_SAVE,'&Save',ShortCut(VK_S,[ssCtrl]));
  AddMenu(M,TAG_SAVEAS,'Save &As...');
  AddMenu(M,0,'-');
  AddMenu(M,TAG_PASTE,'&Paste script',ShortCut(VK_V,[ssCtrl,ssShift]));
  AddMenu(M,0,'-');
  AddMenu(M,TAG_EXIT,'E&xit');

  M:=AddMenu(MainMenu.Items,0,'&Edit');
  AddMenu(M,TAG_UNDO,'&Undo',ShortCut(VK_Z,[ssCtrl]));
  AddMenu(M,TAG_REDO,'&Redo',ShortCut(VK_Y,[ssCtrl]));
  AddMenu(M,0,'-');
  AddMenu(M,TAG_DELETE,'&Delete'#9'Del');
  AddMenu(M,TAG_SELALL,'Select &all'#9'Ctrl+A');

  M:=AddMenu(MainMenu.Items,0,'F&orm');
  AddMenu(M,TAG_NEWFORM,'&New form');
  AddMenu(M,TAG_DELFORM,'&Delete form');
  AddMenu(M,TAG_FORMLEFT,'Move &left');
  AddMenu(M,TAG_FORMRIGHT,'Move &right');

  M:=AddMenu(MainMenu.Items,0,'&Arrange');
  for Op:=Low(TMdAlignOp) to High(TMdAlignOp) do
  begin
    AddMenu(M,TAG_ALIGN+Ord(Op),AlignCaptions[Op]);
    if Op in [aoBottom,aoCentreV,aoParentV,aoSpreadV] then AddMenu(M,0,'-');
  end;
  AddMenu(M,0,'-');
  AddMenu(M,TAG_FRONT,'Bring to &front');
  AddMenu(M,TAG_BACK,'Send to bac&k');

  M:=AddMenu(MainMenu.Items,0,'&View');
  GridItem:=AddMenu(M,TAG_GRID,'Show &grid');
  SnapGridItem:=AddMenu(M,TAG_SNAPGRID,'Snap to g&rid');
  SnapEdgeItem:=AddMenu(M,TAG_SNAPEDGE,'Snap to &components');
  AddMenu(M,TAG_GRIDSIZE,'Grid &size...');
  AddMenu(M,0,'-');
  PreviewItem:=AddMenu(M,TAG_PREVIEW,'&Preview',ShortCut(VK_F9,[]));
  GridItem.Checked:=ShowGrid;
  SnapGridItem.Checked:=Snap.ToGrid;
  SnapEdgeItem.Checked:=Snap.ToEdges;

  M:=AddMenu(MainMenu.Items,0,'&Help');
  AddMenu(M,TAG_HELP,'&Help',ShortCut(VK_F1,[]));
  AddMenu(M,TAG_ABOUT,'&About...');

  ToolBar:=TToolBar.Create(Self);
  ToolBar.Parent:=Self;
  ToolBar.Align:=alTop;
  ToolBar.ShowCaptions:=True;
  ToolBar.Images:=Images;
  ToolBar.ButtonHeight:=38;   // the icon above the caption
  ToolBar.Flat:=True;
  ToolBar.AutoSize:=True;
  ToolBar.ShowHint:=True;
  AddTool(TAG_NEW,'New design','A new, empty design');
  AddTool(TAG_OPEN,'Open','Open an .euo file');
  AddTool(TAG_SAVE,'Save','Save the design as an .euo file');
  AddTool(-1,'','');
  AddTool(TAG_UNDO,'Undo','Undo');
  AddTool(TAG_REDO,'Redo','Redo');
  AddTool(TAG_DELETE,'Delete','Delete the selection');
  AddTool(-1,'','');
  AddTool(TAG_ALIGN+Ord(aoLeft),'Left','Align left edges');
  AddTool(TAG_ALIGN+Ord(aoRight),'Right','Align right edges');
  AddTool(TAG_ALIGN+Ord(aoTop),'Top','Align top edges');
  AddTool(TAG_ALIGN+Ord(aoBottom),'Bottom','Align bottom edges');
  AddTool(TAG_ALIGN+Ord(aoSpreadH),'Spread','Spread across, equal gaps');
  AddTool(TAG_ALIGN+Ord(aoSameSize),'Same size','Make the same size as the first selected');
  AddTool(-1,'','');
  AddTool(TAG_NEWFORM,'New form','Add a form');
  AddTool(TAG_PREVIEW,'Preview','Show the windows as the script will (F9)');

  StatusBar:=TStatusBar.Create(Self);
  StatusBar.Parent:=Self;
  StatusBar.SimplePanel:=False;
  StatusBar.Panels.Add.Width:=260;
  StatusBar.Panels.Add.Width:=200;
  StatusBar.Panels.Add.Width:=80;
  StatusBar.Panels.Add.Width:=400;
  StatusBar.Panels[2].Text:='MENU 1.6';

  // bottom: the script and the messages
  BottomPanel:=TPanel.Create(Self);
  BottomPanel.Parent:=Self;
  BottomPanel.Align:=alBottom;
  BottomPanel.Height:=230;
  BottomPanel.BevelOuter:=bvNone;
  Split:=TSplitter.Create(Self);
  Split.Parent:=Self;
  Split.Align:=alBottom;

  Messages:=TListBox.Create(Self);
  Messages.Parent:=BottomPanel;
  Messages.Align:=alRight;
  Messages.Width:=420;
  Messages.OnDblClick:=MessagesDblClick;
  Split:=TSplitter.Create(Self);
  Split.Parent:=BottomPanel;
  Split.Align:=alRight;

  Head:=TPanel.Create(Self);
  Head.Parent:=BottomPanel;
  Head.Align:=alTop;
  Head.Height:=28;
  Head.BevelOuter:=bvNone;
  Apply:=TButton.Create(Self);
  Apply.Parent:=Head;
  Apply.Align:=alRight;
  Apply.Width:=150;
  Apply.Caption:='Apply to canvas (Ctrl+Enter)';
  Apply.Tag:=TAG_APPLY;
  Apply.OnClick:=MenuHandlerProc;
  SynHeader:=TLabel.Create(Self);
  SynHeader.Parent:=Head;
  SynHeader.Align:=alClient;
  SynHeader.Layout:=tlCenter;
  SynHeader.BorderSpacing.Left:=6;
  SynHeader.Caption:='Script';

  SynHilite:=TSynEUOSyn.Create(Self);
  Syn:=TSynEdit.Create(Self);
  Syn.Parent:=BottomPanel;
  Syn.Align:=alClient;
  Syn.Highlighter:=SynHilite;
  Syn.Font.Name:='Courier New';
  Syn.Font.Height:=-13;
  Syn.TabWidth:=2;
  Syn.RightEdge:=-1;
  Syn.Gutter.Visible:=True;
  Syn.Options:=Syn.Options+[eoTabsToSpaces,eoTrimTrailingSpaces];
  Syn.OnChange:=SynChange;

  // left: the palette and the structure
  LeftPanel:=TPanel.Create(Self);
  LeftPanel.Parent:=Self;
  LeftPanel.Align:=alLeft;
  LeftPanel.Width:=180;
  LeftPanel.BevelOuter:=bvNone;
  Split:=TSplitter.Create(Self);
  Split.Parent:=Self;
  Split.Align:=alLeft;
  Palette:=TPanel.Create(Self);
  Palette.Parent:=LeftPanel;
  Palette.Align:=alTop;
  Palette.BevelOuter:=bvNone;
  Palette.AutoSize:=True;
  BuildPalette;
  L:=TLabel.Create(Self);
  L.Parent:=LeftPanel;
  L.Align:=alTop;
  L.Top:=Palette.Height+1;
  L.Caption:='Structure';
  L.BorderSpacing.Around:=4;
  Tree:=TTreeView.Create(Self);
  Tree.Parent:=LeftPanel;
  Tree.Align:=alClient;
  Tree.ReadOnly:=True;
  Tree.HideSelection:=False;
  Tree.DragMode:=dmAutomatic;
  Tree.OnChange:=TreeChange;
  Tree.OnDragOver:=TreeDragOver;
  Tree.OnDragDrop:=TreeDragDrop;

  // right: the inspector
  RightPan:=TPanel.Create(Self);
  RightPan.Parent:=Self;
  RightPan.Align:=alRight;
  RightPan.Width:=290;
  RightPan.BevelOuter:=bvNone;
  Split:=TSplitter.Create(Self);
  Split.Parent:=Self;
  Split.Align:=alRight;
  Inspector:=TMdInspector.Create(Self);
  Inspector.Parent:=RightPan;
  Inspector.Align:=alClient;
  Inspector.OnBeforeChange:=BeforeChange;
  Inspector.OnAfterChange:=AfterChange;
  Inspector.OnMessage:=ShowMessageText;

  // centre: one tab per form
  Pages:=TPageControl.Create(Self);
  Pages.Parent:=Self;
  Pages.Align:=alClient;
  Pages.OnChange:=PageChange;

  Timer:=TTimer.Create(Self);
  Timer.Interval:=250;
  Timer.Enabled:=False;
  Timer.OnTimer:=TimerTick;
end;

// One button per control type the table has; a form is added from the Form menu.
// One button per type, in alphabetical order, each with its Lazarus component icon.
procedure TMdMainForm.BuildPalette;
var
  T     : TMdType;
  Types : TStringList;
  B     : TSpeedButton;
  G     : TBitmap;
  Cnt   : Integer;
  Y     : Integer;
  L     : TLabel;
begin
  L:=TLabel.Create(Self);
  L.Parent:=Palette;
  L.SetBounds(4,2,170,16);
  L.Caption:='Palette: click, then click the form';
  PaletteImgs:=TImageList.Create(Self);
  PaletteImgs.Width:=24;
  PaletteImgs.Height:=24;
  Types:=TStringList.Create;
  try
    for T:=Low(TMdType) to High(TMdType) do
      if T<>mdtForm then Types.AddObject(MdTypeRows[T].Name,TObject(PtrInt(Ord(T))));
    Types.Sort;
    Y:=20;
    for Cnt:=0 to Types.Count-1 do
    begin
      T:=TMdType(PtrInt(Types.Objects[Cnt]));
      G:=PaletteGlyph(T);
      try
        PaletteImgs.Add(G,nil);
      finally
        G.Free;
      end;
      B:=TSpeedButton.Create(Self);
      B.Parent:=Palette;
      B.SetBounds(4,Y,170,28);
      B.Caption:=MdTypeRows[T].Name;
      if MdTypeRows[T].Reforged then B.Caption:=B.Caption+' (Reforged only)';
      B.Images:=PaletteImgs;
      B.ImageIndex:=Cnt;
      B.Layout:=blGlyphLeft;
      B.Alignment:=taLeftJustify;
      B.Margin:=4;
      B.Spacing:=6;
      B.GroupIndex:=1;
      B.AllowAllUp:=True;
      B.Tag:=Ord(T);
      B.OnClick:=PaletteClick;
      B.Flat:=True;
      Inc(Y,30);
    end;
  finally
    Types.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Every command runs from the message loop, after the event that asked for it. A shortcut
// arrives while the focused control is still handling its key, and that control is often a
// canvas view: Undo, Open, Delete and the like free every tab and view, and a view freed inside
// its own key handler went on writing into whatever was made in its memory next.
procedure TMdMainForm.MenuHandlerProc(Sender : TObject);
begin
  Application.QueueAsyncCall(MenuQueued,TComponent(Sender).Tag);
end;

procedure TMdMainForm.MenuQueued(Data : PtrInt);
begin
  MenuHandler(Data);
end;

procedure TMdMainForm.MenuHandler(Tag : Integer);
begin
  case Tag of
    TAG_NEW       : DoNew;
    TAG_OPEN      : DoOpen;
    TAG_SAVE      : DoSave(False);
    TAG_SAVEAS    : DoSave(True);
    TAG_PASTE     : DoPaste;
    TAG_EXIT      : Close;
    TAG_UNDO      : if Syn.Focused then Syn.Undo else DoUndo(False);
    TAG_REDO      : if Syn.Focused then Syn.Redo else DoUndo(True);
    TAG_DELETE    : DoDelete;
    TAG_SELALL    : if ActiveView<>nil then
                    begin
                      Sel.Assign(ActiveView.FormComponent.Children);
                      SelectionChanged;
                    end;
    TAG_NEWFORM   : DoNewForm;
    TAG_DELFORM   : if ActiveView<>nil then
                    begin
                      Sel.Clear;
                      Sel.Add(ActiveView.FormComponent);
                      DoDelete;
                    end;
    TAG_FORMLEFT  : DoMoveForm(-1);
    TAG_FORMRIGHT : DoMoveForm(1);
    TAG_ALIGN..TAG_ALIGN+Ord(High(TMdAlignOp)) : DoAlign(TMdAlignOp(Tag-TAG_ALIGN));
    TAG_FRONT     : DoZOrder(True);
    TAG_BACK      : DoZOrder(False);
    TAG_GRID      : begin
                      ShowGrid:=not ShowGrid;
                      GridItem.Checked:=ShowGrid;
                      RefreshViews;
                    end;
    TAG_SNAPGRID  : begin
                      Snap.ToGrid:=not Snap.ToGrid;
                      SnapGridItem.Checked:=Snap.ToGrid;
                      RefreshViews;
                    end;
    TAG_SNAPEDGE  : begin
                      Snap.ToEdges:=not Snap.ToEdges;
                      SnapEdgeItem.Checked:=Snap.ToEdges;
                      RefreshViews;
                    end;
    TAG_GRIDSIZE  : DoGridSize;
    TAG_PREVIEW   : TogglePreview;
    TAG_HELP      : OpenURL(DocsUrl);
    TAG_ABOUT     : ShowMessage('EasyUO Reforged MENU Designer '+REFORGED_VERSION+#13#10#13#10+
                      'Lays out EasyUO MENU windows for the EasyUO 1.6 MENU logic and reads them '+
                      'back from scripts.'+#13#10+
                      'https://github.com/ilpersi/EasyUOReforged');
    TAG_APPLY     : DoApply;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The model changes only between these two. BeforeChange keeps the state for Undo.
procedure TMdMainForm.BeforeChange(Sender : TObject);
var
  Cnt : Integer;
begin
  UndoStack.Add(Doc.Clone);
  while UndoStack.Count>MaxUndo do
  begin
    TObject(UndoStack[0]).Free;
    UndoStack.Delete(0);
  end;
  for Cnt:=0 to RedoStack.Count-1 do TObject(RedoStack[Cnt]).Free;
  RedoStack.Clear;
end;

// New design, Open and Paste script start a design of their own: Undo going back into the one
// before would bring that back under the new one's file name, for Save to write over it.
// (Apply is an edit of the design on show, and stays undoable.)
procedure TMdMainForm.ClearHistory;
var
  Cnt : Integer;
begin
  for Cnt:=0 to UndoStack.Count-1 do TObject(UndoStack[Cnt]).Free;
  UndoStack.Clear;
  for Cnt:=0 to RedoStack.Count-1 do TObject(RedoStack[Cnt]).Free;
  RedoStack.Clear;
end;

// F built again (nil: every form, and the tabs, after a change between forms or of a name).
procedure TMdMainForm.AfterChange(F : TMdComponent);
var
  V : TMdFormView;
begin
  Modified:=True;
  ShowsSource:=False;
  LoadReport.Clear;
  if (F=nil) or (Pages.PageCount<>Doc.FormCount) then
  begin
    Engine.RebuildAll;
    RebuildTabs;
  end
  else
  begin
    Engine.Rebuild(F);
    V:=ViewOf(F);
    if V<>nil then
    begin
      V.Host;
      TTabSheet(V.Parent.Parent).Caption:=F.Name;
    end;
  end;
  WriteScript;
  RebuildTree;
  SelectionChanged;
  UpdateTitle;
end;

// A whole new model: Undo, Open, Paste, Apply.
procedure TMdMainForm.SetDocument(NewDoc : TMdDocument);
var
  Names : TStringList;
  Cnt   : Integer;
  C     : TMdComponent;
  Page  : Integer;
begin
  Names:=TStringList.Create;
  try
    for Cnt:=0 to Sel.Count-1 do Names.Add(TMdComponent(Sel[Cnt]).Name);
    Page:=Pages.ActivePageIndex;
    // the views first: they host the surfaces the engine is about to free
    while Pages.PageCount>0 do Pages.Pages[0].Free;
    Views.Clear;
    Sel.Clear;
    if (Doc<>nil) and (Doc<>NewDoc) then Doc.Free;
    Doc:=NewDoc;
    Engine.Reset(Doc);
    RebuildTabs;
    for Cnt:=0 to Names.Count-1 do
    begin
      C:=Doc.FindName(Names[Cnt]);
      if C<>nil then Sel.Add(C);
    end;
    if (Page>=0) and (Page<Pages.PageCount) then Pages.ActivePageIndex:=Page;
    // nothing selected: the form on show, so the inspector has something to show
    if Sel.Count=0 then
      if (Pages.ActivePageIndex>=0) and (Pages.ActivePageIndex<Doc.FormCount) then
        Sel.Add(Doc.Form(Pages.ActivePageIndex))
      else Sel.Add(Doc.Form0);
  finally
    Names.Free;
  end;
  WriteScript;
  RebuildTree;
  SelectionChanged;
  UpdateTitle;
end;

// A tab and a view per form, in the document's order.
procedure TMdMainForm.RebuildTabs;
var
  Cnt   : Integer;
  F     : TMdComponent;
  Tab   : TTabSheet;
  Box   : TScrollBox;
  V     : TMdFormView;
  Keep  : Integer;
begin
  Keep:=Pages.ActivePageIndex;
  Updating:=True;
  try
    while Pages.PageCount>0 do Pages.Pages[0].Free;
    Views.Clear;
    for Cnt:=0 to Doc.FormCount-1 do
    begin
      F:=Doc.Form(Cnt);
      Tab:=TTabSheet.Create(Pages);
      Tab.PageControl:=Pages;
      Tab.Caption:=F.Name;
      Box:=TScrollBox.Create(Tab);
      Box.Parent:=Tab;
      Box.Align:=alClient;
      Box.Color:=clAppWorkspace;
      V:=TMdFormView.Create(Box,Doc,Engine,F,Sel);
      V.Parent:=Box;
      V.Left:=16;
      V.Top:=16;
      V.Snap:=Snap;
      V.ShowGrid:=ShowGrid;
      V.OnBeforeChange:=BeforeChange;
      V.OnAfterChange:=AfterChange;
      V.OnSelect:=ViewSelect;
      V.OnPlaced:=ViewPlaced;
      Views.Add(V);
      V.Host;
    end;
    if (Keep>=0) and (Keep<Pages.PageCount) then Pages.ActivePageIndex:=Keep;
  finally
    Updating:=False;
  end;
end;

procedure TMdMainForm.RefreshViews;
var
  Cnt : Integer;
  V   : TMdFormView;
begin
  for Cnt:=0 to Views.Count-1 do
  begin
    V:=TMdFormView(Views[Cnt]);
    V.Snap:=Snap;
    V.ShowGrid:=ShowGrid;
    V.Host;
  end;
  UpdateStatus;
end;

function TMdMainForm.ViewOf(F : TMdComponent) : TMdFormView;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Views.Count-1 do
    if TMdFormView(Views[Cnt]).FormComponent=F then Exit(TMdFormView(Views[Cnt]));
  Result:=nil;
end;

function TMdMainForm.ActiveView : TMdFormView;
begin
  if (Pages.ActivePageIndex>=0) and (Pages.ActivePageIndex<Views.Count) then
    Result:=TMdFormView(Views[Pages.ActivePageIndex])
  else Result:=nil;
end;

procedure TMdMainForm.RebuildTree;

  procedure AddNodes(Parent : TTreeNode; C : TMdComponent);
  var
    N   : TTreeNode;
    Cnt : Integer;
    S   : String;
  begin
    S:=C.Name+'  ('+C.Row.Name+')';
    if not C.Visible then S:=S+'  hidden';
    N:=Tree.Items.AddChildObject(Parent,S,C);
    for Cnt:=0 to C.ChildCount-1 do
      AddNodes(N,C.Child(Cnt));
  end;

var
  Cnt : Integer;
begin
  Updating:=True;
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
    for Cnt:=0 to Doc.FormCount-1 do
      AddNodes(nil,Doc.Form(Cnt));
    Tree.FullExpand;
  finally
    Tree.Items.EndUpdate;
    Updating:=False;
  end;
end;

procedure TMdMainForm.SelectionChanged;
var
  Cnt  : Integer;
  Node : TTreeNode;
  C    : TMdComponent;
begin
  if Sel.Count>0 then C:=TMdComponent(Sel[0]) else C:=nil;
  Inspector.Warnings.Assign(Engine.Warnings);
  Inspector.ShowComponent(Doc,C);
  for Cnt:=0 to Views.Count-1 do
    TMdFormView(Views[Cnt]).UpdateMarks;
  Updating:=True;
  try
    Node:=Tree.Items.GetFirstNode;
    while Node<>nil do
    begin
      if Node.Data=Pointer(C) then
      begin
        Tree.Selected:=Node;
        Break;
      end;
      Node:=Node.GetNext;
    end;
  finally
    Updating:=False;
  end;
  UpdateStatus;
end;

// The script pane: the file the design saves as.
procedure TMdMainForm.WriteScript;
var
  Gen   : TMdGenerator;
  Lines : TStringList;
  Top   : Integer;
begin
  if ShowsSource then Exit;
  Gen:=TMdGenerator.Create;
  Lines:=TStringList.Create;
  try
    Gen.FileLines(Doc,Lines);
    Updating:=True;
    try
      Top:=Syn.TopLine;
      Syn.Lines.Assign(Lines);
      Syn.TopLine:=Top;
      Syn.Modified:=False;
    finally
      Updating:=False;
    end;
    Engine.Warnings.Assign(Gen.Warnings);
  finally
    Lines.Free;
    Gen.Free;
  end;
  SynHeader.Caption:='Script (what Save writes)';
  ShowWarnings;
end;

procedure TMdMainForm.ShowWarnings;
var
  Cnt : Integer;
begin
  Messages.Items.BeginUpdate;
  try
    Messages.Items.Clear;
    for Cnt:=0 to LoadReport.Count-1 do
      Messages.Items.AddObject(LoadReport[Cnt],LoadReport.Objects[Cnt]);
    for Cnt:=0 to Engine.Warnings.Count-1 do
      Messages.Items.Add(Engine.Warnings[Cnt]);
    if Messages.Items.Count=0 then Messages.Items.Add('No warnings.');
  finally
    Messages.Items.EndUpdate;
  end;
end;

procedure TMdMainForm.UpdateTitle;
var
  S : String;
begin
  if FileName='' then S:='untitled' else S:=ExtractFileName(FileName);
  if Modified then S:=S+' *';
  Caption:=S+' - EasyUO Reforged MENU Designer '+REFORGED_VERSION;
end;

procedure TMdMainForm.UpdateStatus;
var
  C : TMdComponent;
  S : String;
begin
  if Sel.Count=0 then StatusBar.Panels[0].Text:=''
  else
  begin
    C:=TMdComponent(Sel[0]);
    StatusBar.Panels[0].Text:=Format('%s  %d, %d  %d x %d',[C.Name,C.Left,C.Top,C.Width,C.Height]);
    if Sel.Count>1 then
      StatusBar.Panels[0].Text:=StatusBar.Panels[0].Text+Format('  (+%d)',[Sel.Count-1]);
  end;
  S:='Snap:';
  if Snap.ToGrid then S:=S+' grid '+IntToStr(Snap.Grid);
  if Snap.ToEdges then S:=S+' edges';
  if not (Snap.ToGrid or Snap.ToEdges) then S:=S+' off';
  StatusBar.Panels[1].Text:=S+'  (Alt: off)';
end;

procedure TMdMainForm.ShowMessageText(const S : String);
begin
  StatusBar.Panels[3].Text:=S;
  Beep;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdMainForm.PaletteClick(Sender : TObject);
var
  V : TMdFormView;
begin
  V:=ActiveView;
  if V=nil then Exit;
  V.Placing:=TSpeedButton(Sender).Down;
  V.PlaceType:=TMdType(TSpeedButton(Sender).Tag);
  if V.Placing then
    StatusBar.Panels[3].Text:='Click on the form to place a '+MdTypeRows[V.PlaceType].Name+
      ' (Esc: cancel)'
  else StatusBar.Panels[3].Text:='';
end;

procedure TMdMainForm.ViewPlaced(Sender : TObject);
var
  Cnt : Integer;
begin
  for Cnt:=0 to Palette.ControlCount-1 do
    if Palette.Controls[Cnt] is TSpeedButton then TSpeedButton(Palette.Controls[Cnt]).Down:=False;
  StatusBar.Panels[3].Text:='';
end;

procedure TMdMainForm.ViewSelect(Sender : TObject);
begin
  SelectionChanged;
end;

procedure TMdMainForm.PageChange(Sender : TObject);
begin
  if Updating or (ActiveView=nil) then Exit;
  Sel.Clear;
  Sel.Add(ActiveView.FormComponent);
  ViewPlaced(nil);
  SelectionChanged;
end;

procedure TMdMainForm.TreeChange(Sender : TObject; Node : TTreeNode);
var
  C   : TMdComponent;
  Cnt : Integer;
begin
  if Updating or (Node=nil) then Exit;
  C:=TMdComponent(Node.Data);
  if Sel.IndexOf(C)>=0 then Exit;   // the tree following the selection, late
  Sel.Clear;
  Sel.Add(C);
  for Cnt:=0 to Views.Count-1 do
    if TMdFormView(Views[Cnt]).FormComponent=C.FormOf then
    begin
      Updating:=True;
      Pages.ActivePageIndex:=Cnt;
      Updating:=False;
    end;
  SelectionChanged;
end;

procedure TMdMainForm.TreeDragOver(Sender, Source : TObject; X, Y : Integer;
  State : TDragState; var Accept : Boolean);
var
  Target : TTreeNode;
begin
  Accept:=False;
  if (Source<>Tree) or (Tree.Selected=nil) then Exit;
  Target:=Tree.GetNodeAt(X,Y);
  if Target=nil then Exit;
  Accept:=TMdComponent(Target.Data).IsContainer and
    Doc.CanMoveTo(TMdComponent(Tree.Selected.Data),TMdComponent(Target.Data)) or
    not TMdComponent(Target.Data).IsContainer and (TMdComponent(Target.Data).Parent<>nil) and
    Doc.CanMoveTo(TMdComponent(Tree.Selected.Data),TMdComponent(Target.Data).Parent);
end;

// Dropped on a form or a panel: into it, on top. Dropped on a component: just under it.
procedure TMdMainForm.TreeDragDrop(Sender, Source : TObject; X, Y : Integer);
var
  Target : TTreeNode;
  C, T   : TMdComponent;
begin
  Target:=Tree.GetNodeAt(X,Y);
  if (Target=nil) or (Tree.Selected=nil) then Exit;
  C:=TMdComponent(Tree.Selected.Data);
  T:=TMdComponent(Target.Data);
  if (C=T) or C.IsForm then Exit;
  BeforeChange(Self);
  if T.IsContainer then Doc.MoveTo(C,T)
  else Doc.MoveTo(C,T.Parent,T.Parent.Children.IndexOf(T));
  Sel.Clear;
  Sel.Add(C);
  AfterChange(nil);
end;

procedure TMdMainForm.MessagesDblClick(Sender : TObject);
var
  Line : Integer;
begin
  if Messages.ItemIndex<0 then Exit;
  Line:=PtrInt(Pointer(Messages.Items.Objects[Messages.ItemIndex]));
  if (Line<=0) or not ShowsSource then Exit;
  Syn.CaretY:=Line;
  Syn.TopLine:=Max(1,Line-3);
  Syn.SetFocus;
end;

procedure TMdMainForm.SynChange(Sender : TObject);
begin
  if Updating then Exit;
  SynHeader.Caption:='Script, edited: Apply to rebuild the canvas from it';
end;

procedure TMdMainForm.TimerTick(Sender : TObject);
begin
  if Preview<>nil then
    StatusBar.Panels[3].Text:='Preview: #MenuButton = '+Preview.MenuButton;
end;

////////////////////////////////////////////////////////////////////////////////
function TMdMainForm.ConfirmDiscard : Boolean;
begin
  Result:=True;
  if not Modified then Exit;
  case MessageDlg('Save the changes to '+ExtractFileName(FileName)+'?',mtConfirmation,
    [mbYes,mbNo,mbCancel],0) of
    mrYes: Result:=DoSave(False);
    mrNo:  Result:=True;
  else     Result:=False;
  end;
end;

// Keys of the canvas, which the script pane and the inspector need for themselves. Queued as
// the menu's commands are (MenuHandlerProc): Delete frees the view that has the key.
procedure TMdMainForm.FormKeyDown(Sender : TObject; var Key : Word; Shift : TShiftState);
begin
  if (Key=VK_RETURN) and (ssCtrl in Shift) and Syn.Focused then
  begin
    Application.QueueAsyncCall(MenuQueued,TAG_APPLY);
    Key:=0;
  end
  else if ActiveControl is TMdFormView then
  begin
    if (Key=VK_DELETE) and (Shift=[]) then
    begin
      Application.QueueAsyncCall(MenuQueued,TAG_DELETE);
      Key:=0;
    end
    else if (Key=VK_A) and (Shift=[ssCtrl]) then
    begin
      Application.QueueAsyncCall(MenuQueued,TAG_SELALL);
      Key:=0;
    end;
  end;
end;

procedure TMdMainForm.FormCloseQuery(Sender : TObject; var CanClose : Boolean);
begin
  CanClose:=ConfirmDiscard;
  if CanClose then
  begin
    FreeAndNil(Preview);
    SaveSettings;
  end;
end;

// Lines (or the file FromFile when Lines is nil) read into a new model, with the report.
procedure TMdMainForm.LoadText(Lines : TStrings; const FromFile : String);
var
  Text   : TStringList;
  NewDoc : TMdDocument;
  Imp    : TMdImporter;
  Cnt    : Integer;
  E      : TMdReportEntry;
  S      : String;
begin
  Text:=TStringList.Create;
  NewDoc:=TMdDocument.Create;
  Imp:=TMdImporter.Create;
  try
    if Lines=nil then LoadScript(FromFile,Text) else Text.Assign(Lines);
    Screen.Cursor:=crHourGlass;
    try
      Imp.Import(Text,NewDoc);
    finally
      Screen.Cursor:=crDefault;
    end;
    LoadReport.Clear;
    Dropped:=0;
    for Cnt:=0 to Imp.Report.Count-1 do
    begin
      E:=TMdReportEntry(Imp.Report[Cnt]);
      if E.LineNo>0 then
      begin
        S:='Line '+IntToStr(E.LineNo)+': '+E.Message;
        Inc(Dropped);
      end
      else S:=E.Message;
      LoadReport.AddObject(S,TObject(PtrInt(E.LineNo)));
    end;
    if FromFile<>'' then
    begin
      Foreign.Clear;
      ForeignLines(Text,NewDoc,Foreign);
    end;
    SetDocument(NewDoc);
    NewDoc:=nil;
    // with a report, the pane keeps the text as read so its line numbers can be found
    ShowsSource:=LoadReport.Count>0;
    if ShowsSource then
    begin
      Updating:=True;
      Syn.Lines.Assign(Text);
      Updating:=False;
      SynHeader.Caption:='Script as read: the next change rewrites it in the designer''s layout';
    end;
    ShowWarnings;
  finally
    Imp.Free;
    NewDoc.Free;
    Text.Free;
  end;
end;

procedure TMdMainForm.DoNew;
begin
  if not ConfirmDiscard then Exit;
  FileName:='';
  Foreign.Clear;
  Dropped:=0;
  LoadReport.Clear;
  ShowsSource:=False;
  SetDocument(TMdDocument.Create);
  ClearHistory;
  Modified:=False;
  UpdateTitle;
end;

procedure TMdMainForm.DoOpen;
var
  D : TOpenDialog;
begin
  if not ConfirmDiscard then Exit;
  D:=TOpenDialog.Create(nil);
  try
    D.Filter:='Scripts (*.euo; *.txt)|*.euo;*.txt|All files (*.*)|*.*';
    D.Title:='Open a script with MENU windows';
    if not D.Execute then Exit;
    FileName:=D.FileName;
    LoadText(nil,FileName);
    ClearHistory;
    Modified:=False;
    UpdateTitle;
  finally
    D.Free;
  end;
end;

// Saving over a loaded file that held more than the designer reads asks first.
function TMdMainForm.DoSave(AskName : Boolean) : Boolean;
var
  D     : TSaveDialog;
  Lines : TStringList;
  Gen   : TMdGenerator;
  Msg   : String;
  Cnt   : Integer;
begin
  Result:=False;
  if AskName or (FileName='') then
  begin
    D:=TSaveDialog.Create(nil);
    try
      D.Filter:='EasyUO scripts (*.euo)|*.euo|All files (*.*)|*.*';
      D.DefaultExt:='euo';
      D.Options:=D.Options+[ofOverwritePrompt];
      if not D.Execute then Exit;
      if not SameText(ExpandFileName(D.FileName),ExpandFileName(FileName)) then
      begin
        Foreign.Clear;
        Dropped:=0;
      end;
      FileName:=D.FileName;
    finally
      D.Free;
    end;
  end;

  if (Foreign.Count>0) or (Dropped>0) then
  begin
    Msg:='Saving over '+ExtractFileName(FileName)+' replaces it with the MENU windows only.';
    if Foreign.Count>0 then
    begin
      Msg:=Msg+#13#10#13#10+IntToStr(Foreign.Count)+' lines that are not MENU lines would be lost:';
      for Cnt:=0 to Min(5,Foreign.Count)-1 do Msg:=Msg+#13#10'  '+Foreign[Cnt];
      if Foreign.Count>5 then Msg:=Msg+#13#10'  ...';
    end;
    if Dropped>0 then
      Msg:=Msg+#13#10#13#10+IntToStr(Dropped)+' MENU lines the designer could not read would be '+
        'lost too (see Messages).';
    case QuestionDlg('Save over the file?',Msg,mtWarning,[mrYes,'Save anyway',mrNo,'Save as...',
      mrCancel,'Cancel'],0) of
      mrYes: ;
      mrNo:  Exit(DoSave(True));
    else     Exit;
    end;
  end;

  Gen:=TMdGenerator.Create;
  Lines:=TStringList.Create;
  try
    Gen.FileLines(Doc,Lines);
    SaveScript(FileName,Lines);
  finally
    Lines.Free;
    Gen.Free;
  end;
  Foreign.Clear;
  Dropped:=0;
  Modified:=False;
  UpdateTitle;
  StatusBar.Panels[3].Text:='Saved '+FileName;
  Result:=True;
end;

procedure TMdMainForm.DoPaste;
var
  L : TStringList;
begin
  if not Clipboard.HasFormat(CF_TEXT) then
  begin
    ShowMessageText('The clipboard has no text.');
    Exit;
  end;
  if not ConfirmDiscard then Exit;
  L:=TStringList.Create;
  try
    L.Text:=Clipboard.AsText;
    FileName:='';
    Foreign.Clear;
    LoadText(L,'');
    ClearHistory;
    Modified:=True;
    UpdateTitle;
  finally
    L.Free;
  end;
end;

// The script pane, edited by hand, read back into the canvas.
procedure TMdMainForm.DoApply;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Assign(Syn.Lines);
    BeforeChange(Self);
    LoadText(L,'');
    Modified:=True;
    UpdateTitle;
  finally
    L.Free;
  end;
end;

procedure TMdMainForm.DoUndo(Redo : Boolean);
var
  From, Into : TList;
  D          : TMdDocument;
begin
  if Redo then
  begin
    From:=RedoStack;
    Into:=UndoStack;
  end
  else
  begin
    From:=UndoStack;
    Into:=RedoStack;
  end;
  if From.Count=0 then Exit;
  D:=TMdDocument(From[From.Count-1]);
  From.Delete(From.Count-1);
  Into.Add(Doc.Clone);
  ShowsSource:=False;
  LoadReport.Clear;
  SetDocument(D);
  Modified:=True;
  UpdateTitle;
end;

procedure TMdMainForm.DoDelete;
var
  Cnt   : Integer;
  C     : TMdComponent;
  Whole : Boolean;
  Gone  : TList;
begin
  if Sel.Count=0 then Exit;
  Gone:=TList.Create;
  try
    for Cnt:=0 to Sel.Count-1 do
    begin
      C:=TMdComponent(Sel[Cnt]);
      if C.IsForm0 then Continue;
      Gone.Add(C);
    end;
    if Gone.Count=0 then
    begin
      ShowMessageText('form0 is the main window: it cannot be deleted.');
      Exit;
    end;
    Whole:=False;
    for Cnt:=0 to Gone.Count-1 do
      if TMdComponent(Gone[Cnt]).IsForm then Whole:=True;
    if Whole and (MessageDlg('Delete the form with everything in it?',mtConfirmation,
       [mbYes,mbNo],0)<>mrYes) then Exit;
    BeforeChange(Self);
    // a component inside another one going too goes with it
    for Cnt:=Gone.Count-1 downto 0 do
    begin
      C:=TMdComponent(Gone[Cnt]).Parent;
      while C<>nil do
      begin
        if Gone.IndexOf(C)>=0 then
        begin
          Gone.Delete(Cnt);
          Break;
        end;
        C:=C.Parent;
      end;
    end;
    for Cnt:=0 to Gone.Count-1 do
    begin
      C:=TMdComponent(Gone[Cnt]);
      if C.IsForm then Engine.Forget(C);
      Doc.Remove(C);
    end;
    Sel.Clear;
    AfterChange(nil);
  finally
    Gone.Free;
  end;
end;

// The selection, in the parent of its first component, against that first one.
procedure TMdMainForm.DoAlign(Op : TMdAlignOp);
var
  List  : TList;
  Rects : array of TRect;
  Cnt   : Integer;
  C     : TMdComponent;
  P     : TMdComponent;
  Par   : TRect;
begin
  if (Sel.Count=0) or TMdComponent(Sel[0]).IsForm then Exit;
  P:=TMdComponent(Sel[0]).Parent;
  List:=TList.Create;
  try
    for Cnt:=0 to Sel.Count-1 do
      if TMdComponent(Sel[Cnt]).Parent=P then List.Add(Sel[Cnt]);
    if (List.Count<2) and not (Op in [aoParentH,aoParentV]) then
    begin
      ShowMessageText('Select two or more components in the same form or panel.');
      Exit;
    end;
    SetLength(Rects,List.Count);
    for Cnt:=0 to List.Count-1 do
    begin
      C:=TMdComponent(List[Cnt]);
      Rects[Cnt]:=Bounds(C.Left,C.Top,C.Width,C.Height);
    end;
    Par:=Rect(0,0,P.Width,P.Height);
    AlignRects(Rects,Op,Par);
    BeforeChange(Self);
    for Cnt:=0 to List.Count-1 do
    begin
      C:=TMdComponent(List[Cnt]);
      C.Left:=Rects[Cnt].Left;
      C.Top:=Rects[Cnt].Top;
      if Rects[Cnt].Right-Rects[Cnt].Left<>C.Width then
      begin
        C.Width:=Rects[Cnt].Right-Rects[Cnt].Left;
        if C.Row.W=szAuto then C.FixedW:=True;
      end;
      if Rects[Cnt].Bottom-Rects[Cnt].Top<>C.Height then
      begin
        C.Height:=Rects[Cnt].Bottom-Rects[Cnt].Top;
        if C.Row.H=szAuto then C.FixedH:=True;
      end;
      if (C.Row.Drawing or (C.TypeId=mdtShape)) and not C.Stretch then
      begin
        C.BitmapW:=C.Width;
        C.BitmapH:=C.Height;
      end;
    end;
    AfterChange(P.FormOf);
  finally
    List.Free;
  end;
end;

// z-order is creation order in the script: in front means created later in its parent.
procedure TMdMainForm.DoZOrder(Front : Boolean);
var
  Cnt : Integer;
  C   : TMdComponent;
  F   : TMdComponent;
begin
  F:=nil;
  for Cnt:=0 to Sel.Count-1 do
    if not TMdComponent(Sel[Cnt]).IsForm then
    begin
      if F=nil then BeforeChange(Self);
      C:=TMdComponent(Sel[Cnt]);
      C.Parent.Children.Remove(C);
      if Front then C.Parent.Children.Add(C) else C.Parent.Children.Insert(0,C);
      F:=C.FormOf;
    end;
  if F<>nil then AfterChange(F);
end;

procedure TMdMainForm.DoNewForm;
var
  F : TMdComponent;
begin
  BeforeChange(Self);
  F:=Doc.AddForm('');
  Sel.Clear;
  Sel.Add(F);
  AfterChange(nil);
  Pages.ActivePageIndex:=Doc.FormCount-1;
end;

procedure TMdMainForm.DoMoveForm(Delta : Integer);
var
  V : TMdFormView;
  I : Integer;
begin
  V:=ActiveView;
  if (V=nil) or V.FormComponent.IsForm0 then Exit;
  I:=Pages.ActivePageIndex+Delta;
  if (I<1) or (I>=Doc.FormCount) then Exit;
  BeforeChange(Self);
  Doc.MoveForm(V.FormComponent,I);
  AfterChange(nil);
  Pages.ActivePageIndex:=I;
end;

procedure TMdMainForm.DoGridSize;
var
  S : String;
  N : Integer;
begin
  S:=IntToStr(Snap.Grid);
  if not InputQuery('Grid size','Pixels between grid points (4 to 64):',S) then Exit;
  if not TryStrToInt(Trim(S),N) or (N<4) or (N>64) then
  begin
    ShowMessageText('The grid size is a number from 4 to 64.');
    Exit;
  end;
  Snap.Grid:=N;
  RefreshViews;
end;

procedure TMdMainForm.TogglePreview;
begin
  if Preview<>nil then
  begin
    FreeAndNil(Preview);
    Timer.Enabled:=False;
    PreviewBtn.Caption:='Preview';
    PreviewItem.Checked:=False;
    StatusBar.Panels[3].Text:='';
    Exit;
  end;
  Preview:=TMdPreview.Create(Doc);
  Timer.Enabled:=True;
  PreviewBtn.Caption:='Stop preview';
  PreviewItem.Checked:=True;
  TimerTick(nil);
end;

////////////////////////////////////////////////////////////////////////////////
// The designer's own settings (grid and snapping), never in a script.
procedure TMdMainForm.LoadSettings;
var
  R : TRegistry;
begin
  R:=TRegistry.Create;
  try
    R.RootKey:=HKEY_CURRENT_USER;
    if not R.OpenKeyReadOnly(RegKey) then Exit;
    if R.ValueExists('Grid') then Snap.Grid:=Max(4,Min(64,R.ReadInteger('Grid')));
    if R.ValueExists('SnapToGrid') then Snap.ToGrid:=R.ReadBool('SnapToGrid');
    if R.ValueExists('SnapToEdges') then Snap.ToEdges:=R.ReadBool('SnapToEdges');
    if R.ValueExists('ShowGrid') then ShowGrid:=R.ReadBool('ShowGrid');
  finally
    R.Free;
  end;
end;

procedure TMdMainForm.SaveSettings;
var
  R : TRegistry;
begin
  R:=TRegistry.Create;
  try
    R.RootKey:=HKEY_CURRENT_USER;
    if not R.OpenKey(RegKey,True) then Exit;
    R.WriteInteger('Grid',Snap.Grid);
    R.WriteBool('SnapToGrid',Snap.ToGrid);
    R.WriteBool('SnapToEdges',Snap.ToEdges);
    R.WriteBool('ShowGrid',ShowGrid);
  except
  end;
  R.Free;
end;

end.
