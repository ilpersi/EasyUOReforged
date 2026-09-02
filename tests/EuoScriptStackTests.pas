unit EuoScriptStackTests;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoScriptStack, EuoSortedList;

type
  TEuoScriptStackTests = class(TTestCase)
  published
    procedure TestInitialStateIsMainFrameAtLevel0;
    procedure TestAddCallIncrementsLevel;
    procedure TestDelCallReturnsOldLineAndDecrementsLevel;
    procedure TestDelCallAtBaseLevelIsANoOp;
    procedure TestScrIsPerFrame;
    procedure TestAddSubDelSub;
    procedure TestSubLevelResetsOnNewCall;
    procedure TestSubStackCapsAt1001;
    procedure TestClearDropsAllUpperFrames;
    procedure TestInfoIsPerFrameAndSearchable;
    procedure TestCallLinesReflectsReturnLineAtEachFrame;
    procedure TestSubAccessorsEnumerateGosubStackPerLevel;
    procedure TestSubAccessorsAreIndependentAcrossCallLevels;
  end;

implementation

procedure TEuoScriptStackTests.TestInitialStateIsMainFrameAtLevel0;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    AssertEquals(Cardinal(0), S.CallLevel);
    AssertEquals('main', S.ScrName);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestAddCallIncrementsLevel;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    S.AddCall(5,'sub.txt');
    AssertEquals(Cardinal(1), S.CallLevel);
    AssertEquals('sub.txt', S.ScrName);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestDelCallReturnsOldLineAndDecrementsLevel;
var
  S : TScriptList;
  OldLine : Cardinal;
begin
  S := TScriptList.Create;
  try
    S.AddCall(42,'sub.txt');
    OldLine := S.DelCall;
    AssertEquals(Cardinal(42), OldLine);
    AssertEquals(Cardinal(0), S.CallLevel);
    AssertEquals('main', S.ScrName);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestDelCallAtBaseLevelIsANoOp;
var
  S : TScriptList;
  OldLine : Cardinal;
begin
  S := TScriptList.Create;
  try
    OldLine := S.DelCall;
    AssertEquals('no-op at the base frame, per ExitProc''s "restart from 0" contract '+
                 'relying on CallLevel staying 0 rather than DelCall itself acting',
                 Cardinal(0), OldLine);
    AssertEquals(Cardinal(0), S.CallLevel);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestScrIsPerFrame;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    S.Scr.Add('main line');
    S.AddCall(0,'sub');
    AssertEquals('a new frame starts with an empty script list', 0, S.Scr.Count);
    S.Scr.Add('sub line');
    S.DelCall;
    AssertEquals('popping the frame restores the caller''s own script list',
                 1, S.Scr.Count);
    AssertEquals('main line', S.Scr[0]);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestAddSubDelSub;
var
  S : TScriptList;
  OldLine : Cardinal;
begin
  S := TScriptList.Create;
  try
    S.AddSub(10,'MySub');
    AssertEquals(Cardinal(1), S.SubLevel);
    OldLine := S.DelSub;
    AssertEquals(Cardinal(10), OldLine);
    AssertEquals(Cardinal(0), S.SubLevel);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestSubLevelResetsOnNewCall;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    S.AddSub(1,'A');
    S.AddSub(2,'B');
    AssertEquals(Cardinal(2), S.SubLevel);
    S.AddCall(0,'sub');
    AssertEquals('a fresh call frame starts with its own empty gosub stack',
                 Cardinal(0), S.SubLevel);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestSubStackCapsAt1001;
var
  S : TScriptList;
  i : Integer;
