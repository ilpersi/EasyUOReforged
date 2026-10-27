unit UoWrapPathTests;

{ FPCUnit tests for the pathfinder's uo.dll methods (uowrap.pas, codes 057..066: GetPath, PathCan,
  PathCheck, PathSet, PathBlock, PathUnblock, PathAvoid, PathLink, PathClear), without a client:
  - through TUOWrap.Execute, as the DLL's exports call it: push "Call", the method's name and its
    arguments; Execute removes those and leaves the answers from stack position 1;
  - TUOCmd's PathSetOption and PathPacked directly, which those methods use. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uowrap, uoselector, uovariables, uocommands, pathplan;

type
  TUoWrapPathTests = class(TTestCase)
  private
    W : TUOWrap;
    function Call(const Name : String; const Args : array of const) : Integer;
    function Answer(Index : Integer) : String;
    function NoWaitDelay(Duration : Cardinal) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEveryPathMethodIsFound;
    procedure TestWrongArgumentsAreRefused;
    procedure TestPlanningWithoutAClientSaysNoclient;
    procedure TestPathSetAnswers;
    procedure TestRulesAnswerOk;
    procedure TestNamesAroundTheNewRowsAreStillFound;
    procedure TestPathSetOptionChangesThePlanner;
    procedure TestPathPackedLayout;
  end;

implementation

const
  RES_OK       = 0;    // uowrap.pas's codes
  ERR_NOTFOUND = -1;
  ERR_WRONGPAR = -2;

procedure TUoWrapPathTests.SetUp;
begin
  W := TUOWrap.Create;
end;

procedure TUoWrapPathTests.TearDown;
begin
  W.Free;
end;

function TUoWrapPathTests.NoWaitDelay(Duration : Cardinal) : Boolean;
begin
  Result := True;
end;

function TUoWrapPathTests.Call(const Name : String; const Args : array of const) : Integer;
var
  i : Integer;
begin
  W.Stack.SetTop(0);
  W.Stack.PushStrVal('Call');
  W.Stack.PushStrVal(PChar(Name));
  for i := 0 to High(Args) do
    case Args[i].VType of
      vtInteger       : W.Stack.PushInteger(Args[i].VInteger);
      vtAnsiString    : W.Stack.PushStrVal(PChar(AnsiString(Args[i].VAnsiString)));
      vtUnicodeString : W.Stack.PushStrVal(PChar(AnsiString(UnicodeString(Args[i].VUnicodeString))));
      vtString        : W.Stack.PushStrVal(PChar(AnsiString(Args[i].VString^)));
      vtPChar         : W.Stack.PushStrVal(Args[i].VPChar);
      vtChar          : W.Stack.PushStrVal(PChar(AnsiString(Args[i].VChar)));
    else
      Fail('unsupported argument type');
    end;
  Result := W.Execute;
end;

function TUoWrapPathTests.Answer(Index : Integer) : String;
begin
  Result := String(W.Stack.GetString(Index));
end;

////////////////////////////////////////////////////////////////////////////////
// Each method in each of its forms (no client: they answer, they don't fail to dispatch).
procedure TUoWrapPathTests.TestEveryPathMethodIsFound;

  procedure Ok(const Name : String; const Args : array of const);
  begin
    AssertEquals(Name + ' with ' + IntToStr(Length(Args)) + ' arguments', RES_OK, Call(Name, Args));
    AssertTrue(Name + ' answers with a state', Answer(1) <> '');
  end;

begin
  Ok('GetPath', [10, 20]);
  Ok('GetPath', [10, 20, 5]);
  Ok('GetPath', [10, 20, 5, 1, 2, 3, 0]);
  Ok('PathCan', [10, 20]);
  Ok('PathCan', [10, 20, 5]);
  Ok('PathCheck', [10, 20]);
  Ok('PathCheck', [10, 20, 5]);
  Ok('PathCheck', [10, 20, 5, 3]);
  Ok('PathSet', ['accuracy', 1]);
  Ok('PathSet', ['mobiles', 'ignore']);
  Ok('PathBlock', [10, 20]);
  Ok('PathBlock', [10, 20, 1]);
  Ok('PathBlock', [10, 20, 12, 22]);
  Ok('PathBlock', [10, 20, 12, 22, 1]);
  Ok('PathUnblock', [10, 20]);
  Ok('PathUnblock', [10, 20, 1]);
  Ok('PathUnblock', [10, 20, 12, 22]);
  Ok('PathUnblock', [10, 20, 12, 22, 1]);
  Ok('PathAvoid', [10, 20, 12, 22, 500]);
  Ok('PathAvoid', [10, 20, 12, 22, 500, 1]);
  Ok('PathLink', [1, 2, 0, 9, 9, 0]);
  Ok('PathLink', [1, 2, 0, 9, 9, 0, 100]);
  Ok('PathLink', [1, 2, 0, 9, 9, 0, 100, 1]);
  Ok('PathClear', []);
  Ok('PathClear', ['links']);
