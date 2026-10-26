unit walkrules;

{
  New addition (not in the original EasyUO): the step rules of the pathfinder -- whether the
  character can step from one cell to the next, and at what height it lands. See
  docs\pathfinding.md for the whole design.

  Ported from ClassicUO (BSD-2-Clause, like this project; see NOTICE):
  - Pathfinder.cs: the PATH_OBJECT flags CreateItemList gives land and statics, CalculateMinMaxZ,
    CalculateNewZ, and CanWalk's diagonal rule (a diagonal step also needs both straight steps
    beside it).
  - Land.cs: CalculateCurrentAverageZ, for leaving a sloped land tile.
  - Constants.cs: the block height.
  These are the rules the client itself uses to decide whether to send a step, so a step they
  allow is one the client would send. The port is line for line; C#'s ">> 1" on a signed value
  is an arithmetic shift, which is SarLongint here (Pascal's shr is not).

  Only the normal walking state is ported: no dead/GM, sea horse or flying rules. ClassicUO's
  rules for mobiles, items and multis are not ported either; the live overlay of the walker
  (phase 2) brings those.

  What stands on a cell comes from a TWalkSource: the world model read from the client files
  (walkmap.pas) or, in the tests, a synthetic grid. A source hands out TPathObj records already
  in ClassicUO's PathObject form, made by LandPathObj/StaticPathObj from tiledata flags, so the
  rules themselves never read tiledata.

  CalcMinMaxZ/CalcNewZ take prebuilt lists so that the planner can read the cell it stands on
  once for all eight directions; CalculateNewZ/CanStep/StandZ are the one-call forms.
}

{$mode delphi}{$H+}

interface

const
  // ClassicUO's PATH_OBJECT_FLAGS.
  POF_IMPASSABLE_OR_SURFACE = $01;
  POF_SURFACE               = $02;
  POF_BRIDGE                = $04;

  // tiledata flag bits the rules look at: the low 32 bits, the same in the old and the new
  // tiledata format (names as #TileFlags shows them).
  TDF_IMPASSABLE = $00000040;
  TDF_WET        = $00000080;
  TDF_SURFACE    = $00000200;
  TDF_BRIDGE     = $00000400;

  BLOCK_HEIGHT     = 16;    // ClassicUO Constants.DEFAULT_BLOCK_HEIGHT: head room a character needs
  MAX_CELL_OBJECTS = 256;   // objects kept per cell; a real cell holds a few dozen at most

  // Direction offsets, numbered as #CharDir: 0 = north, clockwise to 7 = north-west.
  DirX : array[0..7] of Integer = (0, 1, 1, 1, 0, -1, -1, -1);
  DirY : array[0..7] of Integer = (-1, -1, 0, 1, 1, 1, 0, -1);

type
  // One thing standing on a cell, as ClassicUO's PathObject: land or a static.
  TPathObj = record
    Flags     : Byte;                     // POF_* bits
    IsLand    : Boolean;
    Stretched : Boolean;                  // land only: textured and not flat (ClassicUO Land.IsStretched)
    Z         : SmallInt;                 // bottom; for land its lowest corner
    AverageZ  : SmallInt;                 // where a character stands on it
    Height    : SmallInt;
    CornerZ   : array[0..3] of ShortInt;  // land only: top, right, bottom, left corner heights
  end;

  TPathObjList = record
    Count : Integer;
    Items : array[0..MAX_CELL_OBJECTS-1] of TPathObj;
  end;

  // Answers "what stands on cell X,Y" for one facet.
  TWalkSource = class
  public
    // Fills List with the objects on the cell, in any order. False when the cell is outside
    // the map; a cell inside it may still give an empty list (nothing to stand on).
    function GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean; virtual; abstract;
  end;

// Appends Obj, keeping one slot free for CalcNewZ's sentinel. False when the list is full.
function  AddPathObj(var List : TPathObjList; const Obj : TPathObj) : Boolean;

