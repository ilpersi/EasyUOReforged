unit EuoScriptStack;

{
  Ported from the original Delphi 7 parser\scripts.pas.

  Note for the not-yet-ported interpreter: the per-frame Info list (one TStringList
  per call-frame, created below in AddCall) is searched via .Find in the original
  parser.pas's LineInfo/ContinueBreakProc/ForProc/WhileProc/IfProc, and kept in
  sorted order manually (Find for insertion point, then Insert/InsertObject at that
  point, never .Add) -- exactly the pattern that turned out to conflict with FPC's
  TStringList.Sorted (see EuoSortedList.pas's header comment for the full story).
  Those future call sites must use EuoSortedList.FindSortedPos, not .Find/Sorted:=True.
  Info is deliberately left as a plain (Sorted=False) TStringList here for that reason.

  AddSub's cap deserves a note since it's easy to "round off" by accident: reading
  the original precisely, the steady-state cap is 1001 entries, not a clean 1000 --
  the check "if SubLevel>1000" runs BEFORE SubLvl is incremented for that call, so
  the 1001st successful add still goes through (SubLevel was 1000, not >1000) and
  only the 1002nd+ call trims. Preserved exactly (including the off-by-one) rather
  than "cleaned up" to a round 1000, since scripts with very deep GoSub recursion
  could observably depend on the exact depth at which old entries start dropping.

  DelCall's field-mutation order matters and is preserved exactly: free+delete the
  InfoList/SubList entries for the current level FIRST, capture the OldLine return
  value from CallList.Objects, THEN delete the CallList entry, THEN delete the
  ScrList entry, THEN recompute SubLvl from the new (now one level shallower) SubList.

  CallLines/SubCount/SubName/SubLine, added during the Lazarus/FPC migration (not
  present in the original Delphi 7 source): read-only views onto state AddCall/DelCall/
  AddSub/DelSub already maintain exactly as before -- no new invariants, no change to
  any existing mutating behavior. Added for a new GUI call-stack panel, which needs to
  enumerate the FULL two-dimensional stack (every CALL level's own return line, and
  every CALL level's own GOSUB stack of name+return-line pairs) rather than just the
  current level's counts (CallLevel/SubLevel), which is all the original ever exposed.
  SubCount/SubName/SubLine deliberately take an explicit Level parameter, unlike Scr/
  Info/ScrName's implicit-current-level style -- a caller enumerating the whole stack
  needs every level's own GOSUB stack, not just the current (innermost) one. Ind is
  oldest-first (index 0 = outermost GOSUB at that level), matching SubList's existing
  plain-append storage order (AddSub always appends, DelSub always pops Count-1).
}

{$mode delphi}{$H+}

interface
uses Classes;

type
  TScriptList   = class(TObject)
  private
    ScrList     : TList;
    InfoList    : TList;
    SubList     : TList;
    CallList    : TStringList;
    SubLvl      : Cardinal;
    function    GetScrs(Ind : Integer) : TStringList;
    function    GetScrNames(Ind : Integer) : String;
    function    GetCallLines(Ind : Integer) : Cardinal;
  public
    constructor Create;
    procedure   Free;
    procedure   Clear;
    function    CallLevel : Cardinal;
    procedure   AddCall(OldLine : Cardinal; FN : String);
    function    DelCall : Cardinal;
    procedure   AddSub(OldLine : Cardinal; SN : String);
    function    DelSub : Cardinal;
    function    Info : TStringList;
    function    Scr : TStringList;
    function    ScrName : String;
    property    Scrs[i : Integer] : TStringList read GetScrs;
    property    ScrNames[i : Integer] : String read GetScrNames;
    property    CallLines[i : Integer] : Cardinal read GetCallLines;
    property    SubLevel : Cardinal read SubLvl;
    function    SubCount(Level : Integer) : Integer;
    function    SubName(Level, Ind : Integer) : String;
    function    SubLine(Level, Ind : Integer) : Cardinal;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TScriptList.Create;
begin
  inherited Create;                                        // Create lists
  ScrList:=TList.Create;
  InfoList:=TList.Create;
  SubList:=TList.Create;
  CallList:=TStringList.Create;
  AddCall(0,'main');                                       // Add lowest level
end;

////////////////////////////////////////////////////////////////////////////////
procedure TScriptList.Free;
var
  Cnt  : Integer;
begin
  for Cnt:=0 to CallLevel do                               // Free all lists
  begin
    TObject(ScrList[Cnt]).Free;
    TObject(InfoList[Cnt]).Free;
    TObject(SubList[Cnt]).Free;
  end;
  ScrList.Free;
  InfoList.Free;
  SubList.Free;
  CallList.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TScriptList.Clear;
begin
  while CallLevel>0 do DelCall;                            // Delete all upper levels
  //TStringList(ScrList[0]).Clear;                         // Clear lowest level
  TStringList(InfoList[0]).Clear;
  TStringList(SubList[0]).Clear;
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.CallLevel : Cardinal;
begin
  Result:=ScrList.Count-1;                                 // GetLevel
end;

////////////////////////////////////////////////////////////////////////////////
procedure TScriptList.AddCall(OldLine : Cardinal; FN : String);
begin
  ScrList.Add(TStringList.Create);                         // Add a new level
  InfoList.Add(TStringList.Create);
  SubList.Add(TStringList.Create);
  CallList.AddObject(FN,Pointer(OldLine));
  SubLvl:=0;
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.DelCall : Cardinal;
begin
  Result:=0;
  if CallLevel<1 then Exit;                                // Check
  TObject(ScrList[CallLevel]).Free;                        // Delete last CallLevel
  TObject(InfoList[CallLevel]).Free;
  TObject(SubList[CallLevel]).Free;
  InfoList.Delete(CallLevel);
  SubList.Delete(CallLevel);
  Result:=Cardinal(CallList.Objects[CallLevel]);
  CallList.Delete(CallLevel);
  ScrList.Delete(CallLevel);
  SubLvl:=TStringList(SubList[CallLevel]).Count;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TScriptList.AddSub(OldLine : Cardinal; SN : String);
begin
  with TStringList(SubList[CallLevel]) do
  begin
    AddObject(SN,Pointer(OldLine));
    if SubLevel>1000 then Delete(0)
    else Inc(SubLvl);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.DelSub : Cardinal;
begin
  Result:=0;
  with TStringList(SubList[CallLevel]) do
    if Count>0 then
  begin
    Result:=Cardinal(Objects[Count-1]);
    Delete(Count-1);
    SubLvl:=Count;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.Info : TStringList;
begin
  Result:=TStringList(InfoList[CallLevel]);
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.Scr : TStringList;
begin
  Result:=TStringList(ScrList[CallLevel]);
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.ScrName : String;
begin
  Result:=CallList[CallLevel];
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.GetScrs(Ind : Integer) : TStringList;
begin
  Result:=TStringList(ScrList[Ind]);
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.GetScrNames(Ind : Integer) : String;
begin
  Result:=CallList[Ind];
end;

////////////////////////////////////////////////////////////////////////////////
// CallLines[0] is always 0 (the OldLine passed to Create's synthetic
// AddCall(0,'main') above) -- frame 0 has no caller, so this value is
// meaningless by design; callers must never treat it as a real line.
function TScriptList.GetCallLines(Ind : Integer) : Cardinal;
begin
  Result:=Cardinal(CallList.Objects[Ind]);
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.SubCount(Level : Integer) : Integer;
begin
  Result:=TStringList(SubList[Level]).Count;
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.SubName(Level, Ind : Integer) : String;
begin
  Result:=TStringList(SubList[Level])[Ind];
end;

////////////////////////////////////////////////////////////////////////////////
function TScriptList.SubLine(Level, Ind : Integer) : Cardinal;
begin
  Result:=Cardinal(TStringList(SubList[Level]).Objects[Ind]);
end;

////////////////////////////////////////////////////////////////////////////////
end.
