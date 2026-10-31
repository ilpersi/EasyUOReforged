unit mdimport;

{
  Port addition: the MENU Designer's importer, script to model (docs/menu-designer.md,
  section 6).

  Only MENU lines are read, in file order, whatever control flow is around them; every other
  command is ignored. Each line is read as the interpreter reads it (mdscript). Lines that
  cannot be modelled are left out and listed in the report with their line number: a variable
  other than the five constants, what a running script reads (get, getprop, activate, ...),
  what 1.6 removed, an unknown sub-command.

  The rest runs through a private, hidden TMenu16, so 1.6's state machine -- default parent,
  pushdef/popdef in their FIFO order, clear, delete, duplicate names -- is replayed by 1.6's
  own port, not by a second copy of its rules. Only what would put a window on screen is kept
  aside: "menu show", "menu hide" and "setprop <form> visible" set the form's Visible in the
  model instead of running. At the end every registered control is read back, with getprop and
  menu get through TMenu16.Run, and becomes the model. Alongside the replay the importer notes
  what the windows cannot tell afterwards: a shape's parameters and an image's drawing
  operations (pixels by then), form0's transparency, and whether a text's or an edit's size was
  set after 1.6 last fitted it.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, Controls, Forms, ExtCtrls, StdCtrls, EuoMenu16, EuoMenuCommon,
  EuoMenuSelect, EuoConversion, mdtypes, mdmodel, mdscript;

type
  TMdReportKind = (rkLogic15, rkVariable, rkRuntime, rkRemoved, rkUnknown, rkNoEffect,
                   rkDuplicate, rkForm0Deleted, rkNoParent, rkBadParent, rkBadName);
  TMdReportKinds = set of TMdReportKind;

  TMdReportEntry = class
  public
    LineNo  : Integer;   // 0: about the whole text
    Kind    : TMdReportKind;
    Message : String;
  end;

  // What the windows cannot tell about a control once the lines have run.
  TMdTrack = class
  public
    Ctrl     : TControl;
    LineNo   : Integer;
    IsShape  : Boolean;
    Style    : Integer;
    LineOn   : Boolean;
    LineW    : Integer;
    LineCol  : Integer;
    FillOn   : Boolean;
    FillCol  : Integer;
    Ops      : array of TMdDrawOp;
    FixedW   : Boolean;
    FixedH   : Boolean;
    Shown    : Boolean;   // a form: show/hide/setprop visible
  end;

  TMdImporter = class
  private
    Menu        : TMenu16;
    Tracks      : TList;
    Transparent : Integer;
    procedure   Note(LineNo : Integer; Kind : TMdReportKind; const Msg : String);
    function    Registered(const Name : String) : TControl;
    function    RegisteredKind(C : TControl) : Integer;
    function    RegisteredName(C : TControl) : String;
    function    Track(C : TControl) : TMdTrack;
    function    NewTrack(C : TControl; LineNo : Integer) : TMdTrack;
    function    GetProp(const Name, Prop : String) : String;
    procedure   ReadLine(R : TMdLineReader);
    procedure   ReadCreate(R : TMdLineReader; const Name : String);
    procedure   ReadImageOp(R : TMdLineReader);
    procedure   ReadBack(Doc : TMdDocument);
    function    ReadComponent(Doc : TMdDocument; Index : Integer) : TMdComponent;
  public
    Report      : TList;   // TMdReportEntry, in line order
    constructor Create;
    destructor  Destroy; override;
    procedure   Import(Lines : TStrings; Doc : TMdDocument);
    function    ReportText : String;
  end;

function ImportText(Lines : TStrings; Doc : TMdDocument) : String;
function ParseDrawOp(const KindWord : String; Words : TStrings; First : Integer;
  out Op : TMdDrawOp; out Known : Boolean) : Boolean;

implementation

uses
  Graphics, mdgenerate;

////////////////////////////////////////////////////////////////////////////////
// The model of a text, report in hand: what most callers want.
function ImportText(Lines : TStrings; Doc : TMdDocument) : String;
var
  Imp : TMdImporter;
