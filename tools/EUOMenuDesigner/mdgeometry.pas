unit mdgeometry;

{
  Port addition: the MENU Designer's canvas geometry (docs/menu-designer.md, section 9.2), as
  plain rectangle arithmetic so the tests reach it without a window. Rectangles are in their
  parent's client coordinates.

  Snapping: while a component moves or one of its edges is dragged, an edge (or the centre)
  within Threshold pixels of a sibling's edge or centre, or of the parent's, jumps to it and a
  guide line marks it; otherwise the edge goes to the grid. Alignment and distribution act on
  a selection, relative to its first rectangle.
}

{$mode delphi}{$H+}

interface
uses
  Types, Math;

type
  TMdEdge = (egLeft, egTop, egRight, egBottom);
  TMdEdges = set of TMdEdge;

  TMdSnap = record
    Grid      : Integer;   // grid step in pixels
    ToGrid    : Boolean;
    ToEdges   : Boolean;   // siblings' and the parent's edges and centres
    Threshold : Integer;
  end;

  TMdGuide = record
    Vertical : Boolean;    // a line at x = Pos, else at y = Pos
    Pos      : Integer;
  end;
  TMdGuides = array of TMdGuide;

  TMdAlignOp = (aoLeft, aoRight, aoTop, aoBottom, aoCentreH, aoCentreV, aoParentH, aoParentV,
                aoSpreadH, aoSpreadV, aoSameWidth, aoSameHeight, aoSameSize);

function  DefaultSnap : TMdSnap;
function  MovedRect(const R : TRect; Edges : TMdEdges; DX, DY : Integer) : TRect;
function  SnapRect(const R : TRect; Edges : TMdEdges; const Others : array of TRect;
            const Parent : TRect; const S : TMdSnap; out Guides : TMdGuides) : TRect;
procedure AlignRects(var Rects : array of TRect; Op : TMdAlignOp; const Parent : TRect);

implementation

function DefaultSnap : TMdSnap;
begin
  Result.Grid:=8;
  Result.ToGrid:=True;
  Result.ToEdges:=True;
  Result.Threshold:=4;
end;

// R with the given edges moved by DX/DY: all four for a move, the dragged ones for a resize.
// A size never goes below 1 pixel.
function MovedRect(const R : TRect; Edges : TMdEdges; DX, DY : Integer) : TRect;
begin
  Result:=R;
  if egLeft in Edges then Inc(Result.Left,DX);
  if egRight in Edges then Inc(Result.Right,DX);
  if egTop in Edges then Inc(Result.Top,DY);
  if egBottom in Edges then Inc(Result.Bottom,DY);
  if (Edges*[egLeft,egRight]=[egLeft]) and (Result.Left>Result.Right-1) then Result.Left:=Result.Right-1;
  if (Edges*[egLeft,egRight]=[egRight]) and (Result.Right<Result.Left+1) then Result.Right:=Result.Left+1;
  if (Edges*[egTop,egBottom]=[egTop]) and (Result.Top>Result.Bottom-1) then Result.Top:=Result.Bottom-1;
  if (Edges*[egTop,egBottom]=[egBottom]) and (Result.Bottom<Result.Top+1) then Result.Bottom:=Result.Top+1;
end;

function GridOf(V, Grid : Integer) : Integer;
begin
  if Grid<=1 then Exit(V);
  Result:=Round(V/Grid)*Grid;
end;

procedure AddGuide(var G : TMdGuides; Vertical : Boolean; Pos : Integer);
begin
  SetLength(G,Length(G)+1);
  G[High(G)].Vertical:=Vertical;
  G[High(G)].Pos:=Pos;
end;

// One axis: the values of the moving rectangle that can snap (its edges, its centre when the
// whole rectangle moves) against the targets; the smallest jump within the threshold wins.
// Returns the jump, or the grid's when nothing is near.
function SnapAxis(const Cands : array of Integer; const Targets : array of Integer;
  const S : TMdSnap; GridCand : Integer; out Hit : Integer; out Found : Boolean) : Integer;
