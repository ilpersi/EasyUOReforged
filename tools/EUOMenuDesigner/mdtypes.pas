unit mdtypes;

{
  Port addition: the MENU Designer's tables (docs/menu-designer.md, sections 3.4 and 8). The
  palette, the inspector, the generator (mdgenerate), the importer (mdimport) and the docs check
  in tests/tools/CheckDocsCoverage.ps1, which reads this file, all go by them.

  Keeping up with the 1.6 MENU syntax: a new 1.6 control type (a new MT_* in EuoMenu16) is a new
  row in MdTypeRows, plus what its creating line needs in mdgenerate and mdimport, its tests, and
  its section on the docs site's designer/components.md. A new property in EuoMenu16's table is
  a new row in MdProps. A new sub-command goes in one of the MdSubs* lists. Whatever is left out
  on purpose goes in MdExcluded, with the reason. The docs check fails until one of these is done.
}

{$mode delphi}{$H+}

interface
uses
  EuoMenu16;

type
  TMdType = (mdtForm, mdtPanel, mdtText, mdtButton, mdtEdit, mdtMemo, mdtCheck, mdtRadio,
             mdtCombo, mdtList, mdtImage, mdtShape);

  // How one of a type's sizes reaches the script.
  TMdSize = (szLine,    // on the creating line
             szAuto,    // the control sizes itself; a fixed size is written with setprop
             szFit);    // the control sizes itself, and the designer does not fix it

  // What the 'alignment' property means for a type.
  TMdAlign = (maNone,
              maText,   // 0 left, 1 right, 2 centre, as setdef alignment and getprop read it
              maCheck); // 0 text right of the box, 1 text left: setdef alignment before creating

  TMdTypeRow = record
    Name        : String;   // palette label, start of new names, heading on components.md
    Kind        : Integer;  // EuoMenu16's MT_*
    Create      : String;   // the creating line, with {fields} the generator fills in
    W, H        : TMdSize;
    DefW, DefH  : Integer;  // size of a new one (for szFit sizes: what the canvas shows first)
    Container   : Boolean;  // forms and panels: the default parent becomes it
    Items       : Boolean;  // combo and list: items and a selection
    Drawing     : Boolean;  // image: drawing operations
    DollarBreak : Boolean;  // '$' in its text is a line break
    HasText     : Boolean;  // the creating line ends with a text
    Align       : TMdAlign;
    Reforged    : Boolean;  // a Reforged addition: real EasyUO 1.6 ignores the line
  end;

