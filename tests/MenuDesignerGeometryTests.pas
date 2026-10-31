unit MenuDesignerGeometryTests;

{
  The MENU Designer's canvas geometry (tools/EUOMenuDesigner/mdgeometry.pas): snapping to the
  grid and to siblings' and the parent's edges while moving and resizing, alignment and
  distribution.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, mdgeometry;

type
  TMenuDesignerGeometryTests = class(TTestCase)
  private
    S : TMdSnap;
    procedure AssertRect(const Msg : String; L, T, R, B : Integer; const Got : TRect);
  protected
    procedure SetUp; override;
  published
    procedure TestMoveSnapsToGrid;
    procedure TestMoveSnapsToASiblingEdge;
    procedure TestMoveSnapsCentres;
    procedure TestEdgesBeatTheGrid;
    procedure TestNothingNearWithoutGrid;
    procedure TestResizeSnapsOnlyTheDraggedEdge;
    procedure TestResizeKeepsAPixel;
    procedure TestSnapToParent;
    procedure TestAlignEdges;
    procedure TestAlignCentres;
    procedure TestCentreInParent;
    procedure TestSpread;
    procedure TestSameSize;
  end;

implementation

const
  Parent : TRect = (Left:0; Top:0; Right:300; Bottom:200);

procedure TMenuDesignerGeometryTests.SetUp;
begin
  S:=DefaultSnap;
end;

procedure TMenuDesignerGeometryTests.AssertRect(const Msg : String; L, T, R, B : Integer;
  const Got : TRect);
begin
  AssertEquals(Msg, Format('%d,%d,%d,%d',[L,T,R,B]),
    Format('%d,%d,%d,%d',[Got.Left,Got.Top,Got.Right,Got.Bottom]));
end;

procedure TMenuDesignerGeometryTests.TestMoveSnapsToGrid;
var
  G : TMdGuides;
begin
  S.ToEdges:=False;
  AssertRect('to the nearest grid point', 16, 8, 96, 33,
    SnapRect(Rect(19,10,99,35),[egLeft,egTop,egRight,egBottom],[],Parent,S,G));
  AssertEquals('no guide for the grid', 0, Length(G));
end;

procedure TMenuDesignerGeometryTests.TestMoveSnapsToASiblingEdge;
var
  G : TMdGuides;
begin
  S.ToGrid:=False;
  // the sibling's left is 50: our left at 52 jumps to it (y 130..150 is near nothing)
  AssertRect('left to left', 50, 130, 90, 150,
    SnapRect(Rect(52,130,92,150),[egLeft,egTop,egRight,egBottom],[Rect(50,10,130,35)],Parent,S,G));
  AssertEquals(1, Length(G));
  AssertTrue(G[0].Vertical);
  AssertEquals(50, G[0].Pos);
  // our left at 133 is 3 from the sibling's right (130)
  AssertRect('left to right', 130, 130, 170, 150,
    SnapRect(Rect(133,130,173,150),[egLeft,egTop,egRight,egBottom],[Rect(50,10,130,35)],Parent,S,G));
end;

procedure TMenuDesignerGeometryTests.TestMoveSnapsCentres;
var
  G : TMdGuides;
begin
  S.ToGrid:=False;
  // the sibling's centre is 90, ours 92
  AssertRect('centre to centre', 70, 100, 110, 120,
    SnapRect(Rect(72,100,112,120),[egLeft,egTop,egRight,egBottom],[Rect(50,10,130,35)],Parent,S,G));
end;

procedure TMenuDesignerGeometryTests.TestEdgesBeatTheGrid;
var
  G : TMdGuides;
begin
  AssertRect('an edge nearby wins over the grid', 51, 104, 91, 124,
    SnapRect(Rect(53,105,93,125),[egLeft,egTop,egRight,egBottom],[Rect(51,10,130,35)],Parent,S,G));
end;

procedure TMenuDesignerGeometryTests.TestNothingNearWithoutGrid;
var
  G : TMdGuides;
begin
  S.ToGrid:=False;
  AssertRect('stays where it is', 163, 105, 203, 125,
    SnapRect(Rect(163,105,203,125),[egLeft,egTop,egRight,egBottom],[Rect(10,10,30,30)],Parent,S,G));
  AssertEquals(0, Length(G));
end;

procedure TMenuDesignerGeometryTests.TestResizeSnapsOnlyTheDraggedEdge;
var
  G : TMdGuides;
begin
  S.ToGrid:=False;
  // dragging the right edge to 128: the sibling's right (130) is near
  AssertRect('the right edge only', 10, 100, 130, 120,
    SnapRect(Rect(10,100,128,120),[egRight],[Rect(50,10,130,35)],Parent,S,G));
  S.ToGrid:=True;
  S.ToEdges:=False;
  AssertRect('the bottom to the grid', 10, 100, 128, 120,
    SnapRect(Rect(10,100,128,118),[egBottom],[],Parent,S,G));
end;

procedure TMenuDesignerGeometryTests.TestResizeKeepsAPixel;
begin
  AssertRect('the left edge stops before the right', 49, 0, 50, 10, MovedRect(Rect(10,0,50,10),[egLeft],100,0));
  AssertRect('moving keeps the size', 15, 5, 55, 15, MovedRect(Rect(10,0,50,10),[egLeft,egTop,egRight,egBottom],5,5));
end;

procedure TMenuDesignerGeometryTests.TestSnapToParent;
var
  G : TMdGuides;
begin
  S.ToGrid:=False;
  AssertRect('to the parent''s right edge', 260, 50, 300, 70,
    SnapRect(Rect(257,50,297,70),[egLeft,egTop,egRight,egBottom],[],Parent,S,G));
  AssertRect('to the parent''s centre', 130, 50, 170, 70,
    SnapRect(Rect(132,50,172,70),[egLeft,egTop,egRight,egBottom],[],Parent,S,G));
end;

procedure TMenuDesignerGeometryTests.TestAlignEdges;
var
  R : array of TRect;
begin
  R:=[Rect(10,10,50,30), Rect(30,50,100,70), Rect(70,90,80,95)];
  AlignRects(R,aoLeft,Parent);
  AssertRect('the first does not move', 10,10,50,30, R[0]);
  AssertRect('', 10,50,80,70, R[1]);
  AssertRect('', 10,90,20,95, R[2]);
  R:=[Rect(10,10,50,30), Rect(30,50,100,70)];
  AlignRects(R,aoRight,Parent);
  AssertRect('', -20,50,50,70, R[1]);
  R:=[Rect(10,10,50,30), Rect(30,50,100,70)];
  AlignRects(R,aoBottom,Parent);
  AssertRect('', 30,10,100,30, R[1]);
end;

procedure TMenuDesignerGeometryTests.TestAlignCentres;
var
  R : array of TRect;
begin
  R:=[Rect(10,10,50,30), Rect(0,50,20,70)];
  AlignRects(R,aoCentreH,Parent);
  AssertRect('', 20,50,40,70, R[1]);
  R:=[Rect(10,10,50,30), Rect(0,50,20,60)];
  AlignRects(R,aoCentreV,Parent);
  AssertRect('', 0,15,20,25, R[1]);
end;

procedure TMenuDesignerGeometryTests.TestCentreInParent;
var
  R : array of TRect;
begin
  R:=[Rect(10,10,50,30), Rect(60,50,90,70)];
  AlignRects(R,aoParentH,Parent);
  // the group is 10..90, centre 50; the parent's 150: both move 100
  AssertRect('as a group', 110,10,150,30, R[0]);
  AssertRect('', 160,50,190,70, R[1]);
end;

procedure TMenuDesignerGeometryTests.TestSpread;
var
  R : array of TRect;
begin
  R:=[Rect(0,0,10,10), Rect(100,0,110,10), Rect(20,0,30,10)];
  AlignRects(R,aoSpreadH,Parent);
  AssertRect('the ends stay', 0,0,10,10, R[0]);
  AssertRect('', 100,0,110,10, R[1]);
  AssertRect('equal gaps of 40', 50,0,60,10, R[2]);
  R:=[Rect(0,0,10,10), Rect(100,0,110,10)];
  AlignRects(R,aoSpreadH,Parent);
  AssertRect('two do not spread', 100,0,110,10, R[1]);
end;

procedure TMenuDesignerGeometryTests.TestSameSize;
var
  R : array of TRect;
begin
  R:=[Rect(0,0,80,25), Rect(10,40,30,50)];
  AlignRects(R,aoSameWidth,Parent);
  AssertRect('', 10,40,90,50, R[1]);
  R:=[Rect(0,0,80,25), Rect(10,40,30,50)];
  AlignRects(R,aoSameSize,Parent);
  AssertRect('', 10,40,90,65, R[1]);
end;

initialization
  RegisterTest(TMenuDesignerGeometryTests);
end.
