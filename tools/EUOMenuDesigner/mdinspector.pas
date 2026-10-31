unit mdinspector;

{
  Port addition: the MENU Designer's property inspector (docs/menu-designer.md, section 9). The
  rows of a component come from the tables: its 1.6 properties from EuoMenu16's own table
  (MdTypeHasProp), the values only creating lines carry from its row in MdTypeRows. A value is
  shown and read the way the script writes it: colours by name or number, booleans yes/no. The
  rows are in alphabetical order of their captions.

  A row the generator had to warn about is drawn in red (Warnings, from the main window).

  When a typed value reaches the model: on Enter or a move to another cell (OnValidateEntry), on
  a choice from a pick list, when the cell loses the focus (OnEditingDone), and before the
  inspector shows another component -- whichever comes first. TValueListEditor's OnValidate is
  never called by this LCL, so it is not used. The value goes to the component it was typed for,
  and only after the grid's own event has finished (QueueAsyncCall): applying it rebuilds the
  rows, which the grid must not see from inside its own event.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, Math, Graphics, Controls, Forms, StdCtrls, ExtCtrls, Dialogs, Grids, ValEdit,
  mdtypes, mdmodel;

type
  TMdMessageEvent = procedure(const S : String) of object;

  // A value typed into a cell, on its way into the model.
  TMdPendingEdit = class
  public
    Doc   : TMdDocument;
    Comp  : TMdComponent;
    Key   : String;
    Value : String;
    Whole : Boolean;    // ChangedLater: the change was between forms
  end;

  TMdInspector = class(TValueListEditor)
  private
    FDoc      : TMdDocument;
    FComp     : TMdComponent;
    Shows     : TMdComponent;     // the component the rows were loaded for
    Keys      : TStringList;
    Shown     : TStringList;      // each row's value as it was loaded
    Pending   : TMdPendingEdit;
    Loading   : Boolean;
    procedure AddRow(const Key, Caption, Value : String; Style : TEditStyle;
                const Picks : array of String; ReadOnlyRow : Boolean = False);
    function  KeyOfRow(ARow : Integer) : String;
    procedure DoSetEditText(Sender : TObject; ACol, ARow : Integer; const Value : String);
    procedure DoValidateEntry(Sender : TObject; ACol, ARow : Integer; const OldValue : String;
                var NewValue : String);
    procedure DoPickListSelect(Sender : TObject);
    procedure DoEditingDone(Sender : TObject);
    procedure Commit;
    procedure ApplyQueued(Data : PtrInt);
    procedure ChangedQueued(Data : PtrInt);
    procedure ChangedLater(C : TMdComponent; WholeDoc : Boolean);
    function  StillThere(D : TMdDocument; C : TMdComponent) : Boolean;
    procedure DoButton(Sender : TObject; ACol, ARow : Integer);
    procedure DoPrepare(Sender : TObject; ACol, ARow : Integer; AState : TGridDrawState);
    function  Apply(C : TMdComponent; const Key, Value : String; out Problem : String;
                out WholeDoc : Boolean) : Boolean;
    function  Containers : TStringList;
    procedure Changed(C : TMdComponent; WholeDoc : Boolean);
  public
    Warnings       : TStringList;
    OnBeforeChange : TNotifyEvent;
    OnAfterChange  : TMdChangeEvent;
    OnMessage      : TMdMessageEvent;
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
    procedure   ShowComponent(ADoc : TMdDocument; C : TMdComponent);
    procedure   Refresh;
  end;

function ColorText(C : Integer) : String;
function ReadColor(const S : String; out C : Integer) : Boolean;
function StyleText(S : Integer) : String;
function LinesDialog(const Title, Hint : String; Lines : TStrings; out Memo : TMemo) : TForm;
function EditLines(const Title, Hint : String; Lines : TStrings) : Boolean;

implementation

uses
  EuoConversion, EuoMenuCommon, EuoMenuSelect, mdgenerate, mdimport;

const
  ShapeNames : array[0..6] of String = ('0 rectangle', '1 circle', '2 ellipse', '3 rectangle',
    '4 rectangle', '5 square', '6 nothing');
  YesNo : array[0..1] of String = ('yes', 'no');
  AlignNames : array[0..2] of String = ('left', 'right', 'centre');
  LineMark = '¶';   // a line break, as the cell shows it

function YN(B : Boolean) : String;
begin
  if B then Result:='yes' else Result:='no';
end;

function ColorText(C : Integer) : String;
var
  Ident : String;
begin
  if ColorToIdent(ColorFromVcl(C),Ident) and (Copy(Ident,1,2)='cl') then
    Result:=Copy(Ident,3,MaxInt)
  else Result:=IntToStr(C);
end;

// A colour as the script commands read it: a number, or a colour name (with or without cl).
function ReadColor(const S : String; out C : Integer) : Boolean;
var
  V : Integer;
  T : String;
begin
  T:=Trim(S);
  if SameText(Copy(T,1,2),'cl') and not IsNumber(T) then T:=Copy(T,3,MaxInt);
  V:=SToCol(T,Result);
  if Result then C:=ColorToVcl(V);
end;

function StyleText(S : Integer) : String;
begin
  Result:='';
  if S and 1<>0 then Result:=Result+'bold ';
  if S and 2<>0 then Result:=Result+'italic ';
  if S and 4<>0 then Result:=Result+'underline ';
  if S and 8<>0 then Result:=Result+'strikeout ';
  Result:=Trim(Result);
  if Result='' then Result:='plain';
end;

function ReadStyle(const S : String) : Integer;
var
  L : String;
begin
  L:=LowerCase(S);
  Result:=0;
  if Pos('bold',L)>0 then Result:=Result or 1;
  if Pos('italic',L)>0 then Result:=Result or 2;
  if Pos('underline',L)>0 then Result:=Result or 4;
  if Pos('strike',L)>0 then Result:=Result or 8;
end;

function ShownText(const S : String) : String;
begin
  Result:=StringReplace(S,#13#10,LineMark,[rfReplaceAll]);
end;

// A small dialog with a memo: one line per item or drawing operation. EditLines shows it.
// The buttons are anchored to the panel's right edge and to each other: the panel has its
// width only once the window is shown, so positions worked out from it beforehand land outside.
function LinesDialog(const Title, Hint : String; Lines : TStrings; out Memo : TMemo) : TForm;
var
  F      : TForm;
  L      : TLabel;
  P      : TPanel;
  OK     : TButton;
  Cancel : TButton;
begin
  F:=TForm.CreateNew(nil);
  F.Caption:=Title;
  F.Position:=poScreenCenter;
  F.Width:=480;
  F.Height:=360;
  L:=TLabel.Create(F);
  L.Parent:=F;
  L.Align:=alTop;
  L.WordWrap:=True;
  L.BorderSpacing.Around:=6;
  L.Caption:=Hint;
  P:=TPanel.Create(F);
  P.Parent:=F;
  P.Align:=alBottom;
  P.Height:=40;
  P.BevelOuter:=bvNone;
  Cancel:=TButton.Create(F);
  Cancel.Parent:=P;
  Cancel.Caption:='Cancel';
  Cancel.ModalResult:=mrCancel;
  Cancel.Cancel:=True;
  Cancel.SetBounds(0,8,80,26);
  Cancel.AnchorSideRight.Control:=P;
  Cancel.AnchorSideRight.Side:=asrRight;
  Cancel.BorderSpacing.Right:=8;
  Cancel.Anchors:=[akTop,akRight];
  OK:=TButton.Create(F);
  OK.Parent:=P;
  OK.Caption:='OK';
  OK.ModalResult:=mrOK;
  OK.Default:=True;
  OK.SetBounds(0,8,80,26);
  OK.AnchorSideRight.Control:=Cancel;
  OK.AnchorSideRight.Side:=asrLeft;
  OK.BorderSpacing.Right:=6;
  OK.Anchors:=[akTop,akRight];
  Memo:=TMemo.Create(F);
  Memo.Parent:=F;
  Memo.Align:=alClient;
  Memo.ScrollBars:=ssAutoBoth;
  Memo.WordWrap:=False;
  Memo.Font.Name:='Courier New';
  Memo.Lines.Assign(Lines);
  Result:=F;
end;

function EditLines(const Title, Hint : String; Lines : TStrings) : Boolean;
var
  F : TForm;
  M : TMemo;
begin
  F:=LinesDialog(Title,Hint,Lines,M);
  try
    Result:=F.ShowModal=mrOK;
    if Result then Lines.Assign(M.Lines);
  finally
    F.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TMdInspector.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  Keys:=TStringList.Create;
  Shown:=TStringList.Create;
  Warnings:=TStringList.Create;
  TitleCaptions.Clear;
  TitleCaptions.Add('Property');
  TitleCaptions.Add('Value');
  KeyOptions:=[];
  DisplayOptions:=[doColumnTitles,doAutoColResize,doKeyColFixed];
  Options:=Options+[goEditing,goAlwaysShowEditor]-[goRowSelect];
  OnSetEditText:=DoSetEditText;
  OnValidateEntry:=DoValidateEntry;
  OnPickListSelect:=DoPickListSelect;
  OnEditingDone:=DoEditingDone;
  OnButtonClick:=DoButton;
  OnPrepareCanvas:=DoPrepare;
  ColWidths[0]:=110;
end;

destructor TMdInspector.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  Pending.Free;
  Warnings.Free;
  Shown.Free;
  Keys.Free;
  inherited Destroy;
end;

procedure TMdInspector.AddRow(const Key, Caption, Value : String; Style : TEditStyle;
  const Picks : array of String; ReadOnlyRow : Boolean);
var
  Cnt : Integer;
  Row : Integer;
begin
  // in alphabetical order of the captions
  Row:=0;
  while (Row<Strings.Count) and (CompareText(Strings.Names[Row],Caption)<=0) do Inc(Row);
  Strings.Insert(Row,Caption+'='+Value);
  Keys.Insert(Row,Key);
  Shown.Insert(Row,Value);
  ItemProps[Row].EditStyle:=Style;
  ItemProps[Row].ReadOnly:=ReadOnlyRow;
  if Style=esPickList then
    for Cnt:=Low(Picks) to High(Picks) do
      ItemProps[Row].PickList.Add(Picks[Cnt]);
end;

function TMdInspector.KeyOfRow(ARow : Integer) : String;
begin
  if (ARow>=1) and (ARow-1<Keys.Count) then Result:=Keys[ARow-1] else Result:='';
end;

function TMdInspector.Containers : TStringList;
var
  L   : TList;
  Cnt : Integer;
  C   : TMdComponent;
  Up  : TMdComponent;
  In_ : Boolean;
begin
  Result:=TStringList.Create;
  L:=TList.Create;
  try
    FDoc.AllComponents(L);
    for Cnt:=0 to L.Count-1 do
    begin
      C:=TMdComponent(L[Cnt]);
      if not C.IsContainer or (C=FComp) then Continue;
      In_:=False;
      Up:=C;
      while Up<>nil do
      begin
        if Up=FComp then In_:=True;
        Up:=Up.Parent;
      end;
      if not In_ then Result.Add(C.Name);
    end;
  finally
    L.Free;
  end;
end;

procedure TMdInspector.ShowComponent(ADoc : TMdDocument; C : TMdComponent);
begin
  if (C<>FComp) or (ADoc<>FDoc) then Commit;   // what was typed for the last one still goes in
  FDoc:=ADoc;
  FComp:=C;
  Refresh;
end;

procedure TMdInspector.Refresh;
var
  R    : TMdTypeRow;
  C    : TMdComponent;
  Box  : TStringList;
  Cnt  : Integer;
  S    : String;
  Picks: array of String;
  A    : array of String;
  Edit : Boolean;
  Keep : Integer;

  function Has(const P : String) : Boolean;
  begin
    Result:=MdTypeHasProp(C.TypeId,P);
  end;

begin
  Commit;   // what was typed goes in before the rows show the model again
  Loading:=True;
  // The rows are rebuilt with the editor away, as TValueListEditor.Sort does: a cell editor
  // left showing writes its old text back into the new rows.
  Edit:=goAlwaysShowEditor in Options;
  if Edit then Options:=Options-[goAlwaysShowEditor];
  EditorMode:=False;
  if FComp=Shows then Keep:=Row else Keep:=-1;   // the same component: the same row
  Shows:=FComp;
  try
    Strings.Clear;
    Keys.Clear;
    Shown.Clear;
    C:=FComp;
    if C=nil then Exit;
    R:=C.Row;
    AddRow('name','Name',C.Name,esSimple,[]);
    S:=R.Name;
    if R.Reforged then S:=S+' (Reforged only)';
    AddRow('type','Type',S,esSimple,[],True);

    if C.IsForm then
    begin
      AddRow('text','Title',C.Text,esSimple,[]);
      AddRow('left','Left (screen)',IntToStr(C.Left),esSimple,[]);
      AddRow('top','Top (screen)',IntToStr(C.Top),esSimple,[]);
      AddRow('width','Width (inside)',IntToStr(C.Width),esSimple,[]);
      AddRow('height','Height (inside)',IntToStr(C.Height),esSimple,[]);
      AddRow('color','Colour',ColorText(C.Color),esEllipsis,[]);
      AddRow('visible','Shown',YN(C.Visible),esPickList,YesNo);
      AddRow('enabled','Enabled',YN(C.Enabled),esPickList,YesNo);
      AddRow('tooltip','Tooltip',C.Tooltip,esSimple,[]);
      if C.IsForm0 then
      begin
        if C.Transparency<0 then S:='none' else S:=IntToStr(C.Transparency);
        AddRow('transparency','Transparency',S,esPickList,['none','0','25','50','75','100']);
      end;
      Exit;
    end;

    AddRow('left','Left',IntToStr(C.Left),esSimple,[]);
    AddRow('top','Top',IntToStr(C.Top),esSimple,[]);
    if R.W=szAuto then AddRow('fixedw','Width fixed',YN(C.FixedW),esPickList,YesNo);
    AddRow('width','Width',IntToStr(C.Width),esSimple,[],R.W=szFit);
    if R.H=szAuto then AddRow('fixedh','Height fixed',YN(C.FixedH),esPickList,YesNo);
    AddRow('height','Height',IntToStr(C.Height),esSimple,[],R.H=szFit);
    if Has('text') then
    begin
      if R.DollarBreak then AddRow('text','Text',ShownText(C.Text),esEllipsis,[])
      else AddRow('text','Text',C.Text,esSimple,[]);
    end;
    case R.Align of
      maText:  AddRow('alignment','Alignment',AlignNames[Max(0,Min(2,C.Alignment))],esPickList,
                 AlignNames);
      maCheck: if C.Alignment=1 then AddRow('alignment','Text side','left',esPickList,['right','left'])
               else AddRow('alignment','Text side','right',esPickList,['right','left']);
    end;
    if Has('checked') then AddRow('checked','Checked',YN(C.Checked),esPickList,YesNo);
    if Has('color') then AddRow('color','Colour',ColorText(C.Color),esEllipsis,[]);
    if Has('fontname') then
    begin
      SetLength(A,Screen.Fonts.Count);
      for Cnt:=0 to Screen.Fonts.Count-1 do
        A[Cnt]:=Screen.Fonts[Cnt];
      AddRow('fontname','Font',C.FontName,esPickList,A);
      AddRow('fontsize','Font size',IntToStr(C.FontSize),esSimple,[]);
      AddRow('fontstyle','Font style',StyleText(C.FontStyle),esEllipsis,[]);
      AddRow('fontcolor','Font colour',ColorText(C.FontColor),esEllipsis,[]);
    end;
    if R.Items then
    begin
      S:='';
      for Cnt:=0 to C.Items.Count-1 do
        S:=S+C.Items[Cnt]+'; ';
      AddRow('items','Items',Trim(S),esEllipsis,[],True);
      AddRow('selected','Selected',IntToStr(C.Selected),esSimple,[]);
    end;
    if C.TypeId=mdtShape then
    begin
      AddRow('shapestyle','Shape',ShapeNames[Max(0,Min(6,C.ShapeStyle))],esPickList,ShapeNames);
      AddRow('lineon','Line',YN(C.LineOn),esPickList,YesNo);
      AddRow('linewidth','Line width',IntToStr(C.LineWidth),esSimple,[]);
      AddRow('linecolor','Line colour',ColorText(C.LineColor),esEllipsis,[]);
      AddRow('fillon','Fill',YN(C.FillOn),esPickList,YesNo);
      AddRow('fillcolor','Fill colour',ColorText(C.FillColor),esEllipsis,[]);
    end;
    if R.Drawing or (C.TypeId=mdtShape) then
    begin
      AddRow('stretch','Stretched',YN(C.Stretch),esPickList,YesNo);
      if C.Stretch then
      begin
        AddRow('bitmapw','Picture width',IntToStr(C.BitmapW),esSimple,[]);
        AddRow('bitmaph','Picture height',IntToStr(C.BitmapH),esSimple,[]);
      end;
    end;
    if R.Drawing then
      AddRow('drawing','Drawing',IntToStr(Length(C.Ops))+' operations',esEllipsis,[],True);
    if Has('tooltip') then AddRow('tooltip','Tooltip',C.Tooltip,esSimple,[]);
    if Has('enabled') then AddRow('enabled','Enabled',YN(C.Enabled),esPickList,YesNo);
    if Has('visible') then AddRow('visible','Visible',YN(C.Visible),esPickList,YesNo);
    if Has('parent') then
    begin
      Box:=Containers;
      try
        SetLength(Picks,Box.Count);
        for Cnt:=0 to Box.Count-1 do
          Picks[Cnt]:=Box[Cnt];
      finally
        Box.Free;
      end;
      AddRow('parent','Parent',C.Parent.Name,esPickList,Picks);
    end;
  finally
    if (Keep>=FixedRows) and (Keep<RowCount) then Row:=Keep;
    if Edit then Options:=Options+[goAlwaysShowEditor];
    Loading:=False;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdInspector.Changed(C : TMdComponent; WholeDoc : Boolean);
begin
  if not Assigned(OnAfterChange) then Exit;
  if WholeDoc then OnAfterChange(nil) else OnAfterChange(C.FormOf);
end;

// After the grid's event: the dialogs of DoButton changed the model while the grid was in one.
procedure TMdInspector.ChangedLater(C : TMdComponent; WholeDoc : Boolean);
var
  E : TMdPendingEdit;
begin
  E:=TMdPendingEdit.Create;
  E.Doc:=FDoc;
  E.Comp:=C;
  E.Whole:=WholeDoc;
  Application.QueueAsyncCall(ChangedQueued,PtrInt(E));
end;

procedure TMdInspector.ChangedQueued(Data : PtrInt);
var
  E : TMdPendingEdit;
begin
  E:=TMdPendingEdit(Data);
  try
    if (E.Doc=FDoc) and StillThere(E.Doc,E.Comp) then Changed(E.Comp,E.Whole);
  finally
    E.Free;
  end;
end;

function TMdInspector.StillThere(D : TMdDocument; C : TMdComponent) : Boolean;
var
  L : TList;
begin
  L:=TList.Create;
  try
    D.AllComponents(L);
    Result:=L.IndexOf(C)>=0;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Typing: what the cell holds now, if it is not what was loaded into it.
procedure TMdInspector.DoSetEditText(Sender : TObject; ACol, ARow : Integer; const Value : String);
var
  Key : String;
begin
  if Loading or (FComp=nil) or (ACol<>1) then Exit;
  Key:=KeyOfRow(ARow);
  if (Key='') or (Key='type') or (Key='items') or (Key='drawing') then Exit;
  if (ARow-1<Shown.Count) and (Value=Shown[ARow-1]) then
  begin
    if (Pending<>nil) and (Pending.Key=Key) then FreeAndNil(Pending);   // typed back
    Exit;
  end;
  if (Pending<>nil) and (Pending.Key<>Key) then Commit;   // another row: the last one goes in
  if Pending=nil then Pending:=TMdPendingEdit.Create;
  Pending.Doc:=FDoc;
  Pending.Comp:=FComp;
  Pending.Key:=Key;
  Pending.Value:=Value;
end;

procedure TMdInspector.DoValidateEntry(Sender : TObject; ACol, ARow : Integer;
  const OldValue : String; var NewValue : String);
begin
  if Loading then Exit;
  DoSetEditText(Sender,ACol,ARow,NewValue);
  Commit;
end;

procedure TMdInspector.DoPickListSelect(Sender : TObject);
begin
  Commit;
end;

procedure TMdInspector.DoEditingDone(Sender : TObject);
begin
  if not Loading then Commit;
end;

// The pending value on its way; until the rows are loaded again it counts as the row's value,
// so the grid writing it back into the cell is not taken for another edit.
procedure TMdInspector.Commit;
var
  Row : Integer;
begin
  if Pending=nil then Exit;
  Row:=Keys.IndexOf(Pending.Key);
  if (Pending.Comp=FComp) and (Row>=0) and (Row<Shown.Count) then Shown[Row]:=Pending.Value;
  Application.QueueAsyncCall(ApplyQueued,PtrInt(Pending));
  Pending:=nil;
end;

procedure TMdInspector.ApplyQueued(Data : PtrInt);
var
  E       : TMdPendingEdit;
  Problem : String;
  Whole   : Boolean;
begin
  E:=TMdPendingEdit(Data);
  try
    if (E.Doc<>FDoc) or not StillThere(E.Doc,E.Comp) then Exit;
    if Assigned(OnBeforeChange) then OnBeforeChange(Self);
    if Apply(E.Comp,E.Key,E.Value,Problem,Whole) then Changed(E.Comp,Whole)
    else
    begin
      if Assigned(OnMessage) then OnMessage(Problem);
      Changed(E.Comp,False);   // shows the value as it was
    end;
  finally
    E.Free;
  end;
end;

// The value typed into a row, into the model; False with the reason when it cannot be.
function TMdInspector.Apply(C : TMdComponent; const Key, Value : String; out Problem : String;
  out WholeDoc : Boolean) : Boolean;
var
  V   : String;
  I   : Integer;
  Col : Integer;
  P   : TMdComponent;

  function Int(out N : Integer) : Boolean;
  begin
    Result:=TryStrToInt(Trim(V),N);
    if not Result then Problem:='"'+V+'" is not a whole number.';
  end;

  function Yes : Boolean;
  begin
    Result:=SameText(Trim(V),'yes') or (Trim(V)='1') or SameText(Trim(V),'true');
  end;

begin
  Result:=False;
  Problem:='';
  WholeDoc:=False;
  V:=Value;
  if Key='name' then
  begin
    V:=LowerCase(Trim(V));
    if V=C.Name then Exit(True);
    if C.IsForm0 then
    begin
      Problem:='form0 is the main window: its name cannot change.';
      Exit;
    end;
    Problem:=FDoc.NameProblem(V,C);
    if Problem<>'' then Exit;
    C.Name:=V;
    WholeDoc:=True;
  end
  else if (Key='left') or (Key='top') or (Key='width') or (Key='height') or (Key='fontsize') or
          (Key='selected') or (Key='linewidth') or (Key='bitmapw') or (Key='bitmaph') then
  begin
    if not Int(I) then Exit;
    if Key='left' then C.Left:=I
    else if Key='top' then C.Top:=I
    else if Key='width' then
    begin
      C.Width:=I;
      if C.Row.W=szAuto then C.FixedW:=True;
      if (C.Row.Drawing or (C.TypeId=mdtShape)) and not C.Stretch then C.BitmapW:=I;
    end
    else if Key='height' then
    begin
      C.Height:=I;
      if C.Row.H=szAuto then C.FixedH:=True;
      if (C.Row.Drawing or (C.TypeId=mdtShape)) and not C.Stretch then C.BitmapH:=I;
    end
    else if Key='fontsize' then C.FontSize:=I
    else if Key='selected' then
    begin
      if (I<0) or (I>C.Items.Count) then
      begin
        Problem:='Selected is 0 (none) or the number of an item, 1 to '+IntToStr(C.Items.Count)+'.';
        Exit;
      end;
      C.Selected:=I;
    end
    else if Key='linewidth' then C.LineWidth:=I
    else if Key='bitmapw' then C.BitmapW:=I
    else if Key='bitmaph' then C.BitmapH:=I;
    if (C.TypeId=mdtShape) and (C.ShapeStyle in [1,5,6]) and ((Key='width') or (Key='height')) then
    begin
      C.Width:=I;
      C.Height:=I;
      C.BitmapW:=I;
      C.BitmapH:=I;
    end;
  end
  else if Key='text' then
  begin
    if C.Row.DollarBreak then C.Text:=StringReplace(V,LineMark,#13#10,[rfReplaceAll])
    else C.Text:=V;
  end
  else if Key='tooltip' then C.Tooltip:=V
  else if (Key='color') or (Key='fontcolor') or (Key='linecolor') or (Key='fillcolor') then
  begin
    if not ReadColor(V,Col) then
    begin
      Problem:='"'+V+'" is not a colour: a number, or a name such as red or BtnFace.';
      Exit;
    end;
    if Key='color' then C.Color:=Col
    else if Key='fontcolor' then C.FontColor:=Col
    else if Key='linecolor' then C.LineColor:=Col
    else C.FillColor:=Col;
  end
  else if Key='fontname' then
  begin
    if Trim(V)='' then
    begin
      Problem:='A font name is needed.';
      Exit;
    end;
    C.FontName:=Trim(V);
  end
  else if Key='fontstyle' then C.FontStyle:=ReadStyle(V)
  else if Key='alignment' then
  begin
    if C.Row.Align=maCheck then
    begin
      if SameText(Trim(V),'left') then C.Alignment:=1 else C.Alignment:=0;
    end
    else if SameText(Trim(V),'right') then C.Alignment:=1
    else if SameText(Copy(Trim(V),1,4),'cent') then C.Alignment:=2
    else C.Alignment:=0;
  end
  else if Key='checked' then FDoc.SetChecked(C,Yes)
  else if Key='enabled' then C.Enabled:=Yes
  else if Key='visible' then C.Visible:=Yes
  else if Key='fixedw' then C.FixedW:=Yes
  else if Key='fixedh' then C.FixedH:=Yes
  else if Key='lineon' then C.LineOn:=Yes
  else if Key='fillon' then C.FillOn:=Yes
  else if Key='stretch' then
  begin
    C.Stretch:=Yes;
    if not C.Stretch then
    begin
      C.Width:=C.BitmapW;
      C.Height:=C.BitmapH;
    end;
  end
  else if Key='shapestyle' then
  begin
    I:=StrToIntDef(Copy(Trim(V),1,1),0);
    C.ShapeStyle:=I;
    if I in [1,5,6] then
    begin
      C.Height:=C.Width;
      C.BitmapW:=C.Width;
      C.BitmapH:=C.Width;
    end;
  end
  else if Key='transparency' then
  begin
    if SameText(Trim(V),'none') or (Trim(V)='') then C.Transparency:=-1
    else
    begin
      if not Int(I) or (I<0) or (I>100) then
      begin
        Problem:='Transparency is none or 0 to 100.';
        Exit;
      end;
      C.Transparency:=I;
    end;
  end
  else if Key='parent' then
  begin
    P:=FDoc.FindName(Trim(V));
    if (P=nil) or not FDoc.CanMoveTo(C,P) then
    begin
      Problem:='"'+V+'" is not a form or a panel this can go into.';
      Exit;
    end;
    FDoc.MoveTo(C,P);
    WholeDoc:=True;
  end;
  Result:=True;
end;

procedure TMdInspector.DoButton(Sender : TObject; ACol, ARow : Integer);
var
  Key   : String;
  C     : TMdComponent;
  L     : TStringList;
  CD    : TColorDialog;
  FD    : TFontDialog;
  Cnt   : Integer;
  W     : TStringList;
  Op    : TMdDrawOp;
  Known : Boolean;
  Bad   : String;
  Col   : Integer;
  Ops   : array of TMdDrawOp;
begin
  Key:=KeyOfRow(ARow);
  C:=FComp;
  if C=nil then Exit;
  if (Key='color') or (Key='fontcolor') or (Key='linecolor') or (Key='fillcolor') then
  begin
    CD:=TColorDialog.Create(nil);
    try
      if Key='color' then Col:=C.Color
      else if Key='fontcolor' then Col:=C.FontColor
      else if Key='linecolor' then Col:=C.LineColor
      else Col:=C.FillColor;
      CD.Color:=ColorToRGB(ColorFromVcl(Col));
      if not CD.Execute then Exit;
      if Assigned(OnBeforeChange) then OnBeforeChange(Self);
      Col:=ColorToRGB(CD.Color);
      if Key='color' then C.Color:=Col
      else if Key='fontcolor' then C.FontColor:=Col
      else if Key='linecolor' then C.LineColor:=Col
      else C.FillColor:=Col;
      ChangedLater(C,False);
    finally
      CD.Free;
    end;
  end
  else if Key='fontstyle' then
  begin
    FD:=TFontDialog.Create(nil);
    try
      FD.Font.Name:=C.FontName;
      FD.Font.Size:=C.FontSize;
      FD.Font.Color:=ColorFromVcl(C.FontColor);
      FD.Font.Style:=[];
      if C.FontStyle and 1<>0 then FD.Font.Style:=FD.Font.Style+[fsBold];
      if C.FontStyle and 2<>0 then FD.Font.Style:=FD.Font.Style+[fsItalic];
      if C.FontStyle and 4<>0 then FD.Font.Style:=FD.Font.Style+[fsUnderline];
      if C.FontStyle and 8<>0 then FD.Font.Style:=FD.Font.Style+[fsStrikeOut];
      if not FD.Execute then Exit;
      if Assigned(OnBeforeChange) then OnBeforeChange(Self);
      C.FontName:=FD.Font.Name;
      C.FontSize:=FD.Font.Size;
      C.FontColor:=ColorToVcl(FD.Font.Color);
      C.FontStyle:=0;
      if fsBold in FD.Font.Style then C.FontStyle:=C.FontStyle or 1;
      if fsItalic in FD.Font.Style then C.FontStyle:=C.FontStyle or 2;
      if fsUnderline in FD.Font.Style then C.FontStyle:=C.FontStyle or 4;
      if fsStrikeOut in FD.Font.Style then C.FontStyle:=C.FontStyle or 8;
      ChangedLater(C,False);
    finally
      FD.Free;
    end;
  end
  else if Key='text' then
  begin
    L:=TStringList.Create;
    try
      L.Text:=C.Text;
      if not EditLines('Text of '+C.Name,'One line per line of text.',L) then Exit;
      if Assigned(OnBeforeChange) then OnBeforeChange(Self);
      C.Text:=TrimRight(L.Text);
      ChangedLater(C,False);
    finally
      L.Free;
    end;
  end
  else if Key='items' then
  begin
    L:=TStringList.Create;
    try
      L.Assign(C.Items);
      if not EditLines('Items of '+C.Name,'One item per line, in order.',L) then Exit;
      if Assigned(OnBeforeChange) then OnBeforeChange(Self);
      C.Items.Clear;
      for Cnt:=0 to L.Count-1 do
        if Trim(L[Cnt])<>'' then C.Items.Add(Trim(L[Cnt]));
      if C.Selected>C.Items.Count then C.Selected:=0;
      ChangedLater(C,False);
    finally
      L.Free;
    end;
  end
  else if Key='drawing' then
  begin
    L:=TStringList.Create;
    W:=TStringList.Create;
    try
      for Cnt:=0 to High(C.Ops) do
        L.Add(MdDrawWords[C.Ops[Cnt].Kind]+' '+DrawOpArgs(C.Ops[Cnt]));
      repeat
        if not EditLines('Drawing on '+C.Name,'One operation per line, in the order they are '+
          'drawn, as menu image writes them after the image''s name: line x1 y1 x2 y2 colour '+
          '[width], rectangle and ellipse x1 y1 x2 y2 colour fill [width] (corners, not a size), '+
          'pix and floodfill x y colour, file x y filename.',L) then Exit;
        Bad:='';
        SetLength(Ops,0);
        for Cnt:=0 to L.Count-1 do
        begin
          if Trim(L[Cnt])='' then Continue;
          SplitScriptLine(L[Cnt],W);
          if (W.Count=0) or not ParseDrawOp(W[0],W,1,Op,Known) then
          begin
            Bad:='Line '+IntToStr(Cnt+1)+', "'+Trim(L[Cnt])+'", is not an operation 1.6 draws.';
            Break;
          end;
          SetLength(Ops,Length(Ops)+1);
          Ops[High(Ops)]:=Op;
        end;
        if Bad<>'' then MessageDlg(Bad,mtWarning,[mbOK],0);
      until Bad='';
      if Assigned(OnBeforeChange) then OnBeforeChange(Self);
      C.Ops:=Ops;
      ChangedLater(C,False);
    finally
      W.Free;
      L.Free;
    end;
  end;
end;

procedure TMdInspector.DoPrepare(Sender : TObject; ACol, ARow : Integer; AState : TGridDrawState);
var
  Key : String;
  Cnt : Integer;
  W   : String;
begin
  if (ARow<1) or (FComp=nil) then Exit;
  Key:=KeyOfRow(ARow);
  for Cnt:=0 to Warnings.Count-1 do
  begin
    if Warnings.Objects[Cnt]<>FComp then Continue;
    W:=Warnings[Cnt];
    if (Pos(': text:',W)>0) and (Key='text') or (Pos(': title:',W)>0) and (Key='text') or
       (Pos(': tooltip:',W)>0) and (Key='tooltip') or (Pos(': item ',W)>0) and (Key='items') or
       (Pos(': font:',W)>0) and (Key='fontname') or (Pos(': drawing ',W)>0) and (Key='drawing') or
       (Pos(': width:',W)>0) and (Key='width') or (Pos(': height:',W)>0) and (Key='height') or
       (Pos(': shape:',W)>0) and (Key='shapestyle') then
      Canvas.Brush.Color:=$C0C0FF;
  end;
end;

end.
