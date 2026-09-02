unit UoEventsTests;

{
  Tests for uo\uoevents.pas's TUOEvent against a real TUOSel/TUOVar with no
  client selected. Unlike TUOVar/TUOCmd, TUOEvent has no explicit "UOSel.Nr>0"
  gate of its own -- every method calls access.ReadMem/WriteMem/VirtualProtectEx
  directly against UOSel.HProc, which is 0 with no client selected. Those WinAPI
  calls simply fail harmlessly against an invalid/null handle (confirmed: this is
  exactly the same "PHandle=0 -> ReadProcessMemory/WriteProcessMemory just
  return False" behavior access.pas's ReadMem/WriteMem already rely on
  elsewhere), so this file is safely exercisable with no live client -- just not
  independently verifiable at the opcode-payload level, which is almost entirely
  private string-building logic. That level of correctness rests on this
  migration's careful byte-for-byte verbatim porting (see uoevents.pas's own
  header comment) plus eventual live-client verification (the migration plan's
  Phase 7), not on unit tests here.

  This suite's contract is deliberately narrow and honestly scoped: every public
  method must be callable with no client selected and must never raise -- the
  same "no client -> safe no-op" property already proven for TUOVar/TUOCmd.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uoselector, uovariables, uocommands,
  uoevents;

type
  TUoEventsTests = class(TTestCase)
  private
    Sel : TUOSel;
    Vr  : TUOVar;
    Ev  : TUOEvent;
    function NoWaitDelay(Duration : Cardinal) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestExMsgDoesNotRaise;
    procedure TestEvPropertyLeavesPropStrsEmptyWithNoClient;
    procedure TestPathfindDoesNotRaise;
    procedure TestDragDoesNotRaise;
    procedure TestSysMessageDoesNotRaise;
    procedure TestMacroDoesNotRaise;
    procedure TestContTopWithNoContainerIsANoOp;
    procedure TestStatBarWithUnknownIDIsANoOp;
    procedure TestBlockInfoOverLimitLeavesBlockStrEmpty;
    procedure TestBlockInfoWithinLimitDoesNotRaise;
    procedure TestExEv_DragWithUnknownIDIsANoOp;
    procedure TestExEv_DropCDoesNotRaise;
    procedure TestExEv_DropGDoesNotRaise;
    procedure TestExEv_DropPDWithNoDragTypeIsANoOp;
    procedure TestExEv_SkillLockAllDoesNotRaise;
    procedure TestExEv_SkillLockInvalidLockIsANoOp;
    procedure TestExEv_StatLockDoesNotRaise;
    procedure TestExEv_RenamePetWithUnknownIDIsANoOp;
    procedure TestExEv_PopUpWithUnknownIDIsANoOp;
    procedure TestExEv_CustomDoesNotRaise;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
function TUoEventsTests.NoWaitDelay(Duration : Cardinal) : Boolean;
begin
  Result := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.SetUp;
begin
  Sel := TUOSel.Create;
  Vr := TUOVar.Create(Sel);
  Ev := TUOEvent.Create(Sel, Vr, NoWaitDelay);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TearDown;
begin
  Ev.Free;
  Vr.Free;
  Sel.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExMsgDoesNotRaise;
begin
  Ev.ExMsg(12345, 3, 0, 'hello');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestEvPropertyLeavesPropStrsEmptyWithNoClient;
begin
  // A fresh TCstDB (never successfully Update'd) has FEVPROPERTY=0, so
  // EvProperty must exit immediately without touching PropStr1/PropStr2.
  Ev.EvProperty(12345);
  AssertEquals('', Ev.PropStr1);
  AssertEquals('', Ev.PropStr2);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestPathfindDoesNotRaise;
begin
  Ev.Pathfind(100, 100, 0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestDragDoesNotRaise;
begin
  // FindID's linked-list walk never finds a match with no client (CHARPTR
  // reads back 0), so this exercises the "not found -> Exit" path.
  Ev.Drag(12345);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestSysMessageDoesNotRaise;
begin
  Ev.SysMessage('test message', 0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestMacroDoesNotRaise;
begin
  Ev.Macro(1, 0, '');
  Ev.Macro(15, 5, '');  // exercises the FMACROMAP-gated Par2 remap branch
  Ev.Macro(30, 0, '');  // exercises the FMACROMAP-gated Par1>25 branch
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestContTopWithNoContainerIsANoOp;
begin
  Ev.ContTop(0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestStatBarWithUnknownIDIsANoOp;
begin
  Ev.StatBar(12345);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestBlockInfoOverLimitLeavesBlockStrEmpty;
begin
  Ev.BlockInfo(0, 0, 0, 64, 64); // 64*64 > 32*32 -> must Exit before InitEvents
  AssertEquals('', Ev.BlockStr);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestBlockInfoWithinLimitDoesNotRaise;
begin
  Ev.BlockInfo(0, 0, 0, 4, 4);
  AssertEquals(4 * 4 * 2, Length(Ev.BlockStr));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_DragWithUnknownIDIsANoOp;
begin
  Ev.ExEv_Drag(12345);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_DropCDoesNotRaise;
begin
  Ev.ExEv_DropC(12345, 10, 10);
  Ev.ExEv_DropC(12345); // exercises the X<0/Y<0 -> -1/-1 normalization branch
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_DropGDoesNotRaise;
begin
  Ev.ExEv_DropG(100, 100);        // Z=-1000 sentinel -> falls back to CharPosZ
  Ev.ExEv_DropG(100, 100, 5);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_DropPDWithNoDragTypeIsANoOp;
begin
  // DragType defaults to 0 (never set by a successful Drag/ExEv_Drag with no
  // client); GetWearableLayer(0) must return 0 -> Exit before any SendExEvent.
  Ev.ExEv_DropPD;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_SkillLockAllDoesNotRaise;
begin
  // Exercises the repeat/until loop across every entry in SkillList.
  Ev.ExEv_SkillLock('ALL', 1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_SkillLockInvalidLockIsANoOp;
begin
  Ev.ExEv_SkillLock('ALCH', 3); // Lock>2 -> Exit immediately
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_StatLockDoesNotRaise;
begin
  Ev.ExEv_StatLock('STR', 1);
  Ev.ExEv_StatLock('NOSUCHSTAT', 1); // Cnt stays -1 -> Exit
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_RenamePetWithUnknownIDIsANoOp;
begin
  Ev.ExEv_RenamePet(12345, 'Rex');
  Ev.ExEv_RenamePet(12345, ''); // empty name -> Exit before FindID
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_PopUpWithUnknownIDIsANoOp;
begin
  Ev.ExEv_PopUp(12345, 0, 0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoEventsTests.TestExEv_CustomDoesNotRaise;
begin
  Ev.ExEv_Custom(#1#2#3#4);
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TUoEventsTests);
end.
