unit EuoLayoutTests;

{
  Tests for easyuo\eulayout.pas: how the editor window comes back as it was left. Where a saved
  window opens on the screens there are now, the limits a saved panel size is kept within, and
  the bottom panel's width shares as the registry stores them.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, eulayout;

type
  TEuoLayoutTests = class(TTestCase)
  private
    procedure CheckRect(const Msg : String; const Expected, Actual : TRect);
  published
    procedure TestWindowInsideTheWorkAreaStaysPut;
    procedure TestWindowPastTheRightAndBottomMovesIn;
    procedure TestWindowPastTheLeftAndTopMovesIn;
    procedure TestWindowBiggerThanTheWorkAreaShrinks;
    procedure TestWindowOnAWorkAreaNotAtTheOrigin;
    procedure TestWindowTooSmallGrowsToTheMinimum;
    procedure TestClampSize;
    procedure TestShareRoundTrip;
    procedure TestShareOutOfRangeIsRejected;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.CheckRect(const Msg : String; const Expected, Actual : TRect);
begin
  AssertEquals(Msg+' (left)',Expected.Left,Actual.Left);
  AssertEquals(Msg+' (top)',Expected.Top,Actual.Top);
  AssertEquals(Msg+' (right)',Expected.Right,Actual.Right);
  AssertEquals(Msg+' (bottom)',Expected.Bottom,Actual.Bottom);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestWindowInsideTheWorkAreaStaysPut;
begin
  CheckRect('a window that fits stays where it was',Rect(100,50,1010,444),
    EuoFitWindow(Rect(100,50,1010,444),Rect(0,0,1920,1040),400,300));
  CheckRect('exactly the work area',Rect(0,0,1920,1040),
    EuoFitWindow(Rect(0,0,1920,1040),Rect(0,0,1920,1040),400,300));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestWindowPastTheRightAndBottomMovesIn;
begin
  CheckRect('moved left and up, same size',Rect(1010,646,1920,1040),
    EuoFitWindow(Rect(1500,900,2410,1294),Rect(0,0,1920,1040),400,300));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestWindowPastTheLeftAndTopMovesIn;
begin
  CheckRect('moved right and down, same size',Rect(0,0,910,394),
    EuoFitWindow(Rect(-300,-20,610,374),Rect(0,0,1920,1040),400,300));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestWindowBiggerThanTheWorkAreaShrinks;
begin
  // saved on a 2560 x 1400 screen, opened on a 1366 x 728 one
  CheckRect('as big as the work area',Rect(0,0,1366,728),
    EuoFitWindow(Rect(200,100,2400,1300),Rect(0,0,1366,728),400,300));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestWindowOnAWorkAreaNotAtTheOrigin;
begin
  // a second screen left of the main one, with the taskbar on its top edge
  CheckRect('kept on the left screen',Rect(-1600,40,-690,434),
    EuoFitWindow(Rect(-1600,40,-690,434),Rect(-1920,40,0,1080),400,300));
  CheckRect('moved below the taskbar',Rect(-1000,40,-90,434),
    EuoFitWindow(Rect(-1000,0,-90,394),Rect(-1920,40,0,1080),400,300));
  CheckRect('moved in from the right edge of that screen',Rect(-910,500,0,894),
    EuoFitWindow(Rect(-500,500,410,894),Rect(-1920,40,0,1080),400,300));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestWindowTooSmallGrowsToTheMinimum;
begin
  CheckRect('grown to the minimum, from its top left',Rect(100,100,500,400),
    EuoFitWindow(Rect(100,100,150,120),Rect(0,0,1920,1040),400,300));
  CheckRect('a minimum larger than the work area gives the work area',Rect(0,0,320,240),
    EuoFitWindow(Rect(10,10,100,100),Rect(0,0,320,240),400,300));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestClampSize;
begin
  AssertEquals('inside',217,EuoClampSize(217,80,900));
  AssertEquals('below',80,EuoClampSize(0,80,900));
  AssertEquals('above',900,EuoClampSize(5000,80,900));
  AssertEquals('Lo wins when Hi < Lo',80,EuoClampSize(217,80,40));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestShareRoundTrip;
var
  Share : Double;
begin
  AssertEquals('a third',3333,EuoShareToInt(1/3));
  AssertTrue('a third reads back',EuoShareFromInt(EuoShareToInt(1/3),Share));
  AssertEquals('close to a third',1/3,Share,0.0001);
  AssertTrue(EuoShareFromInt(EuoShareToInt(0.25),Share));
  AssertEquals(0.25,Share,0.0);
  AssertTrue('the smallest share',EuoShareFromInt(1,Share));
  AssertTrue('the largest share',EuoShareFromInt(SHARE_PARTS-1,Share));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLayoutTests.TestShareOutOfRangeIsRejected;
var
  Share : Double;
begin
  AssertFalse('nothing',EuoShareFromInt(0,Share));
  AssertEquals('a rejected share is 0',0.0,Share,0.0);
  AssertFalse('everything',EuoShareFromInt(SHARE_PARTS,Share));
  AssertFalse('negative',EuoShareFromInt(-5,Share));
  AssertFalse('more than everything',EuoShareFromInt(25000,Share));
end;

initialization
  RegisterTest(TEuoLayoutTests);

end.