begin
  Imp:=TMdImporter.Create;
  try
    Imp.Import(Lines,Doc);
    Result:=Imp.ReportText;
  finally
    Imp.Free;
  end;
end;

constructor TMdImporter.Create;
begin
  inherited Create;
  Report:=TList.Create;
  Tracks:=TList.Create;
end;

destructor TMdImporter.Destroy;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Report.Count-1 do
    TObject(Report[Cnt]).Free;
  Report.Free;
  for Cnt:=0 to Tracks.Count-1 do
    TObject(Tracks[Cnt]).Free;
  Tracks.Free;
  Menu.Free;
  inherited Destroy;
end;

procedure TMdImporter.Note(LineNo : Integer; Kind : TMdReportKind; const Msg : String);
var
  E : TMdReportEntry;
begin
  E:=TMdReportEntry.Create;
  E.LineNo:=LineNo;
  E.Kind:=Kind;
  E.Message:=Msg;
  Report.Add(E);
end;

function TMdImporter.ReportText : String;
var
  Cnt : Integer;
  E   : TMdReportEntry;
begin
  Result:='';
  for Cnt:=0 to Report.Count-1 do
  begin
    E:=TMdReportEntry(Report[Cnt]);
    if E.LineNo>0 then Result:=Result+'Line '+IntToStr(E.LineNo)+': ';
    Result:=Result+E.Message+LineEnding;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The registry, read through TMenu16's read-only views.
function TMdImporter.Registered(const Name : String) : TControl;
var
  Cnt   : Integer;
  Lower : String;
begin
  Lower:=LowerCase(Name);
  for Cnt:=0 to Menu.RegistryCount-1 do
    if Menu.RegistryName(Cnt)=Lower then Exit(Menu.RegistryCtrl(Cnt));
  Result:=nil;
end;

function TMdImporter.RegisteredKind(C : TControl) : Integer;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Menu.RegistryCount-1 do
    if Menu.RegistryCtrl(Cnt)=C then Exit(Menu.RegistryKind(Cnt));
  Result:=0;
end;

function TMdImporter.RegisteredName(C : TControl) : String;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Menu.RegistryCount-1 do
    if Menu.RegistryCtrl(Cnt)=C then Exit(Menu.RegistryName(Cnt));
  Result:='';
end;

function TMdImporter.Track(C : TControl) : TMdTrack;
var
  Cnt : Integer;
begin
  for Cnt:=0 to Tracks.Count-1 do
    if TMdTrack(Tracks[Cnt]).Ctrl=C then Exit(TMdTrack(Tracks[Cnt]));
  Result:=nil;
end;

// A control just created starts with nothing noted. A freed control's memory can come back
// as a new one, so an old note for the same address goes.
function TMdImporter.NewTrack(C : TControl; LineNo : Integer) : TMdTrack;
var
  Old : TMdTrack;
begin
  Old:=Track(C);
  if Old<>nil then
  begin
    Tracks.Remove(Old);
    Old.Free;
  end;
  Result:=TMdTrack.Create;
  Result.Ctrl:=C;
  Result.LineNo:=LineNo;
  Tracks.Add(Result);
end;

function TMdImporter.GetProp(const Name, Prop : String) : String;
begin
  RunMenuLine(Menu,'menu getprop '+Name+' '+Prop);
  Result:=Menu.MenuRes;
end;

////////////////////////////////////////////////////////////////////////////////
// A creating line: run it, and see what it did to the registry.
procedure TMdImporter.ReadCreate(R : TMdLineReader; const Name : String);
var
  Before : TControl;
  After  : TControl;
  T      : TMdTrack;
  OK     : Boolean;