begin
  // Exact original quirk (verified directly against scripts.pas): the check runs
  // BEFORE SubLvl is incremented for that call, so the 1001st successful add still
  // goes through; only the 1002nd+ starts trimming the oldest. Steady-state cap is
  // 1001, not a round 1000 -- preserved deliberately, not "cleaned up".
  S := TScriptList.Create;
  try
    for i := 1 to 1001 do
      S.AddSub(i,'F'+IntToStr(i));
    AssertEquals('1001 adds, none capped yet', Cardinal(1001), S.SubLevel);

    S.AddSub(1002,'F1002');
    AssertEquals('the 1002nd add trims the oldest, net level unchanged',
                 Cardinal(1001), S.SubLevel);

    // the oldest entry (OldLine=1) must have been the one dropped
    AssertEquals(Cardinal(1002), S.DelSub);   // newest first
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestClearDropsAllUpperFrames;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    S.AddCall(0,'a');
    S.AddCall(0,'b');
    AssertEquals(Cardinal(2), S.CallLevel);
    S.Clear;
    AssertEquals(Cardinal(0), S.CallLevel);
    AssertEquals('main', S.ScrName);
  finally S.Free; end;
end;

procedure TEuoScriptStackTests.TestInfoIsPerFrameAndSearchable;
var
  S : TScriptList;
  i : Integer;
begin
  S := TScriptList.Create;
  try
    // Info is searched via EuoSortedList.FindSortedPos in the (not yet ported)
    // interpreter, never via TStringList.Find/Sorted -- see EuoSortedList.pas and
    // this unit's header comment for why. Confirm Info supports that pattern.
    //
    // The real call pattern (from parser.pas's LineInfo) searches for just the
    // numeric prefix ("5 "), which is NEVER an exact match against the full stored
    // entry ("5 FOR X 10 + 6") -- the boolean result is correctly False here, and
    // the caller ignores it, using only the returned index (the correct lower-bound
    // position) and then independently confirming via Objects[]. Verified this is
    // not a bug in FindSortedPos: a plain prefix is always lexicographically less
    // than any string it prefixes, so the "insertion point" lands exactly there.
    S.Info.InsertObject(0,'5 FOR X 10 + 6',Pointer(5));
    AssertFalse('a bare prefix is never an exact match against the full entry',
                FindSortedPos(S.Info,'5 ',i));
    AssertEquals('but the returned index is still the right lower-bound position',
                 5, Integer(S.Info.Objects[i]));
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
// New addition (not present in the original app): read-only accessors backing
// the call-stack GUI panel -- see EuoScriptStack.pas's header comment and
// EuoCallStackFormat.pas.
procedure TEuoScriptStackTests.TestCallLinesReflectsReturnLineAtEachFrame;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    AssertEquals('frame 0 has no caller -- meaningless by design, but must not raise',
                 Cardinal(0), S.CallLines[0]);
    S.AddCall(7,'a.txt');
    AssertEquals(Cardinal(7), S.CallLines[1]);
    S.AddCall(20,'b.txt');
    AssertEquals(Cardinal(20), S.CallLines[2]);
    AssertEquals('per-index storage, not a single mutable "last return line"',
                 Cardinal(7), S.CallLines[1]);
    S.DelCall;
    AssertEquals(Cardinal(1), S.CallLevel);
    AssertEquals('popping frame 2 must not disturb frame 1''s own recorded return line',
                 Cardinal(7), S.CallLines[1]);
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoScriptStackTests.TestSubAccessorsEnumerateGosubStackPerLevel;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    S.AddSub(3,'First');
    S.AddSub(9,'Second');
    AssertEquals(2, S.SubCount(0));
    AssertEquals('First', S.SubName(0,0));
    AssertEquals(Cardinal(3), S.SubLine(0,0));
    AssertEquals('oldest-first ordering: index 0 is the outermost GOSUB at this level',
                 'Second', S.SubName(0,1));
    AssertEquals(Cardinal(9), S.SubLine(0,1));
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoScriptStackTests.TestSubAccessorsAreIndependentAcrossCallLevels;
var S : TScriptList;
begin
  S := TScriptList.Create;
  try
    S.AddSub(1,'A');
    S.AddCall(0,'sub.txt'); // a fresh call frame starts with its own empty gosub stack
    S.AddSub(5,'B');
    AssertEquals('level 0''s own gosub stack is untouched by the later AddCall/AddSub',
                 1, S.SubCount(0));
    AssertEquals('A', S.SubName(0,0));
    AssertEquals(1, S.SubCount(1));
    AssertEquals('B', S.SubName(1,0));
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoScriptStackTests);
end.
