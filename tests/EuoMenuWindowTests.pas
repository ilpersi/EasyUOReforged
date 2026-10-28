unit EuoMenuWindowTests;

{
  MENU window regression: TMenuObj holds repaints during a burst of MENU commands
  with WM_SETREDRAW, which works by clearing WS_VISIBLE. Held on the form itself
  that made the top-level window count as hidden for every burst, so its taskbar
  button blinked with each update of a script's status line and clicks went
  through it to the window below. The hold now sits on TEuoMenuForm.Surface (a
  child panel), and MENU SET no longer starts one. These show a real MENU form, so
  they need a window station; they report themselves ignored if it cannot be shown.

  Closing the window (its [X] or MENU HIDE) must set #MenuButton to CLOSED and only
  hide the form. The handler that does it moved from the form class to TMenuObj
  when the window classes went to EuoMenuCommon, so it is pinned here.

  MENU LIST SELECT under the 1.5 logic: an index outside the list must leave the
  selection as it was (LB_SETCURSEL), not stop the script with LCL's out-of-bounds
  error; 0 clears it. These need no shown window.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, fpcunit, testregistry, EuoMenu, EuoMenuSelect,
  EuoInterpreter;

type
  TEuoMenuWindowTests = class(TTestCase)
  private
    function  ListSelect(const Ind : String) : String;
  published
    procedure TestRepaintHoldLeavesWindowVisible;
    procedure TestSetDoesNotStartRepaintHold;
    procedure TestClosingTheWindowSetsClosed;
    procedure TestListSelectPastTheEndKeepsSelection;
    procedure TestListSelectZeroClears;
    procedure TestListSelectBelowZeroKeepsSelection;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuWindowTests.TestRepaintHoldLeavesWindowVisible;
var
  M : TMenuObj;
begin
  Application.Initialize;   // console runner never does; registers the window classes
  M := TMenuObj.Create;
  try
    M.TextCreate('status', 0, 0, 'one');
    M.Form.Show;
    Application.ProcessMessages;
    if not M.Form.Showing then
    begin
      Ignore('MENU form could not be shown in this session');
      Exit;
    end;

    M.BurstBegin;
    AssertTrue('menu window stays visible while repaints are held',
      IsWindowVisible(M.Form.Handle));
    AssertFalse('repaints are held on the controls'' panel',
      IsWindowVisible(M.Form.Surface.Handle));
    M.BurstFlush;
    AssertTrue('controls'' panel is back after the burst',
      IsWindowVisible(M.Form.Surface.Handle));
  finally
    M.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuWindowTests.TestSetDoesNotStartRepaintHold;
var
  Interp : TEuoInterpreter;
  Title  : String;
  Wnd    : HWND;
  Panel  : HWND;

  procedure Play(Lines : Integer);
  var
    Cnt : Integer;
  begin
    for Cnt := 1 to Lines do Interp.PlayLine;
  end;

begin
  Application.Initialize;
  Title := 'EuoMenuWindowTests' + IntToStr(GetCurrentProcessId);
  Interp := TEuoInterpreter.Create(0);
  try
    Interp.Clear;
    Interp.ScrList.Scr.Text :=
      'menu Window Title ' + Title + #13#10 +
      'menu Text status 0 0 one' + #13#10 +
      'menu Show' + #13#10 +
      'menu Set status two' + #13#10 +
      'menu Delete status' + #13#10 +
      'menu Set status three' + #13#10 +
      'menu Text status 0 0 four' + #13#10 +
      'menu Show' + #13#10 +
      'HALT';
    Interp.NextLine := 0;

    Play(3);
    Application.ProcessMessages;
    Wnd := FindWindow(nil, PChar(Title));
    if (Wnd = 0) or not IsWindowVisible(Wnd) then
    begin
      Ignore('MENU form could not be shown in this session');
      Exit;
    end;
    Panel := GetWindow(Wnd, GW_CHILD);
    AssertTrue('MENU controls sit on a child panel', Panel <> 0);

    Play(1);   // menu Set
    AssertTrue('SET on a shown window holds nothing', IsWindowVisible(Panel));

    Play(1);   // menu Delete
    AssertFalse('DELETE still starts a hold', IsWindowVisible(Panel));
    AssertTrue('the menu window itself stays visible', IsWindowVisible(Wnd));

    Play(2);   // menu Set, menu Text -- both join the running hold
    AssertFalse('SET and TEXT join the running hold', IsWindowVisible(Panel));

    Play(1);   // menu Show ends it
    AssertTrue('SHOW ends the hold', IsWindowVisible(Panel));
  finally
    Interp.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuWindowTests.TestClosingTheWindowSetsClosed;
var
  M : TMenuObj;
begin
  Application.Initialize;
  M := TMenuObj.Create;
  try
    M.Form.Show;
    Application.ProcessMessages;
    if not M.Form.Showing then
    begin
      Ignore('MENU form could not be shown in this session');
      Exit;
    end;

    M.MenuButton := 'N/A';
    SendMessage(M.Form.Handle, WM_CLOSE, 0, 0);   // the window's [X]
    Application.ProcessMessages;
    AssertEquals('[X] sets #MenuButton', 'CLOSED', M.MenuButton);
    AssertFalse('[X] hides the window', M.Form.Visible);

    M.Form.Show;
    Application.ProcessMessages;
    M.MenuButton := 'N/A';
    M.Form.Close;                                  // what MENU HIDE does
    AssertEquals('MENU HIDE sets #MenuButton', 'CLOSED', M.MenuButton);
    AssertFalse('MENU HIDE hides the window', M.Form.Visible);
    AssertTrue('the window survives being closed', M.Form.HandleAllocated);
  finally
    M.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Runs a 1.5 script that selects item 1 of a one-item list, then index Ind, and
// returns the selection MENU GET reads back.
function TEuoMenuWindowTests.ListSelect(const Ind : String) : String;
var
  Interp : TEuoInterpreter;
  Cnt    : Integer;
begin
  Application.Initialize;
  Interp := TEuoInterpreter.Create(0);
  try
    Interp.ScrList.Scr.Text :=
      'menu List Create l 0 0 100 100' + #13#10 +
      'menu List Add l one' + #13#10 +
      'menu List Select l 1' + #13#10 +
      'menu List Select l ' + Ind + #13#10 +
      'menu Get l' + #13#10 +
      'set %sel #menures' + #13#10 +
      'set %x reached' + #13#10 +
      'HALT';
    Interp.Clear;
    Interp.NextLine := 0;
    AssertTrue('the script runs under the 1.5 logic', Interp.MenuLogic = mlMenu15);

    Cnt := 0;
    while (Interp.ResInt <> RES_STOP) and (Interp.ResInt <> RES_CLOSE) and (Cnt < 100) do
    begin
      try
        Interp.PlayLine;
      except
        on E : Exception do
          Fail('menu List Select l ' + Ind + ' stopped the script: ' + E.Message);
      end;
      Inc(Cnt);
    end;
    AssertEquals('the script reaches its end', 'reached', Interp.GetVar('%x'));
    Result := Interp.GetVar('%sel');
  finally
    Interp.Free;
  end;
end;

procedure TEuoMenuWindowTests.TestListSelectPastTheEndKeepsSelection;
begin
  AssertEquals('index past the end is ignored', '1', ListSelect('5'));
end;

procedure TEuoMenuWindowTests.TestListSelectZeroClears;
begin
  AssertEquals('0 clears the selection', '0', ListSelect('0'));
end;

procedure TEuoMenuWindowTests.TestListSelectBelowZeroKeepsSelection;
begin
  AssertEquals('index below 0 is ignored', '1', ListSelect('-1'));
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoMenuWindowTests);
end.