// ClassicUO CreateItemList's land case for a flat land tile of Graphic at height Z with the
// tiledata flags TileFlags. False for the void tiles, which give no object at all. A sloped tile
// needs Z, AverageZ, Height, CornerZ and Stretched filled in afterwards (walkmap does).
function  LandPathObj(Graphic : Word; TileFlags : Cardinal; Z : Integer; out Obj : TPathObj) : Boolean;

// ClassicUO CreateItemList's static/item case (normal walking state) for an object of tiledata
// flags TileFlags and height Height standing at Z. False when it neither blocks nor can be
// stood on, so the rules never need to see it.
function  StaticPathObj(TileFlags : Cardinal; Height, Z : Integer; out Obj : TPathObj) : Boolean;

// ClassicUO CalculateMinMaxZ, from the list of the cell being left: the lowest and highest
// height the character may land at when moving in Direction from CurrentZ.
procedure CalcMinMaxZ(const SrcList : TPathObjList; CurrentZ, Direction : Integer;
  out MinZ, MaxZ : Integer);

// ClassicUO CalculateNewZ's search, on the list of the cell being entered (sorted in place, a
// sentinel appended). Z is the height stepped from in, the height landed at out.
function  CalcNewZ(var DestList : TPathObjList; MinZ, MaxZ : Integer; var Z : Integer) : Boolean;

// ClassicUO CalculateNewZ: can the character standing at height Z next to cell X,Y step onto it
// in Direction? Z becomes the landing height. False also outside the map.
function  CalculateNewZ(Src : TWalkSource; X, Y : Integer; var Z : Integer;
  Direction : Integer) : Boolean;

// ClassicUO CanWalk for one direction, without its fall-back to a straight step when a diagonal
// is blocked: the step from X,Y,Z in Direction, landing at NewZ.
function  CanStep(Src : TWalkSource; X, Y, Z, Direction : Integer; out NewZ : Integer) : Boolean;

// Can a character stand on cell X,Y at all, with no limit on climbing? Z is the wanted height
// in; out, the surface with head room nearest to it.
function  StandZ(Src : TWalkSource; X, Y : Integer; var Z : Integer) : Boolean;

implementation

function AddPathObj(var List : TPathObjList; const Obj : TPathObj) : Boolean;
begin
  Result := List.Count < MAX_CELL_OBJECTS-1;
  if not Result then Exit;
  List.Items[List.Count] := Obj;
  Inc(List.Count);
end;

function LandPathObj(Graphic : Word; TileFlags : Cardinal; Z : Integer; out Obj : TPathObj) : Boolean;
begin
  FillChar(Obj, SizeOf(Obj), 0);
  // ClassicUO adds no land object for the void tiles: 2, $1AE..$1B5 and $1DB.
  Result := not ((Graphic = 2) or ((Graphic >= $1AE) and (Graphic <= $1B5)) or (Graphic = $1DB));
  if not Result then Exit;
  Obj.Flags := POF_IMPASSABLE_OR_SURFACE;
  if (TileFlags and TDF_IMPASSABLE) = 0 then
    Obj.Flags := Obj.Flags or POF_SURFACE or POF_BRIDGE;
  Obj.IsLand := True;
  Obj.Z := Z;
  Obj.AverageZ := Z;
  Obj.CornerZ[0] := Z;
  Obj.CornerZ[1] := Z;
  Obj.CornerZ[2] := Z;
  Obj.CornerZ[3] := Z;
end;

function StaticPathObj(TileFlags : Cardinal; Height, Z : Integer; out Obj : TPathObj) : Boolean;
var
  Avg : Integer;
begin
  FillChar(Obj, SizeOf(Obj), 0);
  if (TileFlags and (TDF_IMPASSABLE or TDF_SURFACE)) <> 0 then
    Obj.Flags := POF_IMPASSABLE_OR_SURFACE;
  if (TileFlags and TDF_IMPASSABLE) = 0 then
  begin
    if (TileFlags and TDF_SURFACE) <> 0 then Obj.Flags := Obj.Flags or POF_SURFACE;
    if (TileFlags and TDF_BRIDGE) <> 0 then Obj.Flags := Obj.Flags or POF_BRIDGE;
  end;
  Result := Obj.Flags <> 0;
  if not Result then Exit;

  Avg := Height;
  if (TileFlags and TDF_BRIDGE) <> 0 then Avg := Avg div 2;   // stairs: stand half way up
  Obj.Z := Z;
  Obj.AverageZ := Z + Avg;
  Obj.Height := Height;
