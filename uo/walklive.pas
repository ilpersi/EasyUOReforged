unit walklive;

{
  New addition (not in the original EasyUO): the walker's live overlay -- a TWalkSource that answers
  like the one it wraps (the world model read from the client's files, walkmap.pas) plus what the
  client holds near the character and the files don't have: ground items (doors among them), house
  pieces and mobiles, and the cells where a step was refused (learned blocks, which expire). See
  docs\pathfinding.md, "Live overlay".

  - An item or a house piece counts as a static: its tiledata flags and height, by graphic
    (TileInfo), at the height the client holds it at, through StaticPathObj.
  - A mobile is an obstacle 16 high where it stands, as in ClassicUO Pathfinder.CreateItemList's
    mobile case (DEFAULT_CHARACTER_HEIGHT; BSD-2-Clause, see NOTICE), unless IgnoreMobiles. The
    character itself (SelfID) never is.
  - A door is left out when OpenDoors is set, since the walker opens it, and its cell costs DoorCost
    more (CellCost), so a route goes through a door only when that saves more than it costs.
    ClassicUO's pathfinder leaves doors out the same way when it opens them itself (the tiledata Door
    flag, plus a few door graphics without it).
  - A door standing on a cell with a house piece is a player house's door. It stays a wall unless
    OpenHouseDoors: walked live on the beta, a route through a house's doors met a tile inside that
    the server refused although the client showed it free.
  - A learned block is an obstacle from -128 up past 127 over the whole cell: nothing stands there.
    Each has its own expiry time; Expire drops the old ones. The walker learns them from refused
    steps and from the client's own step check, which can add a hundred at once, so they are kept
    with the rectangle they lie in, and a cell outside it is answered without looking at the list.

  Pure logic: the objects come from the caller (uocommands.pas reads them from the client), so the
  tests run it on a synthetic grid.
}

{$mode delphi}{$H+}

interface

uses
  walkrules;

const
  LIVE_CHAR_HEIGHT = 16;   // ClassicUO Constants.DEFAULT_CHARACTER_HEIGHT: a mobile as an obstacle
  LIVE_RANGE       = 40;   // tiles around the character the overlay is filled for: past what
                           // either client keeps loaded (18 to 31 tiles, measured)