const
  // Creating-line fields: {name} {x} {y} {w} {h} {text}; {checked} (check, radio); {bw} {bh}
  // (the bitmap of an image or a shape, which can be shown at another size); {style}
  // {linetype} {linewidth} {linecolor} {filltype} {fillcolor} (shape). Form0 has no creating
  // line: it exists from the script's start.
  MdTypeRows : array[TMdType] of TMdTypeRow = (
    (Name:'form';   Kind:MT_FORM;   Create:'menu form {name} {x} {y} {w} {h} {text}';
     W:szLine; H:szLine; DefW:200; DefH:100; Container:True; Items:False; Drawing:False;
     DollarBreak:False; HasText:True; Align:maNone; Reforged:False),
    (Name:'panel';  Kind:MT_PANEL;  Create:'menu panel {name} {x} {y} {w} {h}';
     W:szLine; H:szLine; DefW:120; DefH:60; Container:True; Items:False; Drawing:False;
     DollarBreak:False; HasText:False; Align:maNone; Reforged:False),
    (Name:'text';   Kind:MT_TEXT;   Create:'menu text {name} {x} {y} {text}';
     W:szAuto; H:szAuto; DefW:40; DefH:16; Container:False; Items:False; Drawing:False;
     DollarBreak:True; HasText:True; Align:maText; Reforged:False),
    (Name:'button'; Kind:MT_BUTTON; Create:'menu button {name} {x} {y} {w} {h} {text}';
     W:szLine; H:szLine; DefW:80; DefH:25; Container:False; Items:False; Drawing:False;
     DollarBreak:False; HasText:True; Align:maNone; Reforged:False),
    (Name:'edit';   Kind:MT_EDIT;   Create:'menu edit {name} {x} {y} {w} {text}';
     W:szLine; H:szAuto; DefW:100; DefH:24; Container:False; Items:False; Drawing:False;
     DollarBreak:False; HasText:True; Align:maNone; Reforged:False),
    (Name:'memo';   Kind:MT_MEMO;   Create:'menu memo {name} {x} {y} {w} {h} {text}';
     W:szLine; H:szLine; DefW:150; DefH:60; Container:False; Items:False; Drawing:False;
     DollarBreak:True; HasText:True; Align:maNone; Reforged:True),
    (Name:'check';  Kind:MT_CHECK;  Create:'menu check {name} {x} {y} {w} {h} {checked} {text}';
     W:szLine; H:szLine; DefW:100; DefH:20; Container:False; Items:False; Drawing:False;
     DollarBreak:False; HasText:True; Align:maCheck; Reforged:False),
    (Name:'radio';  Kind:MT_RADIO;  Create:'menu radio {name} {x} {y} {w} {h} {checked} {text}';
     W:szLine; H:szLine; DefW:100; DefH:20; Container:False; Items:False; Drawing:False;
     DollarBreak:False; HasText:True; Align:maCheck; Reforged:False),
    (Name:'combo';  Kind:MT_COMBO;  Create:'menu combo create {name} {x} {y} {w}';
     W:szLine; H:szAuto; DefW:100; DefH:24; Container:False; Items:True; Drawing:False;
     DollarBreak:False; HasText:False; Align:maNone; Reforged:False),
    (Name:'list';   Kind:MT_LIST;   Create:'menu list create {name} {x} {y} {w} {h}';
     W:szLine; H:szLine; DefW:100; DefH:80; Container:False; Items:True; Drawing:False;
     DollarBreak:False; HasText:False; Align:maNone; Reforged:False),
    (Name:'image';  Kind:MT_IMAGE;  Create:'menu image create {name} {x} {y} {bw} {bh}';
     W:szLine; H:szLine; DefW:64; DefH:64; Container:False; Items:False; Drawing:True;
     DollarBreak:False; HasText:False; Align:maNone; Reforged:False),
    (Name:'shape';  Kind:MT_IMAGE;
     Create:'menu shape {name} {x} {y} {bw} {bh} {style} {linetype} {linewidth} {linecolor} {filltype} {fillcolor}';
     W:szLine; H:szLine; DefW:50; DefH:50; Container:False; Items:False; Drawing:False;
     DollarBreak:False; HasText:False; Align:maNone; Reforged:False));

type
  TMdEditor = (edText, edInt, edBool, edColor, edFontName, edFontStyle, edAlign, edParent);

  TMdPropRow = record
    Name    : String;   // the property's name in EuoMenu16's table (getprop/setprop)
    Caption : String;
    Editor  : TMdEditor;
  end;