end;

// ClassicUO Land.GetDirectionZ: the corner heights by direction pair.
function DirectionZ(const Land : TPathObj; Direction : Integer) : Integer;
begin
  case Direction of
    1: Result := Land.CornerZ[1];
    2: Result := Land.CornerZ[2];
    3: Result := Land.CornerZ[3];
  else
    Result := Land.CornerZ[0];
  end;
end;

// ClassicUO Land.CalculateCurrentAverageZ.
function CurrentAverageZ(const Land : TPathObj; Direction : Integer) : Integer;
begin
  Result := DirectionZ(Land, ((Direction shr 1) + 1) and 3);
  if (Direction and 1) <> 0 then Exit;
  Result := SarLongint(Result + DirectionZ(Land, Direction shr 1), 1);
end;

// No "with" here or in CalcNewZ: TPathObj has a field Z, which would hide the routines' own Z.
procedure CalcMinMaxZ(const SrcList : TPathObjList; CurrentZ, Direction : Integer;
  out MinZ, MaxZ : Integer);
var
  i, AvgZ, ObjZ, Top : Integer;
begin
  MinZ := -128;
  MaxZ := CurrentZ;
  Direction := Direction and 7;
  if SrcList.Count = 0 then Exit;   // ClassicUO returns before the +2 below

  for i := 0 to SrcList.Count-1 do
  begin
    AvgZ := SrcList.Items[i].AverageZ;
    if (AvgZ <= CurrentZ) and SrcList.Items[i].IsLand and SrcList.Items[i].Stretched then
    begin
      AvgZ := CurrentAverageZ(SrcList.Items[i], Direction);
      if MinZ < AvgZ then MinZ := AvgZ;
      if MaxZ < AvgZ then MaxZ := AvgZ;
    end
    else
    begin
      if ((SrcList.Items[i].Flags and POF_IMPASSABLE_OR_SURFACE) <> 0) and (AvgZ <= CurrentZ)
        and (MinZ < AvgZ) then
        MinZ := AvgZ;

      if ((SrcList.Items[i].Flags and POF_BRIDGE) <> 0) and (CurrentZ = AvgZ) then
      begin
        ObjZ := SrcList.Items[i].Z;
        Top := ObjZ + SrcList.Items[i].Height;
        if MaxZ < Top then MaxZ := Top;
        if MinZ > ObjZ then MinZ := ObjZ;
      end;
    end;
  end;

  Inc(MaxZ, 2);
end;

// ClassicUO PathObject.CompareTo: by Z, then by height. Insertion sort, stable; lists are short.
procedure SortObjects(var List : TPathObjList);
var
  i, j : Integer;
  Tmp  : TPathObj;
begin
  for i := 1 to List.Count-1 do
  begin
    Tmp := List.Items[i];
    j := i - 1;
    while (j >= 0) and ((List.Items[j].Z > Tmp.Z) or
      ((List.Items[j].Z = Tmp.Z) and (List.Items[j].Height > Tmp.Height))) do
    begin
      List.Items[j+1] := List.Items[j];
      Dec(j);
    end;
    List.Items[j+1] := Tmp;
  end;
end;

function CalcNewZ(var DestList : TPathObjList; MinZ, MaxZ : Integer; var Z : Integer) : Boolean;
var
  i, j          : Integer;
  ResultZ       : Integer;
  CurrentTempZ  : Integer;
  CurrentZ      : Integer;
  ObjZ, TempAvg : Integer;
  TempFlags     : Byte;
  Delta         : Integer;
  Sentinel      : TPathObj;
