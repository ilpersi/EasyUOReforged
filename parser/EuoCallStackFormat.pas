unit EuoCallStackFormat;

{
  Formats a TScriptList's live state into a human-readable call-stack listing,
  added during the Lazarus/FPC migration (not present in the original Delphi 7
  app at all) to back a new GUI call-stack panel -- see main.pas's
  BuildComponents/UpdateTimerTimer for how it's used.

  Deliberately includes GOSUB frames, not just CALL-pushed file frames: real
  EasyUO scripts nest via GOSUB far more often than they CALL a second script
  file, so a call-stack view that silently dropped GOSUB nesting would be
  close to useless for its actual purpose. TScriptList (EuoScriptStack.pas)
  already tracks both independently -- this unit just walks and formats them.

  Deliberately takes a TScriptList and a raw Cardinal, not a TExecutor/
  TEuoInterpreter -- keeps this unit at parser's lowest dependency layer and
  trivially unit-testable with no interpreter involved, the same reasoning
  EuoBreakCondition.pas already documents for taking pre-resolved state
  instead of re-deriving it from a live interpreter. The caller (main.pas)
  resolves CurLine exactly the way its own MarkLine computation already does
  (BreakLine if paused on a breakpoint, else CurLine+1).

  Objects[] line numbers only make sense against the OWN script text of that
  entry's frame (ScrList.Scrs[Level]) -- a GUI consumer must not assume every
  emitted line number refers to whatever's currently open in an editor tab.
  This is why the GUI panel restricts double-click navigation to the
  innermost call level's own entries only (see main.pas's
  CallStackListBoxDblClick).
}

{$mode delphi}{$H+}

interface

uses
  Classes, EuoScriptStack;

// Returns a NEW TStringList (caller must Free it) describing the live call
// stack, innermost-first (index 0 = where execution actually is right now).
// CurLine is the 1-based line currently executing in the innermost
// activation. Each entry's Objects[i] holds Pointer(PtrUInt(Line)) -- the
// 1-based line number for that activation, for GUI navigation without
// re-parsing the formatted string.
function FormatCallStack(ScrList : TScriptList; CurLine : Cardinal) : TStringList;

implementation

uses
  SysUtils;

////////////////////////////////////////////////////////////////////////////////
function FormatCallStack(ScrList : TScriptList; CurLine : Cardinal) : TStringList;
var
  Level, Ind, Idx : Integer;
  Line            : Cardinal;
begin
  Result:=TStringList.Create;
  Line:=CurLine;
  Idx:=0;

  for Level:=Integer(ScrList.CallLevel) downto 0 do
  begin
    for Ind:=ScrList.SubCount(Level)-1 downto 0 do
    begin
      Result.AddObject('#'+IntToStr(Idx)+'  '+ScrList.SubName(Level,Ind)+
        '  (line '+IntToStr(Line)+')', Pointer(PtrUInt(Line)));
      Line:=ScrList.SubLine(Level,Ind); // unwind: this GOSUB's own caller resumes here
      Inc(Idx);
    end;

    Result.AddObject('#'+IntToStr(Idx)+'  '+ScrList.ScrNames[Level]+
      '  (line '+IntToStr(Line)+')', Pointer(PtrUInt(Line)));
    Inc(Idx);
    if Level>0 then
      Line:=ScrList.CallLines[Level]; // unwind: this frame's parent CALL resumes here
  end;
end;

end.
