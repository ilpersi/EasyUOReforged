unit mdgenerate;

{
  Port addition: the MENU Designer's generator, model to script (docs/menu-designer.md,
  sections 4 and 5).

  The file: a header (a comment, "menu reforge mode 1.6", a gosub per form, a #MenuButton wait,
  halt), then one sub per form, form0 first, named menu_<form>. Each sub stands alone, because
  1.6's defaults are global: it deletes what it builds (so calling it again rebuilds the form),
  creates the form, resets every default, creates the components depth-first in z-order with
  a setdef before each one for whatever default differs, and shows the form if it is visible.
  No "menu clear" (it frees every other form), no pushdef/popdef (1.6's FIFO order).

  How values are written:
  - Colours by name where EasyUO 1.6 (Delphi 7) and Reforged (LCL) both know one: the Windows
    system colours and the standard ones (ColorWord); any other colour as a number. The
    commands that read a colour by name or number (font color, font bgcolor, window color,
    shape, image drawing: SToCol) get the name. So the defaults' colours are set with
    "menu font color" / "menu font bgcolor", not setdef, which takes numbers only (a colour
    name there silently becomes black). setprop gets Delphi 7 numbers, as it must; a system
    colour with no shared name goes to the defaults with setdef's number too, since SToCol
    would not read a Delphi system colour's number as one.
  - A form's size is asked for on "menu form" and then set exactly with setprop: the frame
    makes 1.6's form larger than asked by an amount that depends on the Windows build.
  - A right-aligned text is placed with setprop left: 1.6 creates it at width 0 and keeps its
    right edge while fitting it, so x on the creating line would be the text's right edge.
  - "menu text" turns '$' into a line break, setprop text does not: a text with a '$' and no
    line break is created empty and given its text with setprop.
  - Every caption, tooltip, title, item, font and file name is checked against the way a line
    is tokenised (TextOnLine). One that cannot be written as it is gets a warning, and is
    written without what tokenising would change (SafeText), so the line still works and the
    script shows what the canvas shows; a file name that is not one plain word leaves the
    picture out.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, mdtypes, mdmodel;

type
  TMdGenerator = class
  private
    FDoc        : TMdDocument;
    FOut        : TStrings;
    FForCanvas  : Boolean;
    FIndent     : String;
    // the defaults as the lines written so far leave them
    DefFontName : String;
    DefSize     : Integer;
    DefStyle    : Integer;
    DefFontCol  : Integer;
    DefColor    : Integer;
    DefAlign    : Integer;
    DefParent   : TMdComponent;
    procedure   Emit(const Line : String);
    procedure   Warn(C : TMdComponent; const Field, Msg : String);
    function    Written(C : TMdComponent; const Field, S : String; DollarBreak : Boolean) : String;
    procedure   ResetDefaults;
    procedure   DefaultColor(Font : Boolean; C : Integer);
    procedure   NeedDefaults(C : TMdComponent);
    procedure   NeedParent(Container : TMdComponent);
    function    CreateLine(C : TMdComponent) : String;
    procedure   AfterCreate(C : TMdComponent);
    procedure   EmitComponent(C : TMdComponent);
    procedure   EmitForm0(F : TMdComponent);
    procedure   EmitForm(F : TMdComponent);
  public
    Warnings    : TStringList;   // "name: field: message", Objects = the component
    constructor Create;
    destructor  Destroy; override;
    procedure   FileLines(Doc : TMdDocument; Lines : TStrings);
    procedure   FormLines(Doc : TMdDocument; F : TMdComponent; Lines : TStrings;
                  ForCanvas : Boolean = False);
  end;

function SubName(F : TMdComponent) : String;
function TextOnLine(const S : String; DollarBreak : Boolean; out Written, Shown : String) : Boolean;
function SafeText(const Written : String) : String;
function ColorWord(C : Integer) : String;
function BoolWord(B : Boolean) : String;
function DrawOpArgs(const Op : TMdDrawOp) : String;
procedure HeaderLines(Doc : TMdDocument; Lines : TStrings);

implementation

uses
  Graphics, EuoScriptWords, EuoMenuSelect, EuoMenuCommon, ReforgedVersion;

////////////////////////////////////////////////////////////////////////////////
function SubName(F : TMdComponent) : String;
begin
  Result:='menu_'+F.Name;
end;

function BoolWord(B : Boolean) : String;
begin
  if B then Result:='#true' else Result:='#false';
end;

// For a command that reads its colour with SToCol (which puts 'cl' in front of a name): the name,
// if Delphi 7's StringToColor (EasyUO 1.6) and LCL's (Reforged) both know it -- a Windows system
// colour up to clMenuBar, or one of the standard colours -- and a number otherwise.
function ColorWord(C : Integer) : String;
const
  Standard : array[0..19] of TColor = (clBlack, clMaroon, clGreen, clOlive, clNavy, clPurple,
    clTeal, clGray, clSilver, clRed, clLime, clYellow, clBlue, clFuchsia, clAqua, clWhite,
    clMoneyGreen, clSkyBlue, clCream, clMedGray);
var
  Ident : String;
  Cnt   : Integer;
  Known : Boolean;
begin
  if (Cardinal(C) and $FFFFFF00)=$FF000000 then
    Known:=(Cardinal(C) and $FF)<=30   // Delphi 7's last system colour is clMenuBar (30)
  else
  begin
    Known:=False;
    for Cnt:=Low(Standard) to High(Standard) do
      if TColor(C)=Standard[Cnt] then Known:=True;
  end;
  if Known and ColorToIdent(ColorFromVcl(C),Ident) and (Copy(Ident,1,2)='cl') then
    Exit(Copy(Ident,3,MaxInt));
  Result:=IntToStr(C);
end;

////////////////////////////////////////////////////////////////////////////////
// What follows "menu image <kind> <name>" for a drawing operation.
function DrawOpArgs(const Op : TMdDrawOp) : String;
begin
  Result:=IntToStr(Op.X1)+' '+IntToStr(Op.Y1);
  case Op.Kind of
    dkLine:
      Result:=Result+Format(' %d %d %s %d',[Op.X2,Op.Y2,ColorWord(Op.Color),Op.PenWidth]);
    dkEllipse, dkRectangle:
      Result:=Result+Format(' %d %d %s %d %d',[Op.X2,Op.Y2,ColorWord(Op.Color),Ord(Op.Fill),Op.PenWidth]);
    dkPix, dkFloodFill:
      Result:=Result+' '+ColorWord(Op.Color);
    dkFile:
      Result:=Result+' '+Op.FileName;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// S as it goes at the end of a line (line breaks as '$' where the command turns '$' into one),
// and what the command will really get from it after the line is split and glued as the
// interpreter does. True when that is S.
function TextOnLine(const S : String; DollarBreak : Boolean; out Written, Shown : String) : Boolean;
var
  Words : TStringList;
  Cnt   : Integer;
  Vars  : Boolean;
begin
  if DollarBreak then Written:=StringReplace(S,#13#10,'$',[rfReplaceAll])
  else Written:=StringReplace(S,#13#10,' ',[rfReplaceAll]);
  Written:=StringReplace(StringReplace(Written,#13,' ',[rfReplaceAll]),#10,' ',[rfReplaceAll]);

  Words:=TStringList.Create;
  try
    SplitScriptLine('menu x '+Written,Words);
    Vars:=False;
    for Cnt:=2 to Words.Count-1 do
      if IsVar(Words[Cnt]) then Vars:=True;
    GlueWords(Words,nil,False);
    Shown:='';
    for Cnt:=2 to Words.Count-1 do
      Shown:=Shown+Words[Cnt]+' ';
    Shown:=Trim(Shown);
  finally
    Words.Free;
  end;
  if DollarBreak then Shown:=StringReplace(Shown,'$',#13#10,[rfReplaceAll]);
  Result:=(Shown=S) and not Vars;
end;

// A text as it is on a line (TextOnLine's Written) without what tokenising would change: words
// that are variables, a lone '.' or ',', words starting with ';', extra spaces.
function SafeText(const Written : String) : String;
var
  Words : TStringList;
  Cnt   : Integer;
  W     : String;
begin
  Result:='';
  Words:=TStringList.Create;
  try
    Words.Delimiter:=' ';
    Words.StrictDelimiter:=True;
    Words.DelimitedText:=StringReplace(Written,#9,' ',[rfReplaceAll]);
    for Cnt:=0 to Words.Count-1 do
    begin
      W:=Words[Cnt];
      if (W='') or (W='.') or (W=',') or (W[1]=';') or IsVar(W) then Continue;
      Result:=Result+W+' ';
    end;
  finally
    Words.Free;
  end;
  Result:=Trim(Result);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TMdGenerator.Create;
begin
  inherited Create;
  Warnings:=TStringList.Create;
end;

destructor TMdGenerator.Destroy;
begin
  Warnings.Free;
  inherited Destroy;
end;

procedure TMdGenerator.Emit(const Line : String);
begin
  FOut.Add(FIndent+Line);
end;

procedure TMdGenerator.Warn(C : TMdComponent; const Field, Msg : String);
begin
  Warnings.AddObject(C.Name+': '+Field+': '+Msg,C);
end;

// S as it goes on the line. When it cannot be written as it is, the words that would be
// substituted, glued or cut off are left out and the spaces collapsed, so that the line
// still works and shows what the canvas shows; the warning says what that is.
function TMdGenerator.Written(C : TMdComponent; const Field, S : String;
  DollarBreak : Boolean) : String;
var
  Shown : String;
begin
  if TextOnLine(S,DollarBreak,Result,Shown) then Exit;
  Result:=SafeText(Result);
  Warn(C,Field,'cannot be written as it is; the script will show "'+Result+'"');
end;

////////////////////////////////////////////////////////////////////////////////
// Every default, as 1.6 has them after a clear, so the sub does not depend on what ran before.
procedure TMdGenerator.ResetDefaults;
begin
  DefFontName:=MdDefFontName;
  DefSize:=MdDefFontSize;
  DefStyle:=0;
  DefFontCol:=MdDefFontColor;
  DefColor:=MdDefColor;
  DefAlign:=0;
  Emit('menu font name '+DefFontName);
  Emit('menu setdef fontsize '+IntToStr(DefSize));
  Emit('menu setdef fontstyle '+IntToStr(DefStyle));
  DefaultColor(True,DefFontCol);
  DefaultColor(False,DefColor);
  Emit('menu setdef alignment '+IntToStr(DefAlign));
end;

// A default colour, by name where one is shared (see the unit header); a system colour without
// one as setdef's Delphi 7 number.
procedure TMdGenerator.DefaultColor(Font : Boolean; C : Integer);
var
  W : String;
begin
  W:=ColorWord(C);
  if (W=IntToStr(C)) and ((Cardinal(C) and $FFFFFF00)=$FF000000) then
  begin
    if Font then Emit('menu setdef fontcolor '+W) else Emit('menu setdef color '+W);
  end
  else if Font then Emit('menu font color '+W)
  else Emit('menu font bgcolor '+W);
end;

// The defaults C is created with, where they differ from the current ones.
procedure TMdGenerator.NeedDefaults(C : TMdComponent);
begin
  if MdTypeHasProp(C.TypeId,'fontname') then
  begin
    if C.FontName<>DefFontName then
    begin
      Emit('menu font name '+Written(C,'font',C.FontName,False));
      DefFontName:=C.FontName;
    end;
    if C.FontSize<>DefSize then
    begin
      Emit('menu setdef fontsize '+IntToStr(C.FontSize));
      DefSize:=C.FontSize;
    end;
    if C.FontStyle<>DefStyle then
    begin
      Emit('menu setdef fontstyle '+IntToStr(C.FontStyle));
      DefStyle:=C.FontStyle;
    end;
    if C.FontColor<>DefFontCol then
    begin
      DefaultColor(True,C.FontColor);
      DefFontCol:=C.FontColor;
    end;
  end;
  if MdTypeHasProp(C.TypeId,'color') and (C.Color<>DefColor) then
  begin
    DefaultColor(False,C.Color);
    DefColor:=C.Color;
  end;
  if (C.Row.Align<>maNone) and (C.Alignment<>DefAlign) then
  begin
    Emit('menu setdef alignment '+IntToStr(C.Alignment));
    DefAlign:=C.Alignment;
  end;
end;

procedure TMdGenerator.NeedParent(Container : TMdComponent);
begin
  if DefParent=Container then Exit;
  Emit('menu setdef parent '+Container.Name);
  DefParent:=Container;
end;

////////////////////////////////////////////////////////////////////////////////
// A text label whose '$' must stay a '$' (setprop text keeps it; menu text would break the line).
function LiteralDollar(C : TMdComponent) : Boolean;
begin
  Result:=(C.TypeId=mdtText) and (Pos('$',C.Text)>0) and (Pos(#13,C.Text)=0) and
    (Pos(#10,C.Text)=0);
end;

function TMdGenerator.CreateLine(C : TMdComponent) : String;
var
  R : TMdTypeRow;

  procedure Field(const Key, Value : String);
  begin
    Result:=StringReplace(Result,'{'+Key+'}',Value,[]);
  end;

begin
  R:=C.Row;
  Result:=R.Create;
  Field('name',C.Name);
  Field('x',IntToStr(C.Left));
  Field('y',IntToStr(C.Top));
  Field('w',IntToStr(C.Width));
  Field('h',IntToStr(C.Height));
  Field('bw',IntToStr(C.BitmapW));
  Field('bh',IntToStr(C.BitmapH));
  Field('checked',BoolWord(C.Checked));
  Field('style',IntToStr(C.ShapeStyle));
  if C.LineOn then Field('linetype','0') else Field('linetype','1');
  Field('linewidth',IntToStr(C.LineWidth));
  Field('linecolor',ColorWord(C.LineColor));
  if C.FillOn then Field('filltype','7') else Field('filltype','0');
  Field('fillcolor',ColorWord(C.FillColor));
  if LiteralDollar(C) then Field('text','')
  else Field('text',Written(C,'text',C.Text,R.DollarBreak));
  Result:=TrimRight(Result);
end;

// What the creating line cannot carry, in an order the controls take it.
procedure TMdGenerator.AfterCreate(C : TMdComponent);
var
  R   : TMdTypeRow;
  Cnt : Integer;
  Op  : TMdDrawOp;
  S   : String;
begin
  R:=C.Row;
  if LiteralDollar(C) then
    Emit('menu setprop '+C.Name+' text '+Written(C,'text',C.Text,False));
  if R.Items then
  begin
    for Cnt:=0 to C.Items.Count-1 do
      Emit('menu '+R.Name+' add '+C.Name+' '+Written(C,'item '+IntToStr(Cnt+1),C.Items[Cnt],False));
    if C.Selected>0 then
      Emit('menu '+R.Name+' select '+C.Name+' '+IntToStr(C.Selected));
  end;

  if R.Drawing then
  begin
    for Cnt:=0 to High(C.Ops) do
    begin
      Op:=C.Ops[Cnt];
      if (Op.Kind=dkFile) and ((SafeText(Op.FileName)<>Op.FileName) or
         (Pos(' ',Op.FileName)>0) or (Op.FileName='')) then
      begin
        Warn(C,'drawing '+IntToStr(Cnt+1),'"'+Op.FileName+'" is not one word without '+
          'variables, which is all menu image file reads; the picture is left out');
        Continue;
      end;
      S:='menu image '+MdDrawWords[Op.Kind]+' '+C.Name+' '+DrawOpArgs(Op);
      if (Op.Kind in [dkLine,dkEllipse,dkRectangle]) and ((Op.X2<0) or (Op.Y2<0) or (Op.PenWidth<0)) then
        Warn(C,'drawing '+IntToStr(Cnt+1),'1.6 draws nothing with a negative x2, y2 or width');
      Emit(S);
    end;
  end;
  if R.Drawing or (C.TypeId=mdtShape) then
    if C.Stretch then
      Emit(Format('menu image pos %s %d %d %d %d',[C.Name,C.Left,C.Top,C.Width,C.Height]))
    else
    begin
      // shown at another size than its bitmap, without stretching (setprop width/height
      // after the drawing)
      if C.Width<>C.BitmapW then Emit('menu setprop '+C.Name+' width '+IntToStr(C.Width));
      if C.Height<>C.BitmapH then Emit('menu setprop '+C.Name+' height '+IntToStr(C.Height));
    end;
  if (C.TypeId=mdtShape) and (C.ShapeStyle in [1,5,6]) and (C.BitmapW<>C.BitmapH) then
    Warn(C,'shape','1.6 draws style '+IntToStr(C.ShapeStyle)+' in a square: it shrinks the '+
      'longer side and centres it');

  if (R.W=szAuto) and C.FixedW then Emit('menu setprop '+C.Name+' width '+IntToStr(C.Width));
  if (R.H=szAuto) and C.FixedH then Emit('menu setprop '+C.Name+' height '+IntToStr(C.Height));
  if (R.Align=maText) and (C.Alignment=1) then
    Emit('menu setprop '+C.Name+' left '+IntToStr(C.Left));

  if C.Tooltip<>'' then
    Emit('menu setprop '+C.Name+' tooltip '+Written(C,'tooltip',C.Tooltip,False));
  if not C.Enabled then Emit('menu setprop '+C.Name+' enabled #false');
  if not C.Visible and not FForCanvas then Emit('menu setprop '+C.Name+' visible #false');
end;

procedure TMdGenerator.EmitComponent(C : TMdComponent);
var
  Cnt : Integer;
begin
  NeedParent(C.Parent);
  NeedDefaults(C);
  if (C.Row.W=szLine) and (C.Width<0) and not C.IsContainer then
    Warn(C,'width','1.6 does not create it with a negative width');
  if (C.Row.H=szLine) and (C.Height<0) and not C.IsContainer then
    Warn(C,'height','1.6 does not create it with a negative height');
  Emit(CreateLine(C));
  AfterCreate(C);
  if C.IsContainer then
  begin
    DefParent:=C;
    for Cnt:=0 to C.ChildCount-1 do
      EmitComponent(C.Child(Cnt));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMdGenerator.EmitForm0(F : TMdComponent);
var
  Cnt : Integer;
begin
  for Cnt:=0 to F.ChildCount-1 do
    Emit('menu delete '+F.Child(Cnt).Name);
  Emit('menu window title '+Written(F,'title',F.Text,False));
  Emit(Format('menu window size %d %d',[F.Width,F.Height]));
  Emit('menu window color '+ColorWord(F.Color));
  if F.Transparency>=0 then Emit('menu window transparent '+IntToStr(F.Transparency));
  if F.Tooltip<>'' then Emit('menu setprop form0 tooltip '+Written(F,'tooltip',F.Tooltip,False));
  if not F.Enabled then Emit('menu setprop form0 enabled #false');
  Emit('menu setdef parent form0');
  DefParent:=F;
  ResetDefaults;
  for Cnt:=0 to F.ChildCount-1 do
    EmitComponent(F.Child(Cnt));
  if FForCanvas then Exit;
  if F.Visible then Emit(Format('menu show %d %d',[F.Left,F.Top]))
  else
  begin
    Emit('menu setprop form0 left '+IntToStr(F.Left));
    Emit('menu setprop form0 top '+IntToStr(F.Top));
    Emit('menu hide');
  end;
end;

procedure TMdGenerator.EmitForm(F : TMdComponent);
var
  Cnt : Integer;
begin
  Emit('menu delete '+F.Name);
  Emit(TrimRight(Format('menu form %s %d %d %d %d %s',[F.Name,F.Left,F.Top,F.Width,F.Height,
    Written(F,'title',F.Text,False)])));
  Emit('menu setprop '+F.Name+' width '+IntToStr(F.Width));
  Emit('menu setprop '+F.Name+' height '+IntToStr(F.Height));
  if F.Color<>MdDefColor then Emit('menu setprop '+F.Name+' color '+IntToStr(F.Color));
  if F.Tooltip<>'' then
    Emit('menu setprop '+F.Name+' tooltip '+Written(F,'tooltip',F.Tooltip,False));
  if not F.Enabled then Emit('menu setprop '+F.Name+' enabled #false');
  DefParent:=F;
  ResetDefaults;
  for Cnt:=0 to F.ChildCount-1 do
    EmitComponent(F.Child(Cnt));
  if F.Visible and not FForCanvas then Emit('menu setprop '+F.Name+' visible #true');
end;

////////////////////////////////////////////////////////////////////////////////
// The MENU lines of F's sub, without "sub" and "return". ForCanvas leaves out what shows or
// hides a window or a component, for the designer's canvas.
procedure TMdGenerator.FormLines(Doc : TMdDocument; F : TMdComponent; Lines : TStrings;
  ForCanvas : Boolean);
begin
  FDoc:=Doc;
  FOut:=Lines;
  FForCanvas:=ForCanvas;
  FIndent:='';
  DefParent:=nil;
  if F.IsForm0 then EmitForm0(F) else EmitForm(F);
end;

procedure HeaderLines(Doc : TMdDocument; Lines : TStrings);
var
  Cnt : Integer;
begin
  Lines.Add('; MENU windows made with the EasyUO Reforged MENU Designer '+REFORGED_VERSION);
  Lines.Add('; Each form is built by its own sub, which can be called again to rebuild it.');
  Lines.Add('menu reforge mode 1.6');
  for Cnt:=0 to Doc.FormCount-1 do
    Lines.Add('gosub '+SubName(Doc.Form(Cnt)));
  Lines.Add('set #MenuButton N/A');
  Lines.Add('while #MenuButton = N/A');
  Lines.Add('  wait 1');
  Lines.Add('halt');
end;

procedure TMdGenerator.FileLines(Doc : TMdDocument; Lines : TStrings);
var
  Cnt  : Integer;
  Body : TStringList;
  Line : Integer;
begin
  Warnings.Clear;
  HeaderLines(Doc,Lines);
  Body:=TStringList.Create;
  try
    for Cnt:=0 to Doc.FormCount-1 do
    begin
      Body.Clear;
      FormLines(Doc,Doc.Form(Cnt),Body);
      Lines.Add('');
      Lines.Add('sub '+SubName(Doc.Form(Cnt)));
      for Line:=0 to Body.Count-1 do
        Lines.Add('  '+Body[Line]);
      Lines.Add('return');
    end;
  finally
    Body.Free;
  end;
end;

end.