begin
  Before:=Registered(Name);
  RunWords(Menu,R.Words);
  After:=Registered(Name);
  if (Before<>nil) and (After=Before) then
  begin
    Note(R.LineNo,rkDuplicate,'"'+LowerCase(Name)+'" is already a name. EasyUO 1.6 shows this '+
      'control but nothing can reach it, so it is not loaded.');
    Exit;
  end;
  if After=nil then
  begin
    Note(R.LineNo,rkNoEffect,'EasyUO 1.6 does nothing with this line (a value it needs is '+
      'missing or out of range).');
    Exit;
  end;

  T:=NewTrack(After,R.LineNo);
  if R.Sub='SHAPE' then
  begin
    T.IsShape:=True;
    T.Style:=StrToIntDef(R.Word(7),0);
    T.LineOn:=StrToIntDef(R.Word(8),0)<>1;
    T.LineW:=StrToIntDef(R.Word(9),0);
    T.LineCol:=ColorToVcl(SToCol(R.Word(10),OK));
    T.FillOn:=StrToIntDef(R.Word(11),0)=7;
    T.FillCol:=ColorToVcl(SToCol(R.Word(12),OK));
  end;
end;

// A drawing operation as "menu image <kind> <name> <values>" carries it, the values from
// Words[First]: what 1.6 would draw, with its checks (RunImage). False when 1.6 draws nothing;
// Known is False for a kind 1.6 does not have.
function ParseDrawOp(const KindWord : String; Words : TStrings; First : Integer;
  out Op : TMdDrawOp; out Known : Boolean) : Boolean;
var
  K     : TMdDrawKind;
  Need  : Integer;
  ColOK : Boolean;

  function Arg(I : Integer) : String;
  begin
    if First+I<Words.Count then Result:=Words[First+I] else Result:='';
  end;

begin
  Op:=Default(TMdDrawOp);
  Known:=False;
  for K:=Low(TMdDrawKind) to High(TMdDrawKind) do
    if SameText(MdDrawWords[K],KindWord) then
    begin
      Op.Kind:=K;
      Known:=True;
    end;
  if not Known then Exit(False);
  case Op.Kind of
    dkLine:                Need:=5;
    dkEllipse,dkRectangle: Need:=6;
  else                     Need:=3;
  end;
  Result:=(Words.Count-First>=Need) and IsNumber(Arg(0)) and IsNumber(Arg(1));
  Op.X1:=StrToIntDef(Arg(0),0);
  Op.Y1:=StrToIntDef(Arg(1),0);
  case Op.Kind of
    dkLine, dkEllipse, dkRectangle:
      begin
        Op.X2:=StrToIntDef(Arg(2),-1);
        Op.Y2:=StrToIntDef(Arg(3),-1);
        // 1.6 draws nothing with a negative or missing corner
        Result:=Result and IsNumber(Arg(2)) and IsNumber(Arg(3)) and (Op.X2>=0) and (Op.Y2>=0);
        Op.Color:=ColorToVcl(SToCol(Arg(4),ColOK));
        Result:=Result and ColOK;
        Op.PenWidth:=1;
        if Op.Kind=dkLine then
        begin
          if (Words.Count-First>5) and IsNumber(Arg(5)) and (StrToIntDef(Arg(5),-1)>=0) then
            Op.PenWidth:=StrToIntDef(Arg(5),1);
        end
        else
        begin
          Op.Fill:=StrToIntDef(Arg(5),0)<>0;
          if (Words.Count-First>6) and IsNumber(Arg(6)) and (StrToIntDef(Arg(6),-1)>=0) then
            Op.PenWidth:=StrToIntDef(Arg(6),1);
        end;
      end;
    dkPix, dkFloodFill:
      begin
        Op.Color:=ColorToVcl(SToCol(Arg(2),ColOK));
        Result:=Result and ColOK;
      end;
    dkFile:
      Op.FileName:=Arg(2);
  end;
end;

// MENU IMAGE drawing, noted for the image the name reaches now.
procedure TMdImporter.ReadImageOp(R : TMdLineReader);
var
  C    : TControl;
  T    : TMdTrack;
  Op   : TMdDrawOp;
  Kind : String;
  OK   : Boolean;
  Known: Boolean;