const
  // One row per property name in EuoMenu16's table; which types have it comes from that
  // table's masks (Menu16PropRow).
  MdProps : array[0..15] of TMdPropRow = (
    (Name:'alignment'; Caption:'Alignment';   Editor:edAlign),
    (Name:'checked';   Caption:'Checked';     Editor:edBool),
    (Name:'color';     Caption:'Colour';      Editor:edColor),
    (Name:'enabled';   Caption:'Enabled';     Editor:edBool),
    (Name:'fontcolor'; Caption:'Font colour'; Editor:edColor),
    (Name:'fontname';  Caption:'Font';        Editor:edFontName),
    (Name:'fontsize';  Caption:'Font size';   Editor:edInt),
    (Name:'fontstyle'; Caption:'Font style';  Editor:edFontStyle),
    (Name:'height';    Caption:'Height';      Editor:edInt),
    (Name:'left';      Caption:'Left';        Editor:edInt),
    (Name:'parent';    Caption:'Parent';      Editor:edParent),
    (Name:'text';      Caption:'Text';        Editor:edText),
    (Name:'tooltip';   Caption:'Tooltip';     Editor:edText),
    (Name:'top';       Caption:'Top';         Editor:edInt),
    (Name:'visible';   Caption:'Visible';     Editor:edBool),
    (Name:'width';     Caption:'Width';       Editor:edInt));

  // Every sub-command TMenu16.Run dispatches is in one of these three lists.
  // Written by the generator (and read by the importer):
  MdSubsWritten : array[0..17] of String = (
    'FORM', 'PANEL', 'TEXT', 'BUTTON', 'EDIT', 'MEMO', 'CHECK', 'RADIO', 'COMBO', 'LIST',
    'SHAPE', 'IMAGE', 'WINDOW', 'FONT', 'SETDEF', 'SETPROP', 'SHOW', 'DELETE');
  // Read by the importer, never written:
  MdSubsRead : array[0..4] of String = (
    'HIDE', 'CLEAR', 'PUSHDEF', 'POPDEF', 'SET');
  // What a running script reads; the importer reports the line and leaves it out:
  MdSubsRuntime : array[0..4] of String = (
    'GET', 'GETNUM', 'GETPROP', 'GETDEF', 'ACTIVATE');

  // Removed in EasyUO 1.6 (1.6 does nothing with them); the importer reports them.
  MdSubsRemoved : array[0..3] of String = (
    'HIDEEUO', 'TEST', 'FONT TRANSPARENT', 'IMAGE PIXLINE');

  // Left out of the designer on purpose: an MT_* kind, a property name or a sub-command of the
  // 1.6 logic, each with the reason.
  MdExcluded : array[0..0] of String = (
    'MT_DEFAULT'   // the defaults object of setdef/getdef, not a control a window shows
  );

  // What 1.6 gives every new control (TMenu16.ResetDefault), and form0 at the script's start.
  MdDefFontName  = 'Arial';
  MdDefFontSize  = 10;
  MdDefFontColor = 0;
  MdDefColor     = -16777201;   // clBtnFace as a Delphi 7 number
  MdForm0Name    = 'form0';
  MdForm0Title   = 'EUO Menu';

function MdTypeByName(const Name : String; out T : TMdType) : Boolean;
function MdPropIndex(const Name : String) : Integer;
function MdTypeHasProp(T : TMdType; const PropName : String) : Boolean;
function InList(const S : String; const List : array of String) : Boolean;

implementation

uses
  SysUtils;

////////////////////////////////////////////////////////////////////////////////
function MdTypeByName(const Name : String; out T : TMdType) : Boolean;
var
  Cnt : TMdType;
begin
  for Cnt:=Low(TMdType) to High(TMdType) do
    if SameText(MdTypeRows[Cnt].Name,Name) then
    begin
      T:=Cnt;
      Exit(True);
    end;
  T:=mdtForm;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function MdPropIndex(const Name : String) : Integer;
begin
  for Result:=Low(MdProps) to High(MdProps) do
    if SameText(MdProps[Result].Name,Name) then Exit;
  Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
// From EuoMenu16's own table: does a control of this type have the property?
function MdTypeHasProp(T : TMdType; const PropName : String) : Boolean;
var
  Cnt   : Integer;
  Name  : String;
  PType : Integer;
  Mask  : Integer;
begin
  for Cnt:=0 to Menu16PropCount-1 do
  begin
    Menu16PropRow(Cnt,Name,PType,Mask);
    if SameText(Name,PropName) and ((Mask and MdTypeRows[T].Kind)<>0) then Exit(True);
  end;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function InList(const S : String; const List : array of String) : Boolean;
var
  Cnt : Integer;
begin
  for Cnt:=Low(List) to High(List) do
    if SameText(List[Cnt],S) then Exit(True);
  Result:=False;
end;

end.
