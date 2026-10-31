unit mdengine;

{
  Port addition: the MENU Designer's canvas engine (docs/menu-designer.md, section 7). The
  canvas is built by TMenu16 itself: one TMenu16 for the document (names are global in 1.6, as
  in the file), and a form is rebuilt by running the sub the generator writes for it, without
  the lines that show or hide something. So the canvas shows what the script will show -- label
  autosize, edit heights, right-aligned text, clamped form sizes, squeezed shapes, drawings,
  fonts, colours -- by construction, and runs the generator's output on every edit.

  The forms themselves stay hidden: the canvas hosts each form's Surface (the panel every MENU
  control lives on) in its tab. The engine also reads back the sizes controls give themselves
  into the model, for the inspector and for snapping.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, Controls, ExtCtrls, Forms, EuoMenu16, EuoMenuCommon, mdtypes, mdmodel,
  mdgenerate, mdscript;

type
  TMdEngine = class
  private
    FMenu     : TMenu16;
    FDoc      : TMdDocument;
    Built     : TStringList;   // form name -> the TMdComponent it was built from
    function  Registered(const Name : String) : TControl;
    procedure DeleteForm(const Name : String);
  public
    Warnings  : TStringList;
    constructor Create;
    destructor  Destroy; override;
    procedure   Reset(ADoc : TMdDocument);
    procedure   Rebuild(F : TMdComponent);
    procedure   RebuildAll;
    procedure   Forget(F : TMdComponent);
    function    Control(C : TMdComponent) : TControl;
    function    FormWindow(F : TMdComponent) : TEuoMenuForm;
    function    ComponentOf(Ctrl : TControl) : TMdComponent;
    procedure   Measure(F : TMdComponent);
    property    Menu : TMenu16 read FMenu;
  end;

  // The Preview: the whole saved file's MENU lines run through a TMenu16 of its own, in the
  // order the file's header calls the subs, so the real windows appear as the script shows them.
  TMdPreview = class
  private
    FMenu : TMenu16;
  public
    constructor Create(Doc : TMdDocument);
    destructor  Destroy; override;
    function    MenuButton : String;
  end;

implementation

constructor TMdEngine.Create;
begin
  inherited Create;
  Built:=TStringList.Create;
  Warnings:=TStringList.Create;
end;

destructor TMdEngine.Destroy;
begin
  FMenu.Free;
  Warnings.Free;
  Built.Free;
  inherited Destroy;
end;

function TMdEngine.Registered(const Name : String) : TControl;
var
  Cnt   : Integer;
  Lower : String;
begin
  Result:=nil;
  if FMenu=nil then Exit;
  Lower:=LowerCase(Name);
  for Cnt:=0 to FMenu.RegistryCount-1 do
    if FMenu.RegistryName(Cnt)=Lower then Exit(FMenu.RegistryCtrl(Cnt));
end;

// A new document: everything goes, form0 is made again, every form is built.
procedure TMdEngine.Reset(ADoc : TMdDocument);
begin
  FDoc:=ADoc;
  FMenu.Free;
  FMenu:=TMenu16.Create;
  FMenu.ScriptStart;
  Built.Clear;
  RebuildAll;
end;

procedure TMdEngine.DeleteForm(const Name : String);
begin
  if (Name='') or SameText(Name,MdForm0Name) then Exit;
  RunMenuLine(FMenu,'menu delete '+Name);
end;

// A form removed from the document, or about to get another name.
procedure TMdEngine.Forget(F : TMdComponent);
var
  Cnt : Integer;
begin
  for Cnt:=Built.Count-1 downto 0 do
    if Built.Objects[Cnt]=F then
    begin
      DeleteForm(Built[Cnt]);
      Built.Delete(Cnt);
    end;
end;

// F built again from its sub. Names are global, so first everything F will build is deleted
// wherever it is now (a component moved here from another form), and on form0, which stays,
// everything on it (so what was deleted, renamed or moved away goes too); another form goes
// with all it holds, under the name it was built with.
procedure TMdEngine.Rebuild(F : TMdComponent);
var
  Gen   : TMdGenerator;
  Lines : TStringList;
  L     : TList;
  Mine  : TStringList;
  F0    : TEuoMenuForm;
  Cnt   : Integer;