begin
  Kind:=UpperCase(R.Word(2));
  C:=Registered(R.Word(3));
  RunWords(Menu,R.Words);
  if Kind='POS' then
  begin
    // with a size, "image pos" sizes any control, as setprop width/height would
    if ((C is TLabel) or (C is TEdit) or (C is TComboBox)) and (R.Words.Count>=8) and
       IsNumber(R.Word(6)) and IsNumber(R.Word(7)) and (StrToIntDef(R.Word(6),-1)>=0) and
       (StrToIntDef(R.Word(7),-1)>=0) then
    begin
      T:=Track(C);
      if T=nil then T:=NewTrack(C,R.LineNo);
      T.FixedW:=C is TLabel;
      T.FixedH:=True;
    end;
    Exit;
  end;

  OK:=ParseDrawOp(Kind,R.Words,4,Op,Known);
  if not Known then
  begin
    Note(R.LineNo,rkUnknown,'menu image '+LowerCase(Kind)+' is not a MENU sub-command of EasyUO 1.6.');
    Exit;
  end;
  if not (C is TImage) then
  begin
    Note(R.LineNo,rkNoEffect,'"'+LowerCase(R.Word(3))+'" is not an image: nothing is drawn.');
    Exit;
  end;
  if not OK then
  begin
    Note(R.LineNo,rkNoEffect,'EasyUO 1.6 draws nothing for this line (a value it needs is '+
      'missing or not a number or colour).');
    Exit;
  end;
  T:=Track(C);
  if T=nil then T:=NewTrack(C,R.LineNo);
  SetLength(T.Ops,Length(T.Ops)+1);
  T.Ops[High(T.Ops)]:=Op;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdImporter.ReadLine(R : TMdLineReader);
var
  Sub  : String;
  W2   : String;
  W3   : String;
  C    : TControl;
  T    : TMdTrack;
  F0   : TControl;
begin
  Sub:=R.Sub;
  W2:=UpperCase(R.Word(2));

  if R.Variable<>'' then
  begin
    Note(R.LineNo,rkVariable,'uses '+R.Variable+', which is only known when the script runs.');
    Exit;
  end;
  if Sub='REFORGE' then Exit;   // the designer writes its own
  if Sub='' then Exit;
  if InList(Sub,MdSubsRuntime) then
  begin
    Note(R.LineNo,rkRuntime,'menu '+LowerCase(Sub)+' is read by a running script; not a window design.');
    Exit;
  end;
  if InList(Sub,MdSubsRemoved) or InList(Sub+' '+W2,MdSubsRemoved) then
  begin
    Note(R.LineNo,rkRemoved,'EasyUO 1.6 removed menu '+LowerCase(Trim(Sub+' '+W2))+'.');
    Exit;
  end;
  if not (InList(Sub,MdSubsWritten) or InList(Sub,MdSubsRead)) then
  begin
    Note(R.LineNo,rkUnknown,'menu '+LowerCase(Sub)+' is not a MENU sub-command of EasyUO 1.6.');
    Exit;
  end;

  F0:=Registered(MdForm0Name);

  // What would put a window on screen is noted, not run.
  if Sub='SHOW' then
  begin
    if not (F0 is TEuoMenuForm) then Exit;
    if (R.Words.Count>=4) and IsNumber(R.Word(2)) and IsNumber(R.Word(3)) then
    begin
      F0.Left:=StrToIntDef(R.Word(2),F0.Left);
      F0.Top:=StrToIntDef(R.Word(3),F0.Top);
    end;
    T:=Track(F0);
    if T=nil then T:=NewTrack(F0,R.LineNo);
    T.Shown:=True;
    Exit;
  end;
  if Sub='HIDE' then
  begin
    if not (F0 is TEuoMenuForm) then Exit;
    T:=Track(F0);
    if T=nil then T:=NewTrack(F0,R.LineNo);
    T.Shown:=False;
    Exit;
  end;
  if (Sub='SETPROP') and SameText(R.Word(3),'visible') then
  begin
    C:=Registered(R.Word(2));
    if C is TCustomForm then
    begin
      T:=Track(C);
      if T=nil then T:=NewTrack(C,R.LineNo);
      T.Shown:=SToI64Def(R.Word(4),0)<>0;
      Exit;
    end;
  end;
  if (Sub='DELETE') and SameText(R.Word(2),MdForm0Name) then
  begin
    Note(R.LineNo,rkForm0Deleted,'menu delete form0 destroys the main window until the script '+
      'starts again; the designer always has form0, so this line is not read.');
    Exit;
  end;

  // Transparency is a layered window's alpha afterwards; the value asked for is kept here.
  if (Sub='WINDOW') and (W2='TRANSPARENT') and (R.Words.Count>3) and IsNumber(R.Word(3)) and
     (StrToIntDef(R.Word(3),-1)>=0) and (StrToIntDef(R.Word(3),-1)<101) and (F0 is TEuoMenuForm) then
    Transparent:=StrToIntDef(R.Word(3),-1);

  // Creating lines.
  if (Sub='FORM') or (Sub='PANEL') or (Sub='TEXT') or (Sub='BUTTON') or (Sub='EDIT') or
     (Sub='MEMO') or (Sub='CHECK') or (Sub='RADIO') or (Sub='SHAPE') then
  begin
    ReadCreate(R,R.Word(2));
    Exit;
  end;
  if ((Sub='LIST') or (Sub='COMBO') or (Sub='IMAGE')) and (W2='CREATE') then
  begin
    ReadCreate(R,R.Word(3));
    Exit;
  end;
  if (Sub='IMAGE') then
  begin
    ReadImageOp(R);
    Exit;
  end;

  // A text's or an edit's size: fixed by setprop until 1.6 fits it again.
  if Sub='SETPROP' then
  begin
    C:=Registered(R.Word(2));
    W3:=LowerCase(R.Word(3));
    if (C is TLabel) or (C is TEdit) or (C is TComboBox) then
    begin
      T:=Track(C);
      if T=nil then T:=NewTrack(C,R.LineNo);
      if (W3='width') and (C is TLabel) then T.FixedW:=True;
      if W3='height' then T.FixedH:=True;
      // 1.6 fits a label again after a text or font change, an edit after a font change
      if ((Copy(W3,1,4)='font') and not (C is TComboBox)) or ((W3='text') and (C is TLabel)) then
      begin
        T.FixedW:=False;
        T.FixedH:=False;
      end;
    end;
  end;
  if Sub='SET' then
  begin
    C:=Registered(R.Word(2));
    T:=Track(C);
    if (C is TLabel) and (T<>nil) then
    begin
      T.FixedW:=False;
      T.FixedH:=False;
    end;
  end;

  RunWords(Menu,R.Words);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdImporter.Import(Lines : TStrings; Doc : TMdDocument);
