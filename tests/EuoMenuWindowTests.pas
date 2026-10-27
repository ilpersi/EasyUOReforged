unit EuoMenuWindowTests;

{
  MENU window regression: TMenuObj holds repaints during a burst of MENU commands
  with WM_SETREDRAW, which works by clearing WS_VISIBLE. Held on the form itself
  that made the top-level window count as hidden for every burst, so its taskbar
  button blinked with each update of a script's status line and clicks went
  through it to the window below. The hold now sits on TEuoMenuForm.Surface (a
  child panel), and MENU SET no longer starts one. These show a real MENU form, so
  they need a window station; they report themselves ignored if it cannot be shown.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, fpcunit, testregistry, EuoMenu, EuoInterpreter;

type
  TEuoMenuWindowTests = class(TTestCase)
  published
    procedure TestRepaintHoldLeavesWindowVisible;
    procedure TestSetDoesNotStartRepaintHold;
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
initialization
  RegisterTest(TEuoMenuWindowTests);
end.
