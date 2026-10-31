unit mdmodel;

{
  Port addition: the MENU Designer's document (docs/menu-designer.md, section 3.3). A document
  is an ordered list of forms, form0 first; a form or a panel holds components in z-order. Every
  value is held as the 1.6 logic reads it back with getprop, so a model can be compared with
  the windows a script builds: positions and sizes as on screen, colours as Delphi 7 numbers,
  font styles as 1.6's bits, names lower-case.

  For check and radio boxes 'Alignment' is the side of the text (0 right of the box, 1 left);
  the generator and the importer map it to and from 1.6's inverted values.

  No GUI: the tests use it directly.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, mdtypes;

type
  TMdDrawKind = (dkLine, dkEllipse, dkRectangle, dkPix, dkFloodFill, dkFile);

const
  MdDrawWords : array[TMdDrawKind] of String = ('line','ellipse','rectangle','pix','floodfill','file');

type
  TMdDrawOp = record
    Kind     : TMdDrawKind;
    X1, Y1   : Integer;
    X2, Y2   : Integer;    // line, ellipse, rectangle (corners, not a size)
    Color    : Integer;    // Delphi 7 number
    Fill     : Boolean;    // ellipse, rectangle
    PenWidth : Integer;    // line, ellipse, rectangle
    FileName : String;     // file
  end;

  TMdComponent = class
  public
    TypeId       : TMdType;
    Name         : String;
    Parent       : TMdComponent;   // nil for a form
    Children     : TList;          // TMdComponent, in z-order (forms and panels)
    Left, Top    : Integer;
    Width        : Integer;        // a form: its client area
    Height       : Integer;
    FixedW       : Boolean;        // an szAuto size written with setprop
    FixedH       : Boolean;
    Text         : String;         // caption, title or edit text; line breaks as #13#10
    Tooltip      : String;
    Enabled      : Boolean;
    Visible      : Boolean;
    Checked      : Boolean;
    Color        : Integer;
    FontName     : String;
    FontSize     : Integer;
    FontStyle    : Integer;        // 1 bold, 2 italic, 4 underline, 8 strike-out
    FontColor    : Integer;
    Alignment    : Integer;
    Items        : TStringList;    // combo, list
    Selected     : Integer;        // 1-based as "select" writes it; 0 none
    ShapeStyle   : Integer;        // 0..6 as "menu shape" takes it
    LineOn       : Boolean;
    LineWidth    : Integer;
    LineColor    : Integer;
    FillOn       : Boolean;
    FillColor    : Integer;
    BitmapW      : Integer;        // an image's bitmap; shown at Width x Height when Stretch
    BitmapH      : Integer;
    Stretch      : Boolean;
    Ops          : array of TMdDrawOp;
    Transparency : Integer;        // form0: -1 none, else 0..100 as "window transparent" takes it
    constructor Create(AType : TMdType);
    destructor  Destroy; override;
    function    Row : TMdTypeRow;
    function    IsForm : Boolean;
    function    IsForm0 : Boolean;
    function    IsContainer : Boolean;
    function    FormOf : TMdComponent;
    function    ChildCount : Integer;
    function    Child(Index : Integer) : TMdComponent;
    procedure   AddOp(const Op : TMdDrawOp);
    procedure   AssignValues(Src : TMdComponent);
  end;

  // A change to the model, made in F (nil: anywhere, or between forms).
  TMdChangeEvent = procedure(F : TMdComponent) of object;

  TMdDocument = class
  private
    FForms      : TList;
    procedure   Collect(C : TMdComponent; List : TList);
    function    CloneComponent(Src, NewParent : TMdComponent) : TMdComponent;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Clear;
    function    FormCount : Integer;
    function    Form(Index : Integer) : TMdComponent;
    function    Form0 : TMdComponent;
    procedure   AllComponents(List : TList);
    function    FindName(const Name : String) : TMdComponent;
    function    NameProblem(const Name : String; Owner : TMdComponent) : String;
    function    UniqueName(const Prefix : String) : String;
    function    AddForm(const Name : String) : TMdComponent;
    procedure   AddExistingForm(F : TMdComponent);
    function    Add(AType : TMdType; AParent : TMdComponent; X, Y : Integer;
                  const AName : String = '') : TMdComponent;
    procedure   Remove(C : TMdComponent);
    procedure   MoveForm(C : TMdComponent; Index : Integer);
    function    CanMoveTo(C, NewParent : TMdComponent) : Boolean;
    procedure   MoveTo(C, NewParent : TMdComponent; Index : Integer = -1);
    procedure   SetChecked(C : TMdComponent; Value : Boolean);
    function    Clone : TMdDocument;
    function    Dump : String;
  end;

function DumpComponent(C : TMdComponent) : String;

implementation

uses
  EuoScriptWords;

////////////////////////////////////////////////////////////////////////////////
constructor TMdComponent.Create(AType : TMdType);
begin
  inherited Create;
  TypeId:=AType;
  Children:=TList.Create;
  Items:=TStringList.Create;
  Width:=MdTypeRows[AType].DefW;
  Height:=MdTypeRows[AType].DefH;
  Enabled:=True;
  Visible:=True;
  Color:=MdDefColor;
  FontName:=MdDefFontName;
  FontSize:=MdDefFontSize;
  FontColor:=MdDefFontColor;
  LineOn:=True;
  LineWidth:=1;
  BitmapW:=Width;
  BitmapH:=Height;
  Transparency:=-1;
end;

destructor TMdComponent.Destroy;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Children.Count-1 do
    TMdComponent(Children[Cnt]).Free;
  Children.Free;
  Items.Free;
  inherited Destroy;
end;

function TMdComponent.Row : TMdTypeRow;
begin
  Result:=MdTypeRows[TypeId];
end;

function TMdComponent.IsForm : Boolean;
begin
  Result:=TypeId=mdtForm;
end;

function TMdComponent.IsForm0 : Boolean;
begin
  Result:=IsForm and (Name=MdForm0Name);
end;

function TMdComponent.IsContainer : Boolean;
begin
  Result:=MdTypeRows[TypeId].Container;
end;

function TMdComponent.FormOf : TMdComponent;
begin
  Result:=Self;
  while Result.Parent<>nil do
    Result:=Result.Parent;
end;

function TMdComponent.ChildCount : Integer;
begin
  Result:=Children.Count;
end;

function TMdComponent.Child(Index : Integer) : TMdComponent;
begin
  Result:=TMdComponent(Children[Index]);
end;

procedure TMdComponent.AddOp(const Op : TMdDrawOp);
begin
  SetLength(Ops,Length(Ops)+1);
  Ops[High(Ops)]:=Op;
end;

// Everything but the name, the parent and the children.
procedure TMdComponent.AssignValues(Src : TMdComponent);
begin
  TypeId:=Src.TypeId;
  Left:=Src.Left;
  Top:=Src.Top;
  Width:=Src.Width;
  Height:=Src.Height;
  FixedW:=Src.FixedW;
  FixedH:=Src.FixedH;
  Text:=Src.Text;
  Tooltip:=Src.Tooltip;
  Enabled:=Src.Enabled;
  Visible:=Src.Visible;
  Checked:=Src.Checked;
  Color:=Src.Color;
  FontName:=Src.FontName;
  FontSize:=Src.FontSize;
  FontStyle:=Src.FontStyle;
  FontColor:=Src.FontColor;
  Alignment:=Src.Alignment;
  Items.Assign(Src.Items);
  Selected:=Src.Selected;
  ShapeStyle:=Src.ShapeStyle;
  LineOn:=Src.LineOn;
  LineWidth:=Src.LineWidth;
  LineColor:=Src.LineColor;
  FillOn:=Src.FillOn;
  FillColor:=Src.FillColor;
  BitmapW:=Src.BitmapW;
  BitmapH:=Src.BitmapH;
  Stretch:=Src.Stretch;
  Ops:=Copy(Src.Ops);
  Transparency:=Src.Transparency;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TMdDocument.Create;
begin
  inherited Create;
  FForms:=TList.Create;
  Clear;
end;

destructor TMdDocument.Destroy;
var
  Cnt : Integer;
begin
  for Cnt:=0 to FForms.Count-1 do
    TMdComponent(FForms[Cnt]).Free;
  FForms.Free;
  inherited Destroy;
end;

// Back to a new document: form0 alone, as 1.6 creates it at the script's start (100,100,
// 295 x 170 asked, which the frame makes 305 x 180 on Windows 10/11).
procedure TMdDocument.Clear;
var
  Cnt : Integer;
  F0  : TMdComponent;
begin
  for Cnt:=0 to FForms.Count-1 do
    TMdComponent(FForms[Cnt]).Free;
  FForms.Clear;
  F0:=TMdComponent.Create(mdtForm);
  F0.Name:=MdForm0Name;
  F0.Left:=100;
  F0.Top:=100;
  F0.Width:=305;
  F0.Height:=180;
  F0.Text:=MdForm0Title;
  FForms.Add(F0);
end;

function TMdDocument.FormCount : Integer;
begin
  Result:=FForms.Count;
end;

function TMdDocument.Form(Index : Integer) : TMdComponent;
begin
  Result:=TMdComponent(FForms[Index]);
end;

function TMdDocument.Form0 : TMdComponent;
begin
  Result:=Form(0);
end;

procedure TMdDocument.Collect(C : TMdComponent; List : TList);
var
  Cnt : Integer;
begin
  List.Add(C);
  for Cnt:=0 to C.ChildCount-1 do
    Collect(C.Child(Cnt),List);
end;

// Every form and component, depth-first in z-order.
procedure TMdDocument.AllComponents(List : TList);
var
  Cnt : Integer;
begin
  for Cnt:=0 to FormCount-1 do
    Collect(Form(Cnt),List);
end;

function TMdDocument.FindName(const Name : String) : TMdComponent;
var
  List : TList;
  Cnt  : Integer;
begin
  Result:=nil;
  List:=TList.Create;
  try
    AllComponents(List);
    for Cnt:=0 to List.Count-1 do
      if SameText(TMdComponent(List[Cnt]).Name,Name) then
        Exit(TMdComponent(List[Cnt]));
  finally
    List.Free;
  end;
end;

// Why Name cannot be a name for Owner ('' when it can). Names are one word and unique across
// every form, because 1.6 has one registry for all of them and leaves a duplicate unreachable.
function TMdDocument.NameProblem(const Name : String; Owner : TMdComponent) : String;
var
  Cnt   : Integer;
  Other : TMdComponent;
begin
  Result:='';
  if Name='' then Exit('A name is needed.');
  for Cnt:=1 to Length(Name) do
    if Name[Cnt] in [#0..#32] then Exit('A name is one word, without spaces.');
  if Name[1]=';' then Exit('A name cannot start with ";": the rest of the line would be a comment.');
  if (Name='.') or (Name=',') then Exit('"'+Name+'" alone glues the words around it together.');
  if IsVar(Name) then Exit('"'+Name+'" reads as a variable.');
  if SameText(Name,MdForm0Name) and not ((Owner<>nil) and Owner.IsForm0) then
    Exit('form0 is the main window''s name.');
  Other:=FindName(Name);
  if (Other<>nil) and (Other<>Owner) then
    Exit('"'+LowerCase(Name)+'" is already the name of a '+Other.Row.Name+'.');
end;

function TMdDocument.UniqueName(const Prefix : String) : String;
var
  Nr : Integer;
begin
  Nr:=1;
  repeat
    Result:=LowerCase(Prefix)+IntToStr(Nr);
    Inc(Nr);
  until FindName(Result)=nil;
end;

function TMdDocument.AddForm(const Name : String) : TMdComponent;
begin
  Result:=TMdComponent.Create(mdtForm);
  if Name<>'' then Result.Name:=LowerCase(Name)
  else Result.Name:=UniqueName('form');
  Result.Left:=400;
  Result.Top:=200;
  Result.Text:=Result.Name;
  Result.Visible:=False;   // 1.6 creates every form hidden
  FForms.Add(Result);
end;

// A form built elsewhere (the importer), after the others.
procedure TMdDocument.AddExistingForm(F : TMdComponent);
begin
  F.Parent:=nil;
  FForms.Add(F);
end;

// A new component of AType in AParent (a form or a panel) at X, Y, on top of its siblings.
function TMdDocument.Add(AType : TMdType; AParent : TMdComponent; X, Y : Integer;
  const AName : String) : TMdComponent;
begin
  if AType=mdtForm then Exit(AddForm(AName));
  Result:=TMdComponent.Create(AType);
  if AName<>'' then Result.Name:=LowerCase(AName)
  else Result.Name:=UniqueName(MdTypeRows[AType].Name);
  Result.Left:=X;
  Result.Top:=Y;
  if MdTypeRows[AType].HasText and (AType<>mdtEdit) and (AType<>mdtMemo) then
    Result.Text:=Result.Name;
  if AType=mdtShape then
  begin
    Result.LineColor:=0;
    Result.FillColor:=$FFFFFF;
  end;
  Result.Parent:=AParent;
  AParent.Children.Add(Result);
end;

// Frees C with everything in it. Form0 cannot go.
procedure TMdDocument.Remove(C : TMdComponent);
begin
  if C.IsForm0 then Exit;
  if C.Parent=nil then FForms.Remove(C)
  else C.Parent.Children.Remove(C);
  C.Free;
end;

// Forms after form0 can change places; form0 stays first.
procedure TMdDocument.MoveForm(C : TMdComponent; Index : Integer);
begin
  if C.IsForm0 or (FForms.IndexOf(C)<0) then Exit;
  if Index<1 then Index:=1;
  if Index>FormCount-1 then Index:=FormCount-1;
  FForms.Move(FForms.IndexOf(C),Index);
end;

// A component can go into a form or a panel, but not into itself or one of its own children.
function TMdDocument.CanMoveTo(C, NewParent : TMdComponent) : Boolean;
var
  Up : TMdComponent;
begin
  Result:=False;
  if C.IsForm or (NewParent=nil) or not NewParent.IsContainer then Exit;
  Up:=NewParent;
  while Up<>nil do
  begin
    if Up=C then Exit;
    Up:=Up.Parent;
  end;
  Result:=True;
end;

// Into NewParent at Index in its z-order (-1: on top). A checked radio button keeps its check
// and the others in its new parent lose theirs.
procedure TMdDocument.MoveTo(C, NewParent : TMdComponent; Index : Integer);
begin
  if not CanMoveTo(C,NewParent) then Exit;
  C.Parent.Children.Remove(C);
  if (Index<0) or (Index>NewParent.ChildCount) then Index:=NewParent.ChildCount;
  NewParent.Children.Insert(Index,C);
  C.Parent:=NewParent;
  if (C.TypeId=mdtRadio) and C.Checked then SetChecked(C,True);
end;

// 1.6 groups radio buttons by parent: checking one unchecks the others in the same parent.
procedure TMdDocument.SetChecked(C : TMdComponent; Value : Boolean);
var
  Cnt     : Integer;
  Sibling : TMdComponent;
begin
  C.Checked:=Value;
  if (C.TypeId<>mdtRadio) or not Value or (C.Parent=nil) then Exit;
  for Cnt:=0 to C.Parent.ChildCount-1 do
  begin
    Sibling:=C.Parent.Child(Cnt);
    if (Sibling<>C) and (Sibling.TypeId=mdtRadio) then Sibling.Checked:=False;
  end;
end;

function TMdDocument.CloneComponent(Src, NewParent : TMdComponent) : TMdComponent;
var
  Cnt : Integer;
begin
  Result:=TMdComponent.Create(Src.TypeId);
  Result.Name:=Src.Name;
  Result.AssignValues(Src);
  Result.Parent:=NewParent;
  for Cnt:=0 to Src.ChildCount-1 do
    Result.Children.Add(CloneComponent(Src.Child(Cnt),Result));
end;

function TMdDocument.Clone : TMdDocument;
var
  Cnt : Integer;
begin
  Result:=TMdDocument.Create;
  for Cnt:=0 to Result.FormCount-1 do
    Result.Form(Cnt).Free;
  Result.FForms.Clear;
  for Cnt:=0 to FormCount-1 do
    Result.FForms.Add(CloneComponent(Form(Cnt),nil));
end;

////////////////////////////////////////////////////////////////////////////////
function BoolStr(B : Boolean) : String;
begin
  if B then Result:='1' else Result:='0';
end;

function Quoted(const S : String) : String;
begin
  Result:='"'+StringReplace(StringReplace(S,#13#10,'\n',[rfReplaceAll]),'"','\"',[rfReplaceAll])+'"';
end;

// One line with every value that applies to the component's type: what the tests compare.
function DumpComponent(C : TMdComponent) : String;
var
  R   : TMdTypeRow;
  Cnt : Integer;
  Op  : TMdDrawOp;
  P   : String;
begin
  R:=C.Row;
  if C.Parent<>nil then P:=C.Parent.Name else P:='-';
  Result:=Format('%s %s in %s at %d,%d size %d,%d',[R.Name,C.Name,P,C.Left,C.Top,C.Width,C.Height]);
  if R.W=szAuto then Result:=Result+' fixedw='+BoolStr(C.FixedW);
  if R.H=szAuto then Result:=Result+' fixedh='+BoolStr(C.FixedH);
  if MdTypeHasProp(C.TypeId,'text') then Result:=Result+' text='+Quoted(C.Text);
  Result:=Result+' tooltip='+Quoted(C.Tooltip)+' enabled='+BoolStr(C.Enabled)+
    ' visible='+BoolStr(C.Visible);
  if MdTypeHasProp(C.TypeId,'checked') then Result:=Result+' checked='+BoolStr(C.Checked);
  if MdTypeHasProp(C.TypeId,'color') then Result:=Result+' color='+IntToStr(C.Color);
  if MdTypeHasProp(C.TypeId,'fontname') then
    Result:=Result+Format(' font=%s,%d,%d,%d',[Quoted(C.FontName),C.FontSize,C.FontStyle,C.FontColor]);
  if R.Align<>maNone then Result:=Result+' align='+IntToStr(C.Alignment);
  if R.Items then
  begin
    Result:=Result+' items=';
    for Cnt:=0 to C.Items.Count-1 do
      Result:=Result+Quoted(C.Items[Cnt])+';';
    Result:=Result+' selected='+IntToStr(C.Selected);
  end;
  if C.TypeId=mdtShape then
    Result:=Result+Format(' shape=%d line=%s,%d,%d fill=%s,%d',[C.ShapeStyle,BoolStr(C.LineOn),
      C.LineWidth,C.LineColor,BoolStr(C.FillOn),C.FillColor]);
  if R.Drawing then
  begin
    Result:=Result+Format(' bitmap=%d,%d stretch=%s ops=',[C.BitmapW,C.BitmapH,BoolStr(C.Stretch)]);
    for Cnt:=0 to High(C.Ops) do
    begin
      Op:=C.Ops[Cnt];
      Result:=Result+Format('%d:%d,%d,%d,%d,%d,%s,%d,%s;',[Ord(Op.Kind),Op.X1,Op.Y1,Op.X2,Op.Y2,
        Op.Color,BoolStr(Op.Fill),Op.PenWidth,Quoted(Op.FileName)]);
    end;
  end;
  if C.IsForm0 then Result:=Result+' transparency='+IntToStr(C.Transparency);
end;

// Every component in file order, one line each: two documents with the same dump build the
// same windows.
function TMdDocument.Dump : String;
var
  List : TList;
  Cnt  : Integer;
begin
  Result:='';
  List:=TList.Create;
  try
    AllComponents(List);
    for Cnt:=0 to List.Count-1 do
      Result:=Result+DumpComponent(TMdComponent(List[Cnt]))+LineEnding;
  finally
    List.Free;
  end;
end;

end.