var
  R      : TMdLineReader;
  Forced : Boolean;
begin
  Doc.Clear;
  Transparent:=-1;
  if ChooseMenuLogic(Lines,nil,Forced)=mlMenu15 then
    Note(0,rkLogic15,'In EasyUO Reforged this script runs under the MENU 1.5 logic. The '+
      'designer reads it as 1.6, and a file it saves starts with "menu reforge mode 1.6".');

  Menu.Free;
  Menu:=TMenu16.Create;
  Menu.ScriptStart;
  R:=TMdLineReader.Create(Lines);
  try
    while R.Next do
      if R.IsMenu then ReadLine(R);
  finally
    R.Free;
  end;
  ReadBack(Doc);
end;

////////////////////////////////////////////////////////////////////////////////
// Controls on a form live on its Surface panel; to the script the form is their parent.
function ParentControl(C : TControl) : TControl;
var
  P : TWinControl;
begin
  P:=C.Parent;
  if (P<>nil) and (P.Owner is TEuoMenuForm) and (TEuoMenuForm(P.Owner).Surface=P) then
    Result:=TEuoMenuForm(P.Owner)
  else Result:=P;
end;

function TypeOfKind(Kind : Integer; IsShape : Boolean; out T : TMdType) : Boolean;
var
  Cnt : TMdType;
begin
  if (Kind=MT_IMAGE) and IsShape then
  begin
    T:=mdtShape;
    Exit(True);
  end;
  for Cnt:=Low(TMdType) to High(TMdType) do
    if (MdTypeRows[Cnt].Kind=Kind) and (Cnt<>mdtShape) then
    begin
      T:=Cnt;
      Exit(True);
    end;
  T:=mdtForm;
  Result:=False;
end;

