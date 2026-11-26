unit eulayout;

{
  Port addition: the editor window opens as it was left -- its size, place and maximized state,
  which panels are shown and how big each one is (main.pas, RestoreLayout / SaveLayout, in the
  registry next to the variable tree's open groups). The decisions that need no window are here,
  apart from main.pas so they can be tested: where a saved window goes on the screens there are
  now, the limits a saved panel size is kept within, and how the bottom panel's width shares are
  stored (the registry has no floating-point values).
}

{$mode delphi}{$H+}

interface

uses
  Types;

const
  // A width share of the bottom panel is stored as this many parts.
  SHARE_PARTS = 10000;

// Where a window saved at Saved opens: no smaller than MinW x MinH, no larger than Work (the
// work area of the screen it opens on), and moved inside Work. A window saved on a larger screen,
// or partly off one, opens whole on this one.
function EuoFitWindow(const Saved, Work : TRect; MinW, MinH : Integer) : TRect;

// Value kept between Lo and Hi; Lo wins when Hi < Lo (a window too small for the limits).
function EuoClampSize(Value, Lo, Hi : Integer) : Integer;

// A width share (0..1) as the integer the registry keeps, and back. Only a share strictly
// between 0 and 1 reads back: anything else is not a share the user dragged to.
function EuoShareToInt(Share : Double) : Integer;
function EuoShareFromInt(V : Integer; out Share : Double) : Boolean;

implementation

////////////////////////////////////////////////////////////////////////////////
function EuoFitWindow(const Saved, Work : TRect; MinW, MinH : Integer) : TRect;
var
  W, H, X, Y : Integer;
begin
  W:=Saved.Right-Saved.Left;
  H:=Saved.Bottom-Saved.Top;
  if W<MinW then W:=MinW;
  if H<MinH then H:=MinH;
  if W>Work.Right-Work.Left then W:=Work.Right-Work.Left;
  if H>Work.Bottom-Work.Top then H:=Work.Bottom-Work.Top;
  X:=Saved.Left;
  Y:=Saved.Top;
  if X+W>Work.Right then X:=Work.Right-W;
  if Y+H>Work.Bottom then Y:=Work.Bottom-H;
  if X<Work.Left then X:=Work.Left;
  if Y<Work.Top then Y:=Work.Top;
  Result:=Rect(X,Y,X+W,Y+H);
end;

////////////////////////////////////////////////////////////////////////////////
function EuoClampSize(Value, Lo, Hi : Integer) : Integer;
begin
  Result:=Value;
  if Result>Hi then Result:=Hi;
  if Result<Lo then Result:=Lo;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoShareToInt(Share : Double) : Integer;
begin
  Result:=Round(Share*SHARE_PARTS);
end;

////////////////////////////////////////////////////////////////////////////////
function EuoShareFromInt(V : Integer; out Share : Double) : Boolean;
begin
  Result:=(V>0) and (V<SHARE_PARTS);
  if Result then Share:=V/SHARE_PARTS
  else Share:=0;
end;

end.