var
  C, T  : Integer;
  Best  : Integer;
begin
  Found:=False;
  Best:=MaxInt;
  Hit:=0;
  Result:=0;
  if S.ToEdges then
    for C:=Low(Cands) to High(Cands) do
      for T:=Low(Targets) to High(Targets) do
        if (Abs(Targets[T]-Cands[C])<=S.Threshold) and (Abs(Targets[T]-Cands[C])<Best) then
        begin
          Best:=Abs(Targets[T]-Cands[C]);
          Result:=Targets[T]-Cands[C];
          Hit:=Targets[T];
          Found:=True;
        end;
  if not Found and S.ToGrid then Result:=GridOf(GridCand,S.Grid)-GridCand;
end;

function SnapRect(const R : TRect; Edges : TMdEdges; const Others : array of TRect;
  const Parent : TRect; const S : TMdSnap; out Guides : TMdGuides) : TRect;
var
  TX, TY : array of Integer;
  Cnt    : Integer;
  D      : Integer;
  Hit    : Integer;
  Found  : Boolean;
  Move   : Boolean;

  procedure Targets(const O : TRect);
  begin
    TX:=TX+[O.Left,O.Right,(O.Left+O.Right) div 2];
    TY:=TY+[O.Top,O.Bottom,(O.Top+O.Bottom) div 2];
  end;

begin
  Result:=R;
  Guides:=nil;
  TX:=nil;
  TY:=nil;
  Targets(Parent);
  for Cnt:=Low(Others) to High(Others) do
    Targets(Others[Cnt]);
  Move:=Edges=[egLeft,egTop,egRight,egBottom];

  if Move then
  begin
    D:=SnapAxis([R.Left,R.Right,(R.Left+R.Right) div 2],TX,S,R.Left,Hit,Found);
    OffsetRect(Result,D,0);
    if Found then AddGuide(Guides,True,Hit);
    D:=SnapAxis([R.Top,R.Bottom,(R.Top+R.Bottom) div 2],TY,S,R.Top,Hit,Found);
    OffsetRect(Result,0,D);
    if Found then AddGuide(Guides,False,Hit);
    Exit;
  end;

  if egLeft in Edges then
  begin
    D:=SnapAxis([R.Left],TX,S,R.Left,Hit,Found);
    if R.Left+D<R.Right then Inc(Result.Left,D);
    if Found then AddGuide(Guides,True,Hit);
  end
  else if egRight in Edges then
  begin
    D:=SnapAxis([R.Right],TX,S,R.Right,Hit,Found);
    if R.Right+D>R.Left then Inc(Result.Right,D);
    if Found then AddGuide(Guides,True,Hit);
  end;
  if egTop in Edges then
  begin
    D:=SnapAxis([R.Top],TY,S,R.Top,Hit,Found);
    if R.Top+D<R.Bottom then Inc(Result.Top,D);
    if Found then AddGuide(Guides,False,Hit);
  end
  else if egBottom in Edges then
  begin
    D:=SnapAxis([R.Bottom],TY,S,R.Bottom,Hit,Found);
    if R.Bottom+D>R.Top then Inc(Result.Bottom,D);
    if Found then AddGuide(Guides,False,Hit);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Rects[0] is the one the others go by. Centring in the parent and spreading move the
// selection as a group.
procedure AlignRects(var Rects : array of TRect; Op : TMdAlignOp; const Parent : TRect);
var
  Key   : TRect;
  Cnt   : Integer;
  Box   : TRect;
  Order : array of Integer;
  I, J  : Integer;
  T     : Integer;
  Total : Integer;
  Gap   : Double;
  Pos   : Double;
