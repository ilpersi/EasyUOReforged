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

  A button's new caption must be drawn: TEuoMenuButton is self-painted, and LCL does not
  repaint a TCustomControl when its text changes, so MENU SET left the old caption on
  screen. Checked by the button having an update region right after the change.

  MENU LIST SELECT under the 1.5 logic: an index outside the list must leave the
  selection as it was (LB_SETCURSEL), not stop the script with LCL's out-of-bounds
  error; 0 clears it. These need no shown window.

  The memo's "wordwrap" and "scrollbars" (MENU 1.6, Reforged additions), in the real window:
  a wrapping Windows edit control counts its visual lines (EM_GETLINECOUNT, and LCL's Lines
  with it), so what MENU GET and GETPROP TEXT read must stay the text the script wrote, with
  no "$" for a line the window broke, also across the window rebuilds both properties cause.
  The memo's window is made with HandleNeeded; its form stays hidden.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, Controls, StdCtrls, fpcunit, testregistry, EuoMenu,
  EuoMenuSelect, EuoMenuCommon, EuoInterpreter, EuoMenu16, mdscript;

type
  TEuoMenuWindowTests = class(TTestCase)
  private
    function  ListSelect(const Ind : String) : String;
    function  Res16(M : TMenu16; const Line : String) : String;
    function  Memo16(M : TMenu16; const Name : String) : TMemo;
    function  Bars(Memo : TMemo) : String;
  published
    procedure TestRepaintHoldLeavesWindowVisible;
    procedure TestSetDoesNotStartRepaintHold;
    procedure TestClosingTheWindowSetsClosed;
    procedure TestSetButtonCaptionRepaints;
    procedure TestListSelectPastTheEndKeepsSelection;
    procedure TestListSelectZeroClears;
    procedure TestListSelectBelowZeroKeepsSelection;
    procedure TestMemoWordWrapKeepsTheTypedText;
    procedure TestMemoScrollBars;
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

procedure TEuoMenuWindowTests.TestSetButtonCaptionRepaints;
var
  M   : TMenuObj;
  Btn : TEuoMenuButton;
  Cnt : Integer;
begin
  Application.Initialize;
  M := TMenuObj.Create;
  try
    M.ButtonCreate('face', 10, 10, 40, 40, 'one');
    M.Form.Show;
    Application.ProcessMessages;
    if not M.Form.Showing then
    begin
      Ignore('MENU form could not be shown in this session');
      Exit;
    end;

    Btn := nil;
    for Cnt := 0 to M.Form.Surface.ControlCount-1 do
      if M.Form.Surface.Controls[Cnt] is TEuoMenuButton then
        Btn := TEuoMenuButton(M.Form.Surface.Controls[Cnt]);
    AssertNotNull('the button exists', Btn);

    Btn.Update;   // paint now, so the update region starts empty
    AssertFalse('nothing to paint before the change', GetUpdateRect(Btn.Handle, nil, False));
    M._Set('face', 'two');
    AssertEquals('caption changed', 'two', Btn.Caption);
    AssertTrue('the new caption is queued for painting', GetUpdateRect(Btn.Handle, nil, False));
  finally
    M.Free;
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
// MENU 1.6: runs Line and returns #MenuRes, '<unchanged>' when the line left it alone.
function TEuoMenuWindowTests.Res16(M : TMenu16; const Line : String) : String;
begin
  M.MenuRes := '<unchanged>';
  RunMenuLine(M, Line);
  Result := M.MenuRes;
end;

// The memo registered as Name, with its window made (a hidden form makes none by itself).
function TEuoMenuWindowTests.Memo16(M : TMenu16; const Name : String) : TMemo;
var
  Cnt : Integer;
begin
  Result := nil;
  for Cnt := 0 to M.RegistryCount-1 do
    if (M.RegistryName(Cnt) = Name) and (M.RegistryCtrl(Cnt) is TMemo) then
      Result := TMemo(M.RegistryCtrl(Cnt));
  AssertNotNull(Name + ' is a memo', Result);
  Result.HandleNeeded;
end;

function TEuoMenuWindowTests.Bars(Memo : TMemo) : String;
var
  Style : LongInt;
begin
  Style := GetWindowLong(Memo.Handle, GWL_STYLE);
  Result := '';
  if (Style and WS_HSCROLL) <> 0 then Result := Result + 'H';
  if (Style and WS_VSCROLL) <> 0 then Result := Result + 'V';
  if Result = '' then Result := 'none';
end;

// "wordwrap" wraps the memo's lines in the real window; what the script reads back is the text
// it wrote, with no "$" for a line the window broke, also after the window is rebuilt (each
// wordwrap and scrollbars change) or moved into a panel.
procedure TEuoMenuWindowTests.TestMemoWordWrapKeepsTheTypedText;
const
  Typed = 'This line is much too long for a memo a hundred pixels wide so it wraps$second';
var
  M    : TMenu16;
  Memo : TMemo;
