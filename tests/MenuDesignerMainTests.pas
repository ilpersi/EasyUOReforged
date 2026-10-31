unit MenuDesignerMainTests;

{
  The MENU Designer's main window (tools/EUOMenuDesigner/mdmain.pas), driven as the user drives
  it: a design applied from the script pane, components placed on the canvas, picked in the tree,
  values typed or picked in the inspector, Undo from the menu or as a Ctrl+Z key press wherever
  the focus is. Undo, Delete and the like free every tab and view and make new ones. Hand test 5
  saw an access violation after Ctrl+Z: a shortcut reaches the menu while the focused control
  is still handling its key, and Undo freed that control (a canvas view) there, whose handler
  then wrote into whatever was made in its memory next. Commands now run from the message loop;
  each key test checks that the control it presses the key in is still there when its key-down
  message returns, which the old code failed every time, not only when the memory was reused.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Menus, Grids, SynEdit,
  Buttons, fpcunit, testregistry, mdtypes, mdmodel, mdinspector, mdcanvas, mdgeometry, mdicons,
  mdmain;

type
  TMenuDesignerMainTests = class(TTestCase)
  private
    Win  : TMdMainForm;
    Insp : TMdInspector;
    Tree : TTreeView;
    procedure Settle;
    function  Find(AClass : TClass) : TComponent;
    procedure Command(const Caption : String);
    procedure ApplyScript(const Lines : array of String);
    procedure Pick(const Name : String);
    function  Picked : TMdComponent;
    procedure PickInList(const Caption, Value : String);
    procedure TypeIn(const Caption, Value : String);
    function  View(Index : Integer) : TMdFormView;
    procedure Place(Index : Integer; T : TMdType; X, Y : Integer);
    function  Press(Key : Word; Ctrl : Boolean; Target : TWinControl = nil) : Boolean;
    function  ParentOf(const Name : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestUndoAfterMovingToAnotherForm;
    procedure TestHandTest5UpToUndo;
    procedure TestUndoKeyOnTheTabs;
    procedure TestUndoKeyOnTheCanvas;
    procedure TestUndoKeyOnTheTree;
    procedure TestDeleteKeyOnTheCanvas;
    procedure TestNewDesignStartsANewHistory;
    procedure TestPaletteIsAlphabetical;
    procedure TestEveryCommandHasAnIcon;
  end;

implementation

type
  // Select is what the combo box does when an item is picked from its list.
  TPickCrack = class(TPickListCellEditor);
  // A click on the canvas.
  TViewCrack = class(TMdFormView);

  // Told when the component it watches is freed.
  TFreeWatch = class(TComponent)
  protected
    procedure Notification(AComponent : TComponent; Operation : TOperation); override;
  public
    Gone : Boolean;
  end;

procedure TFreeWatch.Notification(AComponent : TComponent; Operation : TOperation);
begin
  inherited Notification(AComponent,Operation);
  if Operation=opRemove then Gone:=True;
end;

type
  // Answers the next question the window asks: LCL's own modal dialog, or Windows' task dialog
  // (what MessageDlg shows when the program has a common-controls 6 manifest). A timer, since
  // both modal loops go on dispatching its ticks.
  TAnswer = class
  private
    Timer : TTimer;
    procedure Tick(Sender : TObject);
  public
    Reply : TModalResult;
    Done  : Boolean;
    constructor Create(AReply : TModalResult);
    destructor  Destroy; override;
  end;

constructor TAnswer.Create(AReply : TModalResult);
begin
  inherited Create;
  Reply:=AReply;
  Timer:=TTimer.Create(nil);
  Timer.Interval:=20;
  Timer.OnTimer:=Tick;
end;

destructor TAnswer.Destroy;
begin
  Timer.Free;
  inherited Destroy;
end;

procedure TAnswer.Tick(Sender : TObject);
var
  Cnt : Integer;
  H   : HWND;
  Pid : DWORD;
  Id  : Integer;
begin
  for Cnt:=0 to Screen.CustomFormCount-1 do
    if fsModal in Screen.CustomForms[Cnt].FormState then
    begin
      Screen.CustomForms[Cnt].ModalResult:=Reply;
      Done:=True;
    end;
  if not Done then
  begin
    case Reply of
      mrYes: Id:=IDYES;
      mrNo:  Id:=IDNO;
    else     Id:=IDCANCEL;
    end;
    H:=FindWindowEx(0,0,'#32770',nil);
    while H<>0 do
    begin
      GetWindowThreadProcessId(H,Pid);
      if (Pid=GetCurrentProcessId) and IsWindowVisible(H) then
      begin
        SendMessage(H,WM_USER+102,Id,0);   // TDM_CLICK_BUTTON
        Done:=True;
        Break;
      end;
      H:=FindWindowEx(0,H,'#32770',nil);
    end;
  end;
  if Done then Timer.Enabled:=False;
end;

procedure TMenuDesignerMainTests.SetUp;
begin
  Application.Initialize;
  Win:=TMdMainForm.Create(nil);
  Win.Show;
  Settle;
  Insp:=TMdInspector(Find(TMdInspector));
  Tree:=TTreeView(Find(TTreeView));
end;

procedure TMenuDesignerMainTests.TearDown;
begin
  Win.Free;
  Settle;
end;

procedure TMenuDesignerMainTests.Settle;
var
  Cnt : Integer;
begin
  for Cnt:=1 to 5 do
    Application.ProcessMessages;
end;

function TMenuDesignerMainTests.Find(AClass : TClass) : TComponent;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Win.ComponentCount-1 do
    if Win.Components[Cnt] is AClass then Exit(Win.Components[Cnt]);
  Fail('the window has a '+AClass.ClassName);
  Result:=nil;
end;

// A menu item by its caption without the '&', as a click on it.
procedure TMenuDesignerMainTests.Command(const Caption : String);

  function Search(M : TMenuItem) : Boolean;
  var
    Cnt : Integer;
  begin
    for Cnt:=0 to M.Count-1 do
    begin
      if StringReplace(M[Cnt].Caption,'&','',[rfReplaceAll])=Caption then
      begin
        M[Cnt].Click;
        Exit(True);
      end;
      if Search(M[Cnt]) then Exit(True);
    end;
    Result:=False;
  end;

begin
  AssertTrue('the menu has '+Caption, Search(Win.Menu.Items));
  Settle;
end;

procedure TMenuDesignerMainTests.ApplyScript(const Lines : array of String);
var
  Syn : TSynEdit;
  Cnt : Integer;
  B   : TButton;
begin
  Syn:=TSynEdit(Find(TSynEdit));
  Syn.Lines.Clear;
  for Cnt:=Low(Lines) to High(Lines) do
    Syn.Lines.Add(Lines[Cnt]);
  B:=nil;
  for Cnt:=0 to Win.ComponentCount-1 do
    if (Win.Components[Cnt] is TButton) and (Pos('Apply',TButton(Win.Components[Cnt]).Caption)=1) then
      B:=TButton(Win.Components[Cnt]);
  AssertTrue('there is an Apply button', B<>nil);
  B.Click;
  Settle;
end;

procedure TMenuDesignerMainTests.Pick(const Name : String);
var
  N : TTreeNode;
begin
  N:=Tree.Items.GetFirstNode;
  while (N<>nil) and (TMdComponent(N.Data).Name<>Name) do
    N:=N.GetNext;
  AssertTrue(Name+' is in the tree', N<>nil);
  Tree.Selected:=N;
  Tree.OnChange(Tree,N);   // as a click does; set in code, LCL may not call it
  Settle;
end;

function TMenuDesignerMainTests.Picked : TMdComponent;
begin
  AssertTrue('the tree has a selection', Tree.Selected<>nil);
  Result:=TMdComponent(Tree.Selected.Data);
end;

// What the user does: the cell gets its list, and an item of it is picked.
procedure TMenuDesignerMainTests.PickInList(const Caption, Value : String);
var
  Row : Integer;
  E   : TPickListCellEditor;
begin
  Row:=Insp.Strings.IndexOfName(Caption)+Insp.FixedRows;
  AssertTrue(Caption+' is a row: '+Insp.Strings.CommaText, Row>=Insp.FixedRows);
  Insp.Col:=1;
  Insp.Row:=Row;
  Insp.EditorMode:=True;
  AssertTrue('the cell has a list', Insp.Editor is TPickListCellEditor);
  E:=TPickListCellEditor(Insp.Editor);
  E.ItemIndex:=E.Items.IndexOf(Value);
  AssertTrue(Value+' is in the list', E.ItemIndex>=0);
  TPickCrack(E).Select;
  Settle;
end;

// What the user does: text typed into the cell, then Enter.
procedure TMenuDesignerMainTests.TypeIn(const Caption, Value : String);
var
  Row : Integer;
  Key : Char;
begin
  Row:=Insp.Strings.IndexOfName(Caption)+Insp.FixedRows;
  AssertTrue(Caption+' is a row: '+Insp.Strings.CommaText, Row>=Insp.FixedRows);
  Insp.Col:=1;
  Insp.Row:=Row;
  Insp.EditorMode:=True;
  AssertTrue('the cell has an editor', Insp.Editor is TCustomEdit);
  TCustomEdit(Insp.Editor).Text:=Value;
  Key:=#13;
  Insp.EditorKeyPress(Insp.Editor,Key);
  Settle;
end;

// The view on tab Index.
function TMenuDesignerMainTests.View(Index : Integer) : TMdFormView;
var
  Pages : TPageControl;
  Cnt   : Integer;

  function Search(W : TWinControl) : TMdFormView;
  var
    I : Integer;
  begin
    for I:=0 to W.ControlCount-1 do
    begin
      if W.Controls[I] is TMdFormView then Exit(TMdFormView(W.Controls[I]));
      if W.Controls[I] is TWinControl then
      begin
        Result:=Search(TWinControl(W.Controls[I]));
        if Result<>nil then Exit;
      end;
    end;
    Result:=nil;
  end;

begin
  Pages:=TPageControl(Find(TPageControl));
  AssertTrue('there is a tab '+IntToStr(Index), Index<Pages.PageCount);
  Result:=Search(Pages.Pages[Index]);
  AssertTrue('tab '+IntToStr(Index)+' has a view', Result<>nil);
  Cnt:=0;
end;

// A palette button, then a click on the form at X, Y (inside the form, below the title).
procedure TMenuDesignerMainTests.Place(Index : Integer; T : TMdType; X, Y : Integer);
var
  V : TMdFormView;
begin
  V:=View(Index);
  V.Placing:=True;
  V.PlaceType:=T;
  TViewCrack(V).MouseDown(mbLeft,[],X,Y+24);
  Settle;
  V:=View(Index);
  TViewCrack(V).MouseUp(mbLeft,[],X,Y+24);
  Settle;
end;

// Key pressed in Target (nil: the inspector's cell editor) through the window messages a key
// press sends, Ctrl down as GetKeyState reads it (the thread's keyboard state). The result: was
// Target still there when its key-down message returned? What the key starts must not free the
// control while that control is still handling it.
function TMenuDesignerMainTests.Press(Key : Word; Ctrl : Boolean; Target : TWinControl) : Boolean;
var
  Keys  : TKeyboardState;
  Old   : TKeyboardState;
  H     : HWND;
  Edit  : HWND;
  Watch : TFreeWatch;
begin
  if Target=nil then
  begin
    AssertTrue('the inspector has its editor', Insp.Editor<>nil);
    Target:=TWinControl(Insp.Editor);
  end;
  H:=Target.Handle;
  Edit:=FindWindowEx(H,0,'Edit',nil);   // a combo box's text is a child window
  if Edit<>0 then H:=Edit;
  Watch:=TFreeWatch.Create(nil);
  try
    Target.FreeNotification(Watch);
    GetKeyboardState(Old);
    Keys:=Old;
    if Ctrl then Keys[VK_CONTROL]:=$80;
    SetKeyboardState(Keys);
    try
      SendMessage(H,WM_KEYDOWN,Key,1);
      Result:=not Watch.Gone;
      if Ctrl and not Watch.Gone then SendMessage(H,WM_CHAR,Key-Ord('A')+1,1);
      Settle;
    finally
      SetKeyboardState(Old);
    end;
    if not Watch.Gone then SendMessage(H,WM_KEYUP,Key,LPARAM($C0000001));
    Settle;
  finally
    Watch.Free;   // takes itself off Target's list, if Target is still there
  end;
end;

function TMenuDesignerMainTests.ParentOf(const Name : String) : String;
var
  N : TTreeNode;
begin
  N:=Tree.Items.GetFirstNode;
  while (N<>nil) and (TMdComponent(N.Data).Name<>Name) do
    N:=N.GetNext;
  AssertTrue(Name+' is in the tree', N<>nil);
  Result:=TMdComponent(N.Data).Parent.Name;
end;

procedure TMenuDesignerMainTests.TestUndoAfterMovingToAnotherForm;
begin
  ApplyScript(['menu reforge mode 1.6',
               'menu form options 300 100 160 80 Options',
               'menu setdef parent options',
               'menu button ok 10 10 60 25 OK']);
  AssertEquals('options', ParentOf('ok'));
  Pick('ok');
  PickInList('Parent','form0');
  AssertEquals('moved', 'form0', ParentOf('ok'));
  Command('Undo');
  AssertEquals('back', 'options', ParentOf('ok'));
  Command('Redo');
  AssertEquals('moved again', 'form0', ParentOf('ok'));
end;

// Hand test 5, steps 1 to 6, in the order the owner did them.
procedure TMenuDesignerMainTests.TestHandTest5UpToUndo;
begin
  Command('New form');
  Command('New form');
  Place(0,mdtButton,20,20);
  Place(1,mdtButton,20,20);
  Place(2,mdtButton,20,20);
  Pick('form1');
  PickInList('Shown','yes');
  PickInList('Shown','no');
  Pick('form1');
  TypeIn('Name','options');
  Pick('button2');
  AssertEquals('options', ParentOf('button2'));
  TypeIn('Name','ok');
  Pick('button3');
  TypeIn('Name','ok');
  AssertEquals('refused', 'form2', ParentOf('button3'));
  Pick('form2');
  Command('Move left');
  Pick('form0');
  Command('Move left');
  Command('Move right');
  Pick('ok');
  PickInList('Parent','form0');
  AssertEquals('moved', 'form0', ParentOf('ok'));
  AssertTrue('the cell editor outlives its key', Press(Ord('Z'),True));
  AssertEquals('back', 'options', ParentOf('ok'));
end;

// Ctrl+Z with the tabs focused, as after a click on a tab to look at the moved component.
procedure TMenuDesignerMainTests.TestUndoKeyOnTheTabs;
var
  Pages : TPageControl;
begin
  Command('New form');
  Place(1,mdtButton,20,20);
  Pick('button1');
  PickInList('Parent','form0');
  AssertEquals('moved', 'form0', ParentOf('button1'));
  Pages:=TPageControl(Find(TPageControl));
  Pages.ActivePageIndex:=0;
  Settle;
  AssertTrue('the tabs outlive their key', Press(Ord('Z'),True,Pages));
  AssertEquals('back', 'form1', ParentOf('button1'));
end;

// Ctrl+Z with a canvas focused, as after a click on the moved component. Undo frees every view;
// it used to do so inside the focused view's key handler, which then wrote into whatever was
// made in its memory next (an access violation later, when that memory was reused).
procedure TMenuDesignerMainTests.TestUndoKeyOnTheCanvas;
begin
  Command('New form');
  Place(1,mdtButton,20,20);
  Pick('button1');
  PickInList('Parent','form0');
  AssertEquals('moved', 'form0', ParentOf('button1'));
  AssertTrue('the view outlives its key', Press(Ord('Z'),True,View(0)));
  AssertEquals('back', 'form1', ParentOf('button1'));
end;

// Del on the canvas: deleting rebuilds every view too.
procedure TMenuDesignerMainTests.TestDeleteKeyOnTheCanvas;
var
  V : TMdFormView;
begin
  Place(0,mdtButton,20,20);
  AssertEquals('placed', 'form0', ParentOf('button1'));
  V:=View(0);
  Win.ActiveControl:=V;
  AssertTrue('the view outlives its key', Press(VK_DELETE,False,V));
  AssertTrue('deleted', Tree.Items.Count=1);
end;

// Ctrl+Z with the tree focused, as after a click on the moved component in it.
procedure TMenuDesignerMainTests.TestUndoKeyOnTheTree;
begin
  Command('New form');
  Place(1,mdtButton,20,20);
  Pick('button1');
  PickInList('Parent','form0');
  AssertEquals('moved', 'form0', ParentOf('button1'));
  Pick('button1');
  AssertTrue('the tree outlives its key', Press(Ord('Z'),True,Tree));
  AssertEquals('back', 'form1', ParentOf('button1'));
end;

// New design (Open and Paste script likewise) starts a history of its own: Undo used to go back
// into the design before, under the new one's file name, for Save to write over that file.
procedure TMenuDesignerMainTests.TestNewDesignStartsANewHistory;
var
  A : TAnswer;
begin
  Place(0,mdtButton,20,20);
  Place(0,mdtButton,20,60);
  AssertEquals('form0 and two buttons', 3, Tree.Items.Count);
  A:=TAnswer.Create(mrNo);   // "Save the changes?"
  try
    Command('New design');
    AssertTrue('the save question was asked', A.Done);
  finally
    A.Free;
  end;
  AssertEquals('a new design', 1, Tree.Items.Count);
  Command('Undo');
  AssertEquals('Undo brings nothing back', 1, Tree.Items.Count);
  Command('Redo');
  AssertEquals('nor does Redo', 1, Tree.Items.Count);
end;

// The palette's buttons, top to bottom: every kind of control but a form, by name, each with its
// icon.
procedure TMenuDesignerMainTests.TestPaletteIsAlphabetical;
var
  L   : TList;
  Cnt : Integer;
  B   : TSpeedButton;
  S   : String;
  T   : TMdType;
  N   : Integer;
begin
  L:=TList.Create;
  try
    for Cnt:=0 to Win.ComponentCount-1 do
      if Win.Components[Cnt] is TSpeedButton then
      begin
        B:=TSpeedButton(Win.Components[Cnt]);
        N:=0;
        while (N<L.Count) and (TSpeedButton(L[N]).Top<B.Top) do Inc(N);
        L.Insert(N,B);
      end;
    N:=0;
    for T:=Low(TMdType) to High(TMdType) do
      if T<>mdtForm then Inc(N);
    AssertEquals('one button per kind of control', N, L.Count);
    S:='';
    for Cnt:=0 to L.Count-1 do
    begin
      B:=TSpeedButton(L[Cnt]);
      AssertTrue(B.Caption+' has an icon', (B.Images<>nil) and (B.ImageIndex>=0) and
        (B.ImageIndex<B.Images.Count));
      AssertTrue(B.Caption+' after '+S, CompareText(S,B.Caption)<0);
      S:=B.Caption;
    end;
  finally
    L.Free;
  end;
end;

// Every command in the menu and on the toolbar has an icon, but the View toggles, whose check
// mark shows instead.
procedure TMenuDesignerMainTests.TestEveryCommandHasAnIcon;
var
  Bar  : TToolBar;
  Cnt  : Integer;
  Imgs : Integer;

  procedure Walk(M : TMenuItem);
  var
    I : Integer;
  begin
    for I:=0 to M.Count-1 do
    begin
      if M[I].Count>0 then Walk(M[I])
      else if (M[I].Caption<>'-') and not M[I].AutoCheck and
              (Pos('Show',M[I].Caption)<>1) and (Pos('Snap',M[I].Caption)<>1) then
        AssertTrue(M[I].Caption+' has an icon', (M[I].ImageIndex>=0) and (M[I].ImageIndex<Imgs));
    end;
  end;

begin
  AssertEquals('the align icons follow TMdAlignOp', Ord(icSameSize)-Ord(icAlignLeft),
    Ord(High(TMdAlignOp)));
  AssertTrue('the menu has its images', Win.Menu.Images<>nil);
  Imgs:=Win.Menu.Images.Count;
  AssertEquals('one image per icon', Ord(High(TMdIcon))+1, Imgs);
  Walk(Win.Menu.Items);
  Bar:=TToolBar(Find(TToolBar));
  AssertTrue('the toolbar has the same images', Bar.Images=Win.Menu.Images);
  for Cnt:=0 to Bar.ButtonCount-1 do
    if Bar.Buttons[Cnt].Style<>tbsSeparator then
      AssertTrue(Bar.Buttons[Cnt].Caption+' has an icon', (Bar.Buttons[Cnt].ImageIndex>=0) and
        (Bar.Buttons[Cnt].ImageIndex<Imgs));
end;

initialization
  RegisterTest(TMenuDesignerMainTests);
end.