begin
  if Length(Rects)=0 then Exit;
  Key:=Rects[0];
  Box:=Rects[0];
  for Cnt:=1 to High(Rects) do
    UnionRect(Box,Box,Rects[Cnt]);

  case Op of
    aoLeft:   for Cnt:=0 to High(Rects) do OffsetRect(Rects[Cnt],Key.Left-Rects[Cnt].Left,0);
    aoRight:  for Cnt:=0 to High(Rects) do OffsetRect(Rects[Cnt],Key.Right-Rects[Cnt].Right,0);
    aoTop:    for Cnt:=0 to High(Rects) do OffsetRect(Rects[Cnt],0,Key.Top-Rects[Cnt].Top);
    aoBottom: for Cnt:=0 to High(Rects) do OffsetRect(Rects[Cnt],0,Key.Bottom-Rects[Cnt].Bottom);
    aoCentreH:
      for Cnt:=0 to High(Rects) do
        OffsetRect(Rects[Cnt],(Key.Left+Key.Right) div 2-(Rects[Cnt].Left+Rects[Cnt].Right) div 2,0);
    aoCentreV:
      for Cnt:=0 to High(Rects) do
        OffsetRect(Rects[Cnt],0,(Key.Top+Key.Bottom) div 2-(Rects[Cnt].Top+Rects[Cnt].Bottom) div 2);
    aoParentH:
      for Cnt:=0 to High(Rects) do
        OffsetRect(Rects[Cnt],(Parent.Left+Parent.Right-Box.Left-Box.Right) div 2,0);
    aoParentV:
      for Cnt:=0 to High(Rects) do
        OffsetRect(Rects[Cnt],0,(Parent.Top+Parent.Bottom-Box.Top-Box.Bottom) div 2);
    aoSpreadH, aoSpreadV:
      begin
        if Length(Rects)<3 then Exit;
        SetLength(Order,Length(Rects));
        for Cnt:=0 to High(Rects) do Order[Cnt]:=Cnt;
        for I:=0 to High(Order)-1 do
          for J:=I+1 to High(Order) do
            if ((Op=aoSpreadH) and (Rects[Order[J]].Left<Rects[Order[I]].Left)) or
               ((Op=aoSpreadV) and (Rects[Order[J]].Top<Rects[Order[I]].Top)) then
            begin
              T:=Order[I];
              Order[I]:=Order[J];
              Order[J]:=T;
            end;
        Total:=0;
        for Cnt:=0 to High(Rects) do
          if Op=aoSpreadH then Inc(Total,Rects[Cnt].Right-Rects[Cnt].Left)
          else Inc(Total,Rects[Cnt].Bottom-Rects[Cnt].Top);
        if Op=aoSpreadH then
        begin
          Gap:=(Box.Right-Box.Left-Total)/(Length(Rects)-1);
          Pos:=Box.Left;
          for Cnt:=0 to High(Order) do
          begin
            OffsetRect(Rects[Order[Cnt]],Round(Pos)-Rects[Order[Cnt]].Left,0);
            Pos:=Pos+(Rects[Order[Cnt]].Right-Rects[Order[Cnt]].Left)+Gap;
          end;
        end
        else
        begin
          Gap:=(Box.Bottom-Box.Top-Total)/(Length(Rects)-1);
          Pos:=Box.Top;
          for Cnt:=0 to High(Order) do
          begin
            OffsetRect(Rects[Order[Cnt]],0,Round(Pos)-Rects[Order[Cnt]].Top);
            Pos:=Pos+(Rects[Order[Cnt]].Bottom-Rects[Order[Cnt]].Top)+Gap;
          end;
        end;
      end;
    aoSameWidth:
      for Cnt:=0 to High(Rects) do Rects[Cnt].Right:=Rects[Cnt].Left+(Key.Right-Key.Left);
    aoSameHeight:
      for Cnt:=0 to High(Rects) do Rects[Cnt].Bottom:=Rects[Cnt].Top+(Key.Bottom-Key.Top);
    aoSameSize:
      for Cnt:=0 to High(Rects) do
      begin
        Rects[Cnt].Right:=Rects[Cnt].Left+(Key.Right-Key.Left);
        Rects[Cnt].Bottom:=Rects[Cnt].Top+(Key.Bottom-Key.Top);
      end;
  end;
end;

end.