begin
  Application.Initialize;
  M := TMenu16.Create;
  try
    M.ScriptStart;
    RunMenuLine(M, 'menu memo m 10 10 100 120 ' + Typed);
    RunMenuLine(M, 'menu panel p 120 10 150 150');
    Memo := Memo16(M, 'm');
    AssertEquals('no wrap at first', '0', Res16(M, 'menu getprop m wordwrap'));
    AssertEquals('two lines unwrapped', 2, SendMessage(Memo.Handle, EM_GETLINECOUNT, 0, 0));

    RunMenuLine(M, 'menu setprop m wordwrap #true');
    AssertEquals('wrapping', '-1', Res16(M, 'menu getprop m wordwrap'));
    Memo := Memo16(M, 'm');
    AssertTrue('the window wraps the long line',
      SendMessage(Memo.Handle, EM_GETLINECOUNT, 0, 0) > 3);
    AssertEquals('no horizontal bar while wrapping', 'V', Bars(Memo));
    AssertEquals('menu get: only the $ written', Typed, Res16(M, 'menu get m'));
    AssertEquals('getprop text: only the $ written', Typed, Res16(M, 'menu getprop m text'));

    RunMenuLine(M, 'menu set m one$' + Typed);
    AssertEquals('after menu set', 'one$' + Typed, Res16(M, 'menu get m'));
    RunMenuLine(M, 'menu setprop m text ' + Typed);
    AssertEquals('after setprop text', Typed, Res16(M, 'menu getprop m text'));

    RunMenuLine(M, 'menu setprop m scrollbars 2');
    AssertEquals('rebuilt for scrollbars, still wrapping', Typed, Res16(M, 'menu get m'));
    Memo := Memo16(M, 'm');
    AssertEquals('and once its window is back', Typed, Res16(M, 'menu get m'));

    RunMenuLine(M, 'menu setprop m parent p');
    AssertEquals('moved into the panel', 'p', Res16(M, 'menu getprop m parent'));
    Memo := Memo16(M, 'm');
    AssertEquals('moved, still the text written', Typed, Res16(M, 'menu get m'));

    RunMenuLine(M, 'menu setprop m wordwrap #false');
    AssertEquals('unwrapped: the text written', Typed, Res16(M, 'menu get m'));
    Memo := Memo16(M, 'm');
    AssertEquals('unwrapped: two lines again', 2, SendMessage(Memo.Handle, EM_GETLINECOUNT, 0, 0));
    AssertEquals('and again with its window back', Typed, Res16(M, 'menu get m'));
  finally
    M.Free;
  end;
end;

// "scrollbars" 0 none, 1 horizontal, 2 vertical, 3 both (as created); other numbers ignored.
// Neither property exists on an edit.
procedure TEuoMenuWindowTests.TestMemoScrollBars;
var
  M    : TMenu16;
  Memo : TMemo;
begin
  Application.Initialize;
  M := TMenu16.Create;
  try
    M.ScriptStart;
    RunMenuLine(M, 'menu memo m 10 10 100 120 a$b');
    Memo := Memo16(M, 'm');
    AssertEquals('both as created', '3', Res16(M, 'menu getprop m scrollbars'));
    AssertEquals('both bars in the window', 'HV', Bars(Memo));

    RunMenuLine(M, 'menu setprop m scrollbars 0');
    AssertEquals('0', Res16(M, 'menu getprop m scrollbars'));
    AssertEquals('none', Bars(Memo16(M, 'm')));
    RunMenuLine(M, 'menu setprop m scrollbars 1');
    AssertEquals('1', Res16(M, 'menu getprop m scrollbars'));
    AssertEquals('H', Bars(Memo16(M, 'm')));
    RunMenuLine(M, 'menu setprop m scrollbars 2');
    AssertEquals('2', Res16(M, 'menu getprop m scrollbars'));
    AssertEquals('V', Bars(Memo16(M, 'm')));
    RunMenuLine(M, 'menu setprop m scrollbars 3');
    AssertEquals('3', Res16(M, 'menu getprop m scrollbars'));
    AssertEquals('HV', Bars(Memo16(M, 'm')));
    RunMenuLine(M, 'menu setprop m scrollbars 4');
    AssertEquals('4 is ignored', '3', Res16(M, 'menu getprop m scrollbars'));
    RunMenuLine(M, 'menu setprop m scrollbars -1');
    AssertEquals('-1 is ignored', '3', Res16(M, 'menu getprop m scrollbars'));
    RunMenuLine(M, 'menu setprop m wordwrap #true');
    AssertEquals('wrapping: still reads 3', '3', Res16(M, 'menu getprop m scrollbars'));
    AssertEquals('wrapping: the vertical bar only', 'V', Bars(Memo16(M, 'm')));
    AssertEquals('the text', 'a$b', Res16(M, 'menu get m'));

    RunMenuLine(M, 'menu edit e 10 140 100 hi');
    AssertEquals('an edit does not wrap', '<unchanged>', Res16(M, 'menu getprop e wordwrap'));
    AssertEquals('an edit has no scrollbars', '<unchanged>', Res16(M, 'menu getprop e scrollbars'));
    RunMenuLine(M, 'menu setprop e wordwrap #true');
    AssertEquals('setprop on an edit changes nothing', 'hi', Res16(M, 'menu get e'));
  finally
    M.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoMenuWindowTests);
end.