end;

procedure TUoWrapPathTests.TestWrongArgumentsAreRefused;
begin
  AssertEquals('GetPath x', ERR_WRONGPAR, Call('GetPath', [10]));
  AssertEquals('GetPath with 4', ERR_WRONGPAR, Call('GetPath', [10, 20, 5, 1]));
  AssertEquals('PathAvoid with 4', ERR_WRONGPAR, Call('PathAvoid', [10, 20, 12, 22]));
  AssertEquals('PathSet number number', ERR_WRONGPAR, Call('PathSet', [1, 2]));
  AssertEquals('PathLink with 5', ERR_WRONGPAR, Call('PathLink', [1, 2, 0, 9, 9]));
  AssertEquals('names are case-sensitive, as every uo.dll name', ERR_NOTFOUND, Call('getpath', [10, 20]));
end;

procedure TUoWrapPathTests.TestPlanningWithoutAClientSaysNoclient;
var
  Len : Integer;
begin
  AssertEquals(RES_OK, Call('GetPath', [1434, 1699]));
  AssertEquals('noclient', Answer(1));
  AssertEquals('no steps', 0, W.Stack.GetInteger(2));
  W.Stack.GetLString(3, Len);
  AssertEquals('an empty route', 0, Len);
  AssertEquals('state, count, steps', 3, W.Stack.GetTop);

  AssertEquals(RES_OK, Call('PathCan', [1434, 1699, 0]));
  AssertEquals('noclient', Answer(1));
  AssertEquals(0, W.Stack.GetInteger(2));

  AssertEquals(RES_OK, Call('PathCheck', [1434, 1699, 0, 2]));
  AssertEquals('noclient', Answer(1));
  AssertEquals(0, W.Stack.GetInteger(2));
end;

procedure TUoWrapPathTests.TestPathSetAnswers;

  procedure Expect(const Want, Opt : String; const Val : array of const);
  var
    Args : array of TVarRec;
  begin
    SetLength(Args, 2);
    Args[0].VType := vtAnsiString;
    Args[0].VAnsiString := Pointer(Opt);
    Args[1] := Val[0];
    AssertEquals(Opt, RES_OK, Call('PathSet', Args));
    AssertEquals(Opt, Want, Copy(Answer(1), 1, Length(Want)));
  end;

begin
  Expect('ok', 'accuracy', [1]);
  Expect('ok', 'accuracyz', [5]);
  Expect('ok', 'maxnodes', [1000000]);
  Expect('ok', 'timeout', [5000]);
  Expect('ok', 'margin', [100]);
  Expect('ok', 'turncost', [30]);
  Expect('ok', 'heuristic', ['100']);
  Expect('ok', 'doorcost', [50]);
  Expect('ok', 'difs', ['off']);
  Expect('ok', 'mobiles', ['block']);
  Expect('ok', 'doors', ['all']);
  Expect('ok', 'DOORS', ['On']);
  Expect('error: mode is a walking option', 'mode', ['steps']);
  Expect('error: check is a walking option', 'check', [12]);
  Expect('error: unknown path option: bogus', 'bogus', [1]);
  Expect('error: accuracy needs a number of 0 or more', 'accuracy', ['x']);
  Expect('error: accuracy needs a number of 0 or more', 'accuracy', [-1]);
  Expect('error: doors on|off|all', 'doors', ['maybe']);
end;

procedure TUoWrapPathTests.TestRulesAnswerOk;
begin
  Call('PathBlock', [10, 20, 12, 22]);
  AssertEquals('ok', Answer(1));
  Call('PathUnblock', [11, 21]);
  AssertEquals('ok', Answer(1));
  Call('PathAvoid', [10, 20, 12, 22, 500]);
  AssertEquals('ok', Answer(1));
  Call('PathLink', [1, 2, 0, 9, 9, 0]);
  AssertEquals('ok', Answer(1));
  Call('PathClear', ['learned']);
  AssertEquals('ok', Answer(1));
  Call('PathClear', ['all']);
  AssertEquals('ok', Answer(1));
  Call('PathClear', ['nonsense']);
  AssertEquals('error: PathClear [blocks|avoid|links|learned|all]', Answer(1));
