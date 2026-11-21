unit EuoWatchViewTests;

{
  Tests for easyuo\euwatch.pas -- the Watches panel: its rows (the watches, then the variables the
  script uses), adding and removing watches per editor, values read from the tab's run, the values
  a step changed (red, with the old value in the hint), a value set while paused, a freed editor and
  the saved list. On a form that is never shown and editors without a window, as
  EuoOutlineViewTests does, with a real TExecutor and no client (a timing-sensitive smoke test like
  EuoExecutorTests: it waits for the script's thread).
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, fpcunit, testregistry, Registry,
  SynEdit, EuoExecutor, euwatch;

type
  TEuoWatchViewTests = class(TTestCase)
  private
    FForm       : TForm;
    FPanel      : TPanel;
    FView       : TEuoWatchView;
    FExec       : TExecutor;
    FEds        : TList;
    FChangedEd  : TSynEdit;
    FChangedCnt : Integer;
    function  NewEd(const Src : array of String) : TSynEdit;
    procedure WatchesChanged(Ed : TSynEdit);
    // the rows, ' | ' between them: [text] for a grey row, name=value for the others
    function  Rows : String;
    function  RowOf(const Name : String; Kind : TEuoWatchRowKind) : Integer;
    function  WaitForVar(const Name, Expected : String) : Boolean;
    procedure WaitPaused;
    procedure Step(const Name, Expected : String);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRowsAreWatchesThenScriptVariables;
    procedure TestAddWatchRefusesWhatIsNotAVariable;
    procedure TestWatchesAreKeptPerEditor;
    procedure TestRemoveAndClearWatches;
    procedure TestValuesComeFromTheRun;
    procedure TestTextIsRescannedOnceTypingStops;
    procedure TestStepMarksChangedValues;
    procedure TestValueSetWhilePausedIsNotAChange;
    procedure TestFreedEditor;
    procedure TestWatchesSavedPerScript;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.SetUp;
var
  StartTick : Cardinal;
begin
  Application.Initialize;   // console runner never does; registers the window classes
  FEds:=TList.Create;
  FForm:=TForm.CreateNew(nil);
  FForm.SetBounds(0,0,400,300);
  FPanel:=TPanel.Create(FForm);
  FPanel.Parent:=FForm;
  FPanel.Align:=alClient;
  FView:=TEuoWatchView.Create(FForm,FPanel);
  FView.OnWatchesChanged:=WatchesChanged;
  FChangedEd:=nil;
  FChangedCnt:=0;
  FExec:=TExecutor.Create(0);
  // LoadScript only takes effect once the thread has settled into Paused (EuoExecutorTests)
  StartTick:=GetTickCount;
  while (not FExec.Paused) and (GetTickCount-StartTick<2000) do
    Sleep(5);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TearDown;
var
  i : Integer;
begin
  FExec.Free;
  FForm.Free;   // the view goes first: it lets go of its editor
  for i:=0 to FEds.Count-1 do
    TSynEdit(FEds[i]).Free;
  FEds.Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchViewTests.NewEd(const Src : array of String) : TSynEdit;
var
  Cnt : Integer;
begin
  Result:=TSynEdit.Create(nil);
  FEds.Add(Result);
  for Cnt:=Low(Src) to High(Src) do
    Result.Lines.Add(Src[Cnt]);
end;

procedure TEuoWatchViewTests.WatchesChanged(Ed : TSynEdit);
begin
  FChangedEd:=Ed;
  Inc(FChangedCnt);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchViewTests.Rows : String;
var
  i : Integer;
begin
  Result:='';
  for i:=0 to FView.RowCount-1 do
  begin
    if i>0 then Result:=Result+' | ';
    if FView.RowKind(i)=wrkHeader then Result:=Result+'['+FView.RowText(i)+': '+FView.RowValue(i)+']'
    else Result:=Result+FView.RowName(i)+'='+FView.RowValue(i);
  end;
  // the list shows the same
  AssertEquals('list items',FView.RowCount,FView.List.Items.Count);
  for i:=0 to FView.RowCount-1 do
  begin
    AssertEquals('caption',FView.RowText(i),FView.List.Items[i].Caption);
    AssertEquals('value',FView.RowValue(i),FView.List.Items[i].SubItems[0]);
  end;
end;

function TEuoWatchViewTests.RowOf(const Name : String; Kind : TEuoWatchRowKind) : Integer;
begin
  for Result:=0 to FView.RowCount-1 do
    if (FView.RowKind(Result)=Kind) and SameText(FView.RowName(Result),Name) then Exit;
  Fail('no row '+Name);
  Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoWatchViewTests.WaitForVar(const Name, Expected : String) : Boolean;
var
  StartTick : Cardinal;
begin
  StartTick:=GetTickCount;
  repeat
    if FExec.GetVar(Name)=Expected then
    begin
      Result:=True;
      Exit;
    end;
    Sleep(10);
  until GetTickCount-StartTick>5000;
  Result:=False;
end;

procedure TEuoWatchViewTests.WaitPaused;
var
  StartTick : Cardinal;
begin
  StartTick:=GetTickCount;
  while not ((FExec.State=PAUSE) and FExec.Paused) and (GetTickCount-StartTick<3000) do
    Sleep(5);
  AssertTrue('the script did not pause',(FExec.State=PAUSE) and FExec.Paused);
end;

// One Step Into, until Name reads Expected and the script has paused again.
procedure TEuoWatchViewTests.Step(const Name, Expected : String);
begin
  FExec.State:=STEPINTO;
  AssertTrue(Name+' never read '+Expected,WaitForVar(Name,Expected));
  WaitPaused;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestRowsAreWatchesThenScriptVariables;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(['set %b 1','set %a #euover','if #true = %c','halt']);
  FView.Refresh(Ed,FExec);
  AssertEquals('[Watches: none: Ctrl+F5 adds the variable at the cursor] | '+
    '[Script variables: 4] | %a=N/A | %b=N/A | %c=N/A | #euover=1_50_00',Rows);

  AssertTrue(FView.AddWatch(Ed,'%b'));
  AssertTrue(FView.AddWatch(Ed,'#EUOVer'));
  AssertEquals('[Watches: 2] | %b=N/A | #EUOVer=1_50_00 | '+
    '[Script variables: 4] | %a=N/A | %b=N/A | %c=N/A | #euover=1_50_00',Rows);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestAddWatchRefusesWhatIsNotAVariable;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(['halt']);
  FView.Refresh(Ed,FExec);
  AssertFalse('two words',FView.AddWatch(Ed,'%a b'));
  AssertFalse('no sigil',FView.AddWatch(Ed,'abc'));
  AssertFalse('a sigil alone',FView.AddWatch(Ed,'%'));
  AssertFalse('an expression',FView.AddWatch(Ed,'%a+1'));
  AssertEquals('nothing added, nothing saved',0,FChangedCnt);

  AssertTrue('trimmed',FView.AddWatch(Ed,'  %ok '));
  AssertTrue('already a watch',FView.AddWatch(Ed,'%OK'));
  AssertEquals('%ok',Trim(WatchStateOf(Ed).Watches.Text));
  AssertEquals('changed once',1,FChangedCnt);
  AssertSame(Ed,FChangedEd);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestWatchesAreKeptPerEditor;
var
  Ed1, Ed2 : TSynEdit;
begin
  Ed1:=NewEd(['halt']);
  Ed2:=NewEd(['halt']);
  FView.Refresh(Ed1,FExec);
  FView.AddWatch(Ed1,'%x');
  FView.Refresh(Ed2,FExec);
  FView.AddWatch(Ed2,'%y');
  AssertEquals('[Watches: 1] | %y=N/A | [Script variables: 0]',Rows);
  FView.Poll(Ed1,FExec);
  AssertEquals('[Watches: 1] | %x=N/A | [Script variables: 0]',Rows);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestRemoveAndClearWatches;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(['halt']);
  FView.Refresh(Ed,FExec);
  FView.AddWatch(Ed,'%a');
  FView.AddWatch(Ed,'%b');
  FView.AddWatch(Ed,'%c');
  FView.RemoveWatch(Ed,'%B');
  AssertEquals('[Watches: 2] | %a=N/A | %c=N/A | [Script variables: 0]',Rows);
  FView.RemoveWatch(Ed,'%nosuch');
  AssertEquals('a name that is no watch changes nothing',4,FChangedCnt);
  FView.ClearWatches(Ed);
  AssertEquals(0,WatchStateOf(Ed).Watches.Count);
  AssertEquals(5,FChangedCnt);
end;

////////////////////////////////////////////////////////////////////////////////
// Set values show; a variable the run made without its name in the text (%ZZ) is listed too.
procedure TEuoWatchViewTests.TestValuesComeFromTheRun;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(['set %a 1','halt']);
  FView.Refresh(Ed,FExec);
  FView.AddWatch(Ed,'%a');
  FExec.SetVar('%a','5');
  FExec.SetVar('%zz','q');
  FView.Poll(Ed,FExec);
  AssertEquals('[Watches: 1] | %a=5 | [Script variables: 2] | %a=5 | %ZZ=q',Rows);
end;

////////////////////////////////////////////////////////////////////////////////
// The text is scanned again once it has stayed the same for WatchQuietPolls polls.
procedure TEuoWatchViewTests.TestTextIsRescannedOnceTypingStops;
var
  Ed : TSynEdit;
  i  : Integer;
begin
  Ed:=NewEd(['set %a 1']);
  FView.Refresh(Ed,FExec);
  Ed.Lines.Add('set %b 2');
  FView.Poll(Ed,FExec);
  AssertEquals('not yet','[Watches: none: Ctrl+F5 adds the variable at the cursor] | '+
    '[Script variables: 1] | %a=N/A',Rows);
  for i:=1 to WatchQuietPolls do FView.Poll(Ed,FExec);
  AssertEquals('[Watches: none: Ctrl+F5 adds the variable at the cursor] | '+
    '[Script variables: 2] | %a=N/A | %b=N/A',Rows);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestStepMarksChangedValues;
var
  Ed  : TSynEdit;
  Old : String;
  R   : Integer;
begin
  Ed:=NewEd(['set %a 1','set %a 2','set %list . 3 x','halt']);
  FView.Refresh(Ed,FExec);
  FView.AddWatch(Ed,'%a');
  FExec.LoadScript(Ed.Text);

  Step('%a','1');
  FView.Poll(Ed,FExec);
  AssertFalse('nothing is red at the first pause',FView.RowChanged(RowOf('%a',wrkWatch),Old));

  Step('%a','2');
  FView.Poll(Ed,FExec);
  R:=RowOf('%a',wrkWatch);
  AssertTrue('the watch',FView.RowChanged(R,Old));
  AssertEquals('1',Old);
  AssertEquals('Was: 1'+LineEnding+'Now: 2',FView.RowHint(R));
  AssertTrue('the script row',FView.RowChanged(RowOf('%a',wrkScript),Old));
  FView.Poll(Ed,FExec);
  AssertTrue('the same pause seen again stays red',FView.RowChanged(R,Old));

  Step('%list3','x');
  FView.Poll(Ed,FExec);
  AssertFalse('%a did not change this time',FView.RowChanged(RowOf('%a',wrkWatch),Old));
  AssertTrue('a variable the run made',FView.RowChanged(RowOf('%LIST3',wrkScript),Old));
  AssertEquals('N/A',Old);
  AssertEquals('Was: N/A'+LineEnding+'Now: x',FView.RowHint(RowOf('%LIST3',wrkScript)));
  AssertEquals('an unchanged row''s hint','%a: 2',FView.RowHint(RowOf('%a',wrkWatch)));

  FExec.State:=PLAY;   // runs the HALT
  AssertTrue(WaitForVar('%list3','x'));
  Sleep(200);
  FView.Poll(Ed,FExec);
  AssertFalse('nothing is red once it stopped',FView.RowChanged(RowOf('%LIST3',wrkScript),Old));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestValueSetWhilePausedIsNotAChange;
var
  Ed  : TSynEdit;
  Old : String;
begin
  Ed:=NewEd(['set %a 1','set %b 2','set %c 3','halt']);
  FView.Refresh(Ed,FExec);
  FExec.LoadScript(Ed.Text);
  Step('%a','1');
  FView.Poll(Ed,FExec);
  FView.SetRowValue(RowOf('%c',wrkScript),'7');
  AssertEquals('7',FExec.GetVar('%c'));
  Step('%b','2');
  FView.Poll(Ed,FExec);
  AssertTrue(FView.RowChanged(RowOf('%b',wrkScript),Old));
  AssertFalse('set by hand, not by the step',FView.RowChanged(RowOf('%c',wrkScript),Old));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoWatchViewTests.TestFreedEditor;
var
  Ed : TSynEdit;
begin
  Ed:=NewEd(['set %a 1']);
  FView.Refresh(Ed,FExec);
  FView.AddWatch(Ed,'%a');
  FEds.Remove(Ed);
  Ed.Free;
  AssertNull('the view lets go of it',FView.Editor);
  AssertEquals('no rows',0,FView.RowCount);
  AssertEquals('the list is empty',0,FView.List.Items.Count);
  FView.Poll(nil,FExec);
  AssertEquals(0,FView.RowCount);
end;

////////////////////////////////////////////////////////////////////////////////
// The list is saved under the script's path, which ignores case; an empty list removes the value.
procedure TEuoWatchViewTests.TestWatchesSavedPerScript;
const
  Path = 'C:\EuoWatchViewTests\no such folder\test.euo';
var
  Ed1, Ed2 : TSynEdit;
  R        : TRegistry;
begin
  Ed1:=NewEd(['halt']);
  Ed2:=NewEd(['halt']);
  FView.Refresh(Ed1,FExec);
  FView.AddWatch(Ed1,'%a');
  FView.AddWatch(Ed1,'#CharPosX');
  try
    SaveWatches(Ed1,Path);
    LoadWatches(Ed2,UpperCase(Path));
    AssertEquals('%a #CharPosX',
      Trim(WatchStateOf(Ed2).Watches[0]+' '+WatchStateOf(Ed2).Watches[1]));
    AssertEquals(2,WatchStateOf(Ed2).Watches.Count);

    FView.ClearWatches(Ed1);
    SaveWatches(Ed1,Path);
    R:=TRegistry.Create;
    try
      AssertTrue(R.OpenKeyReadOnly(WatchesKey));
      AssertFalse('an empty list leaves no value',R.ValueExists(Path));
    finally
      R.Free;
    end;

    LoadWatches(Ed2,Path);
    AssertEquals(0,WatchStateOf(Ed2).Watches.Count);
    SaveWatches(Ed2,'');   // an unsaved tab: nothing to do
  finally
    R:=TRegistry.Create;
    try
      if R.OpenKey(WatchesKey,False) then
        if R.ValueExists(Path) then R.DeleteValue(Path);
    finally
      R.Free;
    end;
  end;
end;

initialization
  RegisterTest(TEuoWatchViewTests);
end.