begin
  L:=TList.Create;
  Mine:=TStringList.Create;
  try
    FDoc.AllComponents(L);
    for Cnt:=0 to L.Count-1 do
      if (TMdComponent(L[Cnt]).FormOf=F) and (TMdComponent(L[Cnt])<>F) then
        Mine.Add(TMdComponent(L[Cnt]).Name);
    for Cnt:=0 to Mine.Count-1 do
      if Registered(Mine[Cnt])<>nil then RunMenuLine(FMenu,'menu delete '+Mine[Cnt]);
    if F.IsForm0 then
    begin
      F0:=FormWindow(F);
      Mine.Clear;
      if F0<>nil then
        for Cnt:=0 to FMenu.RegistryCount-1 do
          if (FMenu.RegistryCtrl(Cnt).Parent=F0.Surface) then Mine.Add(FMenu.RegistryName(Cnt));
      for Cnt:=0 to Mine.Count-1 do
        RunMenuLine(FMenu,'menu delete '+Mine[Cnt]);   // a name already gone does nothing
    end
    else
    begin
      Forget(F);
      DeleteForm(F.Name);
    end;
  finally
    Mine.Free;
    L.Free;
  end;

  Gen:=TMdGenerator.Create;
  Lines:=TStringList.Create;
  try
    Gen.FormLines(FDoc,F,Lines,True);
    RunMenuLines(FMenu,Lines);
    for Cnt:=0 to Gen.Warnings.Count-1 do
      Warnings.AddObject(Gen.Warnings[Cnt],Gen.Warnings.Objects[Cnt]);
  finally
    Lines.Free;
    Gen.Free;
  end;
  if not F.IsForm0 then Built.AddObject(F.Name,F);
  Measure(F);
end;

procedure TMdEngine.RebuildAll;
var
  Cnt : Integer;
begin
  Warnings.Clear;
  for Cnt:=0 to FDoc.FormCount-1 do
    Rebuild(FDoc.Form(Cnt));
end;

function TMdEngine.Control(C : TMdComponent) : TControl;
begin
  Result:=Registered(C.Name);
end;

function TMdEngine.FormWindow(F : TMdComponent) : TEuoMenuForm;
var
  C : TControl;
begin
  C:=Registered(F.Name);
  if C is TEuoMenuForm then Result:=TEuoMenuForm(C) else Result:=nil;
end;

function TMdEngine.ComponentOf(Ctrl : TControl) : TMdComponent;
var
  Cnt : Integer;
begin
  Result:=nil;
  if (FMenu=nil) or (Ctrl=nil) then Exit;
  for Cnt:=0 to FMenu.RegistryCount-1 do
    if FMenu.RegistryCtrl(Cnt)=Ctrl then Exit(FDoc.FindName(FMenu.RegistryName(Cnt)));
end;

// The sizes 1.6 gives a control itself, into the model: what the inspector shows and what
// snapping measures. Fixed sizes and sizes on the creating line are the model's already.
procedure TMdEngine.Measure(F : TMdComponent);
var
  L    : TList;
  Cnt  : Integer;
  C    : TMdComponent;
  Ctrl : TControl;
begin
  L:=TList.Create;
  try
    FDoc.AllComponents(L);
    for Cnt:=0 to L.Count-1 do
    begin
      C:=TMdComponent(L[Cnt]);
      if C.FormOf<>F then Continue;
      Ctrl:=Control(C);
      if Ctrl=nil then Continue;
      if (C.Row.W=szFit) or ((C.Row.W=szAuto) and not C.FixedW) then C.Width:=Ctrl.Width;
      if (C.Row.H=szFit) or ((C.Row.H=szAuto) and not C.FixedH) then C.Height:=Ctrl.Height;
      // a form's client area as Windows allows it (its minimum size)
      if C.IsForm then
      begin
        C.Width:=TCustomForm(Ctrl).ClientWidth;
        C.Height:=TCustomForm(Ctrl).ClientHeight;
      end;
    end;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TMdPreview.Create(Doc : TMdDocument);
var
  Gen   : TMdGenerator;
  Lines : TStringList;
begin
  inherited Create;
  FMenu:=TMenu16.Create;
  FMenu.ScriptStart;
  Gen:=TMdGenerator.Create;
  Lines:=TStringList.Create;
  try
    Gen.FileLines(Doc,Lines);
    RunMenuLines(FMenu,Lines);
  finally
    Lines.Free;
    Gen.Free;
  end;
end;

destructor TMdPreview.Destroy;
begin
  FMenu.Free;
  inherited Destroy;
end;

function TMdPreview.MenuButton : String;
begin
  Result:=FMenu.GetMenuButton;
end;

end.