end;

// The new rows sit between GetJournal and GetPix, and between PR and Pathfind: the binary search
// still finds those (no client, so each does nothing).
procedure TUoWrapPathTests.TestNamesAroundTheNewRowsAreStillFound;
begin
  AssertEquals('GetJournal', RES_OK, Call('GetJournal', [0]));
  AssertEquals('Pathfind', RES_OK, Call('Pathfind', [10, 20]));
  AssertEquals('Popup', RES_OK, Call('Popup', [12345]));
  AssertEquals('BlockInfo', RES_OK, Call('BlockInfo', [10, 20, 0, 2, 2]));
end;

procedure TUoWrapPathTests.TestPathSetOptionChangesThePlanner;
var
  Sel : TUOSel;
  Vr  : TUOVar;
  Cmd : TUOCmd;
begin
  Sel := TUOSel.Create;
  Vr := TUOVar.Create(Sel);
  Cmd := TUOCmd.Create(Sel, Vr, @NoWaitDelay);
  try
    AssertEquals('ok', Cmd.PathSetOption('accuracy', '3'));
    AssertEquals(3, Cmd.PathPlanner.AccuracyXY);
    AssertEquals('ok', Cmd.PathSetOption('Timeout', '2500'));
    AssertEquals('milliseconds', 2500, Cmd.PathPlanner.TimeoutMs);
    AssertEquals('ok', Cmd.PathSetOption('heuristic', '120'));
    AssertEquals(120, Cmd.PathPlanner.Heuristic);
    AssertEquals('ok', Cmd.PathSetOption('mobiles', 'ignore'));
    AssertTrue(Cmd.PathLive.IgnoreMobiles);
    AssertEquals('ok', Cmd.PathSetOption('doors', 'all'));
    AssertTrue(Cmd.PathLive.OpenHouseDoors);
    AssertEquals('ok', Cmd.PathSetOption('doors', 'off'));
    AssertFalse(Cmd.PathLive.OpenDoors);
    AssertEquals('ok', Cmd.PathSetOption('difs', 'on'));
    AssertTrue(Cmd.PathDifs);
    AssertEquals('ok', Cmd.PathSetOption('doorcost', '80'));
    AssertEquals(80, Cmd.PathLive.DoorCost);
    AssertTrue('a bad value changes nothing', Cmd.PathSetOption('accuracy', 'x') <> 'ok');
    AssertEquals(3, Cmd.PathPlanner.AccuracyXY);
  finally
    Cmd.Free;
    Vr.Free;
    Sel.Free;
  end;
end;

// 6 bytes a step: X and Y low byte first, Z signed, the direction (8 for a link).
procedure TUoWrapPathTests.TestPathPackedLayout;
var
  Sel : TUOSel;
  Vr  : TUOVar;
  Cmd : TUOCmd;
  S   : String;
begin
  Sel := TUOSel.Create;
  Vr := TUOVar.Create(Sel);
  Cmd := TUOCmd.Create(Sel, Vr, @NoWaitDelay);
  try
    AssertEquals('no plan, no bytes', '', Cmd.PathPacked);
    SetLength(Cmd.PathPlanner.Steps, 2);
    Cmd.PathPlanner.StepCount := 2;
    Cmd.PathPlanner.Steps[0].X := 2709;
    Cmd.PathPlanner.Steps[0].Y := 511;
    Cmd.PathPlanner.Steps[0].Z := 15;
    Cmd.PathPlanner.Steps[0].Dir := 1;
    Cmd.PathPlanner.Steps[1].X := 300;
    Cmd.PathPlanner.Steps[1].Y := 4000;
    Cmd.PathPlanner.Steps[1].Z := -5;
    Cmd.PathPlanner.Steps[1].Dir := PATH_DIR_LINK;
    S := Cmd.PathPacked;
    AssertEquals(12, Length(S));
    AssertEquals(#$95#$0A#$FF#$01#$0F#$01#$2C#$01#$A0#$0F#$FB#$08, S);
  finally
    Cmd.Free;
    Vr.Free;
    Sel.Free;
  end;
end;

initialization
  RegisterTest(TUoWrapPathTests);
end.