// One registered control as a model component, not yet in a parent.
function TMdImporter.ReadComponent(Doc : TMdDocument; Index : Integer) : TMdComponent;
var
  Name : String;
  C    : TControl;
  T    : TMdTrack;
  Ty   : TMdType;
  Cnt  : Integer;
  Res  : String;

  function Prop(const P : String; Def : Integer) : Integer;
  begin
    Result:=StrToIntDef(GetProp(Name,P),Def);
  end;

begin
  Result:=nil;
  Name:=Menu.RegistryName(Index);
  C:=Menu.RegistryCtrl(Index);
  T:=Track(C);
  if not TypeOfKind(Menu.RegistryKind(Index),(T<>nil) and T.IsShape,Ty) then Exit;

  if Name=MdForm0Name then Result:=Doc.Form0
  else Result:=TMdComponent.Create(Ty);
  Result.Name:=Name;
  Result.Left:=Prop('left',0);
  Result.Top:=Prop('top',0);
  Result.Width:=Prop('width',0);
  Result.Height:=Prop('height',0);
  if MdTypeHasProp(Ty,'text') then
  begin
    Result.Text:=GetProp(Name,'text');
    if Ty=mdtMemo then Result.Text:=StringReplace(Result.Text,'$',#13#10,[rfReplaceAll]);
  end;
  Result.Tooltip:=GetProp(Name,'tooltip');
  Result.Enabled:=Prop('enabled',-1)<>0;
  if Ty=mdtForm then Result.Visible:=(T<>nil) and T.Shown
  else Result.Visible:=Prop('visible',-1)<>0;
  if MdTypeHasProp(Ty,'checked') then Result.Checked:=Prop('checked',0)<>0;
  if MdTypeHasProp(Ty,'color') then Result.Color:=Prop('color',MdDefColor);
  if MdTypeHasProp(Ty,'fontname') then
  begin
    Result.FontName:=GetProp(Name,'fontname');
    Result.FontSize:=Prop('fontsize',MdDefFontSize);
    Result.FontStyle:=Prop('fontstyle',0);
    Result.FontColor:=Prop('fontcolor',0);
  end;
  case MdTypeRows[Ty].Align of
    maText:  Result.Alignment:=Prop('alignment',0);
    maCheck:
      // 1.6 reads a check box's alignment inverted and a radio button's as stored
      if Ty=mdtRadio then
      begin
        if Prop('alignment',1)=0 then Result.Alignment:=1 else Result.Alignment:=0;
      end
      else if Prop('alignment',0)=1 then Result.Alignment:=1 else Result.Alignment:=0;
  end;
  if MdTypeRows[Ty].Items then
  begin
    if C is TComboBox then Result.Items.Assign(TComboBox(C).Items)
    else if C is TListBox then Result.Items.Assign(TListBox(C).Items);
    RunMenuLine(Menu,'menu get '+Name);
    Res:=Menu.MenuRes;
    Result.Selected:=StrToIntDef(Res,0);
  end;
  if C is TImage then
  begin
    Result.BitmapW:=TImage(C).Picture.Bitmap.Width;
    Result.BitmapH:=TImage(C).Picture.Bitmap.Height;
    Result.Stretch:=TImage(C).Stretch;
  end;
  if T<>nil then
  begin
    Result.FixedW:=T.FixedW;
    Result.FixedH:=T.FixedH;
    if T.IsShape then
    begin
      Result.ShapeStyle:=T.Style;
      Result.LineOn:=T.LineOn;
      Result.LineWidth:=T.LineW;
      Result.LineColor:=T.LineCol;
      Result.FillOn:=T.FillOn;
      Result.FillColor:=T.FillCol;
    end;
    for Cnt:=0 to High(T.Ops) do
      Result.AddOp(T.Ops[Cnt]);
  end;
  if Result.IsForm0 then Result.Transparency:=Transparent;
end;

// The registered controls as the model: forms in the order they were made, form0 first, and
// in each form or panel its children in z-order.
procedure TMdImporter.ReadBack(Doc : TMdDocument);
var
  Comps   : TList;     // TMdComponent per registry index (nil: not loaded)
  Done    : TList;     // placed in the model
  Cnt     : Integer;
  K       : Integer;
  C       : TControl;
  P       : TControl;
  Comp    : TMdComponent;
  Problem : String;

  function IndexOfCtrl(X : TControl) : Integer;
  begin
    for Result:=0 to Menu.RegistryCount-1 do
      if Menu.RegistryCtrl(Result)=X then Exit;
    Result:=-1;
  end;

  function LineOf(X : TControl) : Integer;
  var
    Tr : TMdTrack;
  begin
    Tr:=Track(X);
    if Tr<>nil then Result:=Tr.LineNo else Result:=0;
  end;

  // Place the children of a container, in z-order, then theirs.
  procedure Place(Owner : TMdComponent; Ctrl : TControl);
  var
    I   : Integer;
    Box : TWinControl;
    Kid : TControl;
    Idx : Integer;
  begin
    if Ctrl is TEuoMenuForm then Box:=TEuoMenuForm(Ctrl).Surface
    else Box:=TWinControl(Ctrl);
    for I:=0 to Box.ControlCount-1 do
    begin
      Kid:=Box.Controls[I];
      Idx:=IndexOfCtrl(Kid);
      if (Idx<0) or (Comps[Idx]=nil) or (Done.IndexOf(Comps[Idx])>=0) then Continue;
      TMdComponent(Comps[Idx]).Parent:=Owner;
      Owner.Children.Add(Comps[Idx]);
      Done.Add(Comps[Idx]);
      if TMdComponent(Comps[Idx]).IsContainer then Place(TMdComponent(Comps[Idx]),Kid);
    end;
  end;

begin
  Comps:=TList.Create;
  Done:=TList.Create;
  try
    for Cnt:=0 to Menu.RegistryCount-1 do
    begin
      C:=Menu.RegistryCtrl(Cnt);
      Comp:=ReadComponent(Doc,Cnt);
      if Comp=nil then
        Note(LineOf(C),rkUnknown,'"'+Menu.RegistryName(Cnt)+'" is a kind of control the '+
          'designer does not have.')
      else if not Comp.IsForm0 then
      begin
        Problem:=Doc.NameProblem(Comp.Name,nil);
        if Problem<>'' then
        begin
          Note(LineOf(C),rkBadName,Problem+' Not loaded.');
          Comp.Free;
          Comp:=nil;
        end;
      end;
      Comps.Add(Comp);
    end;

    // forms first, in the order they were made
    for Cnt:=0 to Menu.RegistryCount-1 do
    begin
      Comp:=TMdComponent(Comps[Cnt]);
      if (Comp=nil) or not Comp.IsForm then Continue;
      if not Comp.IsForm0 then Doc.AddExistingForm(Comp);
      Done.Add(Comp);
      Place(Comp,Menu.RegistryCtrl(Cnt));
    end;

    // whatever is left has no form above it, or a parent that is neither a form nor a panel
    for Cnt:=0 to Menu.RegistryCount-1 do
    begin
      Comp:=TMdComponent(Comps[Cnt]);
      if (Comp=nil) or (Done.IndexOf(Comp)>=0) then Continue;
      C:=Menu.RegistryCtrl(Cnt);
      P:=ParentControl(C);
      K:=IndexOfCtrl(P);
      if (P=nil) or (K<0) then
        Note(LineOf(C),rkNoParent,'"'+Comp.Name+'" is in no window (its container was deleted, '+
          'or is a duplicate nothing can reach). Not loaded.')
      else if (Menu.RegistryKind(K)=MT_FORM) or (Menu.RegistryKind(K)=MT_PANEL) then
        Note(LineOf(C),rkNoParent,'"'+Comp.Name+'" is inside "'+Menu.RegistryName(K)+'", '+
          'which is not loaded. Not loaded.')
      else
        Note(LineOf(C),rkBadParent,'"'+Comp.Name+'" is inside "'+Menu.RegistryName(K)+'", '+
          'which is not a form or a panel. Not loaded.');
      Comp.Free;
      Comps[Cnt]:=nil;
    end;
  finally
    Done.Free;
    Comps.Free;
  end;
end;

end.