begin
  Result := False;
  if DestList.Count = 0 then Exit;   // ClassicUO: CreateItemList found nothing

  SortObjects(DestList);
  FillChar(Sentinel, SizeOf(Sentinel), 0);
  Sentinel.Flags := POF_IMPASSABLE_OR_SURFACE;
  Sentinel.Z := 128;
  Sentinel.AverageZ := 128;
  Sentinel.Height := 128;
  DestList.Items[DestList.Count] := Sentinel;   // AddPathObj always leaves this slot free

  ResultZ := -128;
  if Z < MinZ then Z := MinZ;
  CurrentTempZ := 1000000;
  CurrentZ := -128;

  for i := 0 to DestList.Count do        // Count itself is the sentinel
    if (DestList.Items[i].Flags and POF_IMPASSABLE_OR_SURFACE) <> 0 then
    begin
      ObjZ := DestList.Items[i].Z;
      if ObjZ - MinZ >= BLOCK_HEIGHT then
        for j := i-1 downto 0 do
        begin
          TempFlags := DestList.Items[j].Flags;
          if (TempFlags and (POF_SURFACE or POF_BRIDGE)) <> 0 then
          begin
            TempAvg := DestList.Items[j].AverageZ;
            if (TempAvg >= CurrentZ) and (ObjZ - TempAvg >= BLOCK_HEIGHT) and
              (((TempAvg <= MaxZ) and ((TempFlags and POF_SURFACE) <> 0)) or
               (((TempFlags and POF_BRIDGE) <> 0) and (DestList.Items[j].Z <= MaxZ))) then
            begin
              Delta := Abs(Z - TempAvg);
              if Delta < CurrentTempZ then
              begin
                CurrentTempZ := Delta;
                ResultZ := TempAvg;
              end;
            end;
          end;
        end;

      if MinZ < DestList.Items[i].AverageZ then MinZ := DestList.Items[i].AverageZ;
      if CurrentZ < DestList.Items[i].AverageZ then CurrentZ := DestList.Items[i].AverageZ;
    end;

  Z := ResultZ;
  Result := ResultZ <> -128;
end;

function CalculateNewZ(Src : TWalkSource; X, Y : Integer; var Z : Integer;
  Direction : Integer) : Boolean;
var
  SrcList, DestList : TPathObjList;
  MinZ, MaxZ        : Integer;
  Back              : Integer;
begin
  // ClassicUO CalculateMinMaxZ reads the cell the step comes from: one step back.
  Back := (Direction and 7) xor 4;
  SrcList.Count := 0;
  if not Src.GetObjects(X + DirX[Back], Y + DirY[Back], SrcList) then
    SrcList.Count := 0;
  CalcMinMaxZ(SrcList, Z, Direction, MinZ, MaxZ);

  DestList.Count := 0;
  Result := Src.GetObjects(X, Y, DestList) and CalcNewZ(DestList, MinZ, MaxZ, Z);
  if not Result then Z := -128;
end;

function CanStep(Src : TWalkSource; X, Y, Z, Direction : Integer; out NewZ : Integer) : Boolean;
var
  i, TestDir, TestZ : Integer;
begin
  Direction := Direction and 7;
  NewZ := Z;
  Result := CalculateNewZ(Src, X + DirX[Direction], Y + DirY[Direction], NewZ, Direction);

  if Result and Odd(Direction) then
    for i := 0 to 1 do
    begin
      if i = 0 then TestDir := (Direction + 1) and 7
      else TestDir := (Direction - 1) and 7;
      TestZ := Z;
      Result := CalculateNewZ(Src, X + DirX[TestDir], Y + DirY[TestDir], TestZ, TestDir);
      if not Result then Break;
    end;
end;

function StandZ(Src : TWalkSource; X, Y : Integer; var Z : Integer) : Boolean;
var
  List : TPathObjList;
begin
  List.Count := 0;
  Result := Src.GetObjects(X, Y, List) and CalcNewZ(List, -128, 127, Z);
end;

end.