type
  TLiveKind = (lkItem, lkMobile, lkMulti);

  TLiveObj = record
    X, Y, Z : Integer;
    Graphic : Integer;    // tile graphic of an item or a house piece; a mobile's body (unused)
    Kind    : TLiveKind;
    ID      : Cardinal;   // serial; 0 for a house piece
  end;
  TLiveObjs = array of TLiveObj;

  // A static graphic's tiledata: the low 32 bits of its flags, and its height.
  TTileInfoFunc = function(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean of object;

  TLearnedBlock = record
    Facet, X, Y : Integer;
    Expires     : QWord;
  end;

  TLiveOverlay = class(TWalkSource)
  private
    FObjs      : TLiveObjs;
    FFlags     : array of Cardinal;   // per object: tiledata flags (items, house pieces)
    FHeight    : array of Integer;
    FKnown     : array of Boolean;    // per object: TileInfo knew its graphic
    FHouse     : array of Boolean;    // per object: a door on a house piece's cell
    FNext      : array of Integer;    // next object on the same cell, -1 = none
    FSlotKey   : array of Cardinal;   // open-addressed cell table: key, first object
    FSlotHead  : array of Integer;
    FSlotMask  : Integer;
    FX1, FY1   : Integer;             // the rectangle the objects lie in
    FX2, FY2   : Integer;
    FLearned   : array of TLearnedBlock;
    FLX1, FLY1 : Integer;             // the rectangle the learned blocks lie in
    FLX2, FLY2 : Integer;
    procedure LearnedBounds;
    function  Slot(X, Y : Integer) : Integer;
    function  FirstAt(X, Y : Integer) : Integer;
    function  IsDoorObj(i : Integer) : Boolean;
    function  LearnedAt(X, Y : Integer) : Boolean;
  public
    Base          : TWalkSource;     // the world model this overlay adds to
    TileInfo      : TTileInfoFunc;   // tiledata, for items and house pieces
    Facet         : Integer;         // the facet Base answers for; learned blocks of others don't apply
    SelfID        : Cardinal;        // the character: never an obstacle
    IgnoreMobiles : Boolean;
    OpenDoors     : Boolean;
    OpenHouseDoors: Boolean;         // and the doors of player houses
    DoorCost      : Integer;         // in the planner's units (100 = a step)
    IgnoreLearned : Boolean;         // answer as if there were no learned blocks: the client's view
    constructor Create;
    procedure ResetOptions;   // mobiles block, doors (not house doors) open at a cost of 50
    // Replaces the live objects. TileInfo is read here, once per object.
    procedure SetObjects(const Objs : TLiveObjs);
    procedure ClearObjects;
    function  ObjectCount : Integer;
    function  GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean; override;
    function  CellCost(X, Y : Integer) : Integer; override;
    // Is there a door on the cell the walker may open (whatever OpenDoors says)? A house door
    // counts only with OpenHouseDoors.
    function  DoorAt(X, Y : Integer) : Boolean;
    // Is a mobile other than the character standing on the cell (whatever IgnoreMobiles says)?
    function  MobileAt(X, Y : Integer) : Boolean;
    // Learned blocks: Learn adds (or renews) one that lasts LifeMs from Now.
    procedure Learn(AFacet, X, Y : Integer; Now : QWord; LifeMs : Cardinal);
    procedure Unlearn(AFacet, X, Y : Integer);
    procedure Expire(Now : QWord);
    procedure ClearLearned;
    function  IsLearned(AFacet, X, Y : Integer) : Boolean;
    function  LearnedCount : Integer;
  end;

implementation

function CellKey(X, Y : Integer) : Cardinal; inline;
begin
  Result := (Cardinal(Y and $FFFF) shl 16) or Cardinal(X and $FFFF);
end;

// ClassicUO's ignoreDoors test: the Door flag, or one of the door graphics tiledata doesn't flag.
function DoorTile(Graphic : Integer; Flags : Cardinal) : Boolean;
begin
  Result := ((Flags and TDF_DOOR) <> 0) or (Graphic = $0692) or (Graphic = $0846) or
    (Graphic = $0873) or ((Graphic >= $06F5) and (Graphic <= $06F6));
end;

constructor TLiveOverlay.Create;
begin
  inherited Create;
  ResetOptions;
  ClearObjects;
end;

procedure TLiveOverlay.ResetOptions;
begin
  IgnoreMobiles := False;
  OpenDoors := True;
  OpenHouseDoors := False;
  DoorCost := 50;
end;

procedure TLiveOverlay.ClearObjects;
begin
  SetLength(FObjs, 0);
  SetLength(FFlags, 0);
  SetLength(FHeight, 0);
  SetLength(FKnown, 0);
  SetLength(FHouse, 0);
  SetLength(FNext, 0);
  SetLength(FSlotKey, 0);
  SetLength(FSlotHead, 0);
  FSlotMask := 0;
  FX1 := 1;
  FX2 := 0;
  FY1 := 1;
  FY2 := 0;
end;

function TLiveOverlay.ObjectCount : Integer;
begin
  Result := Length(FObjs);
end;

function TLiveOverlay.Slot(X, Y : Integer) : Integer;
var
  Key : Cardinal;
begin
  Key := CellKey(X, Y);
  Result := Integer((Key*2654435761) shr 8) and FSlotMask;
  while (FSlotHead[Result] >= 0) and (FSlotKey[Result] <> Key) do
    Result := (Result + 1) and FSlotMask;
end;

procedure TLiveOverlay.SetObjects(const Objs : TLiveObjs);
var
  i, s, Size : Integer;
  H          : Integer;
  Fl         : Cardinal;
begin
  ClearObjects;
  if Length(Objs) = 0 then Exit;
  FObjs := Copy(Objs, 0, Length(Objs));
  SetLength(FFlags, Length(FObjs));
  SetLength(FHeight, Length(FObjs));
  SetLength(FKnown, Length(FObjs));
  SetLength(FHouse, Length(FObjs));
  SetLength(FNext, Length(FObjs));

  Size := 64;
  while Size < 2*Length(FObjs) do Size := Size*2;
  SetLength(FSlotKey, Size);
  SetLength(FSlotHead, Size);
  FillDWord(FSlotHead[0], Size, $FFFFFFFF);
  FSlotMask := Size - 1;

  FX1 := FObjs[0].X;
  FX2 := FX1;
  FY1 := FObjs[0].Y;
  FY2 := FY1;
  for i := 0 to High(FObjs) do
  begin
    FKnown[i] := False;
    FFlags[i] := 0;
    FHeight[i] := 0;
    if (FObjs[i].Kind <> lkMobile) and Assigned(TileInfo) and TileInfo(FObjs[i].Graphic, Fl, H) then
    begin
      FKnown[i] := True;
      FFlags[i] := Fl;
      FHeight[i] := H;
    end;
    s := Slot(FObjs[i].X, FObjs[i].Y);
    FSlotKey[s] := CellKey(FObjs[i].X, FObjs[i].Y);
    FNext[i] := FSlotHead[s];
    FSlotHead[s] := i;
    if FObjs[i].X < FX1 then FX1 := FObjs[i].X;
    if FObjs[i].X > FX2 then FX2 := FObjs[i].X;
    if FObjs[i].Y < FY1 then FY1 := FObjs[i].Y;
    if FObjs[i].Y > FY2 then FY2 := FObjs[i].Y;
  end;

  // A door on a house piece's cell belongs to a player house.
  for i := 0 to High(FObjs) do
  begin
    FHouse[i] := False;
    if (FObjs[i].Kind = lkItem) and FKnown[i] and DoorTile(FObjs[i].Graphic, FFlags[i]) then
    begin
      s := FirstAt(FObjs[i].X, FObjs[i].Y);
      while (s >= 0) and not FHouse[i] do
      begin
        FHouse[i] := FObjs[s].Kind = lkMulti;
        s := FNext[s];
      end;
    end;
  end;
end;

function TLiveOverlay.FirstAt(X, Y : Integer) : Integer;
begin
  Result := -1;
  if (X < FX1) or (X > FX2) or (Y < FY1) or (Y > FY2) then Exit;
  Result := FSlotHead[Slot(X, Y)];
end;

// A door the walker may open.
function TLiveOverlay.IsDoorObj(i : Integer) : Boolean;
begin
  Result := (FObjs[i].Kind = lkItem) and FKnown[i] and DoorTile(FObjs[i].Graphic, FFlags[i]) and
    (OpenHouseDoors or not FHouse[i]);
end;

function TLiveOverlay.DoorAt(X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := True;
  i := FirstAt(X, Y);
  while i >= 0 do
  begin
    if IsDoorObj(i) then Exit;
    i := FNext[i];
  end;
  Result := False;
end;

function TLiveOverlay.MobileAt(X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := True;
  i := FirstAt(X, Y);
  while i >= 0 do
  begin
    if (FObjs[i].Kind = lkMobile) and (FObjs[i].ID <> SelfID) then Exit;
    i := FNext[i];
  end;
  Result := False;
end;

function TLiveOverlay.CellCost(X, Y : Integer) : Integer;
begin
  Result := 0;
  if OpenDoors and (DoorCost > 0) and DoorAt(X, Y) then Result := DoorCost;
end;

// The client's step check can learn a hundred cells at once, and the planner asks about every cell
// it reaches: the rectangle keeps the search far from them from scanning the list.
procedure TLiveOverlay.LearnedBounds;
var
  i : Integer;
begin
  FLX1 := 1;
  FLX2 := 0;
  FLY1 := 1;
  FLY2 := 0;
  for i := 0 to High(FLearned) do
  begin
    if (i = 0) or (FLearned[i].X < FLX1) then FLX1 := FLearned[i].X;
    if (i = 0) or (FLearned[i].X > FLX2) then FLX2 := FLearned[i].X;
    if (i = 0) or (FLearned[i].Y < FLY1) then FLY1 := FLearned[i].Y;
    if (i = 0) or (FLearned[i].Y > FLY2) then FLY2 := FLearned[i].Y;
  end;
end;

function TLiveOverlay.LearnedAt(X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := False;
  if (X < FLX1) or (X > FLX2) or (Y < FLY1) or (Y > FLY2) then Exit;
  Result := True;
  for i := 0 to High(FLearned) do
    if (FLearned[i].X = X) and (FLearned[i].Y = Y) and (FLearned[i].Facet = Facet) then Exit;
  Result := False;
end;

function TLiveOverlay.GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean;
var
  i   : Integer;
  Obj : TPathObj;
begin
  Result := Base.GetObjects(X, Y, List);
  if not Result then Exit;

  i := FirstAt(X, Y);
  while i >= 0 do
  begin
    case FObjs[i].Kind of
      lkMobile:
        if not IgnoreMobiles and (FObjs[i].ID <> SelfID) then
        begin
          FillChar(Obj, SizeOf(Obj), 0);
          Obj.Flags := POF_IMPASSABLE_OR_SURFACE;
          Obj.Z := FObjs[i].Z;
          Obj.AverageZ := FObjs[i].Z + LIVE_CHAR_HEIGHT;
          Obj.Height := LIVE_CHAR_HEIGHT;
          AddPathObj(List, Obj);
        end;
    else
      if FKnown[i] and not (OpenDoors and IsDoorObj(i)) and
        StaticPathObj(FFlags[i], FHeight[i], FObjs[i].Z, Obj) then
        AddPathObj(List, Obj);
    end;
    i := FNext[i];
  end;

  if (Length(FLearned) > 0) and not IgnoreLearned and LearnedAt(X, Y) then
  begin
    FillChar(Obj, SizeOf(Obj), 0);
    Obj.Flags := POF_IMPASSABLE_OR_SURFACE;
    Obj.Z := -128;
    Obj.AverageZ := 127;
    Obj.Height := 255;
    AddPathObj(List, Obj);
  end;
end;

procedure TLiveOverlay.Learn(AFacet, X, Y : Integer; Now : QWord; LifeMs : Cardinal);
var
  i : Integer;
begin
  for i := 0 to High(FLearned) do
    if (FLearned[i].X = X) and (FLearned[i].Y = Y) and (FLearned[i].Facet = AFacet) then
    begin
      FLearned[i].Expires := Now + LifeMs;
      Exit;
    end;
  SetLength(FLearned, Length(FLearned) + 1);
  FLearned[High(FLearned)].Facet := AFacet;
  FLearned[High(FLearned)].X := X;
  FLearned[High(FLearned)].Y := Y;
  FLearned[High(FLearned)].Expires := Now + LifeMs;
  LearnedBounds;
end;

procedure TLiveOverlay.Unlearn(AFacet, X, Y : Integer);
var
  i, n : Integer;
begin
  n := 0;
  for i := 0 to High(FLearned) do
    if not ((FLearned[i].X = X) and (FLearned[i].Y = Y) and (FLearned[i].Facet = AFacet)) then
    begin
      FLearned[n] := FLearned[i];
      Inc(n);
    end;
  SetLength(FLearned, n);
  LearnedBounds;
end;

procedure TLiveOverlay.Expire(Now : QWord);
var
  i, n : Integer;
begin
  n := 0;
  for i := 0 to High(FLearned) do
    if FLearned[i].Expires > Now then
    begin
      FLearned[n] := FLearned[i];
      Inc(n);
    end;
  SetLength(FLearned, n);
  LearnedBounds;
end;

procedure TLiveOverlay.ClearLearned;
begin
  SetLength(FLearned, 0);
  LearnedBounds;
end;

function TLiveOverlay.IsLearned(AFacet, X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := True;
  for i := 0 to High(FLearned) do
    if (FLearned[i].X = X) and (FLearned[i].Y = Y) and (FLearned[i].Facet = AFacet) then Exit;
  Result := False;
end;

function TLiveOverlay.LearnedCount : Integer;
begin
  Result := Length(FLearned);
end;

end.
