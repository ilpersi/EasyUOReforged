unit walkmap;

{
  New addition (not in the original EasyUO): the pathfinder's world model, read from the client's
  own files -- land (mapN), statics (staidxN/staticsN), tiledata, and optionally the dif files.
  It answers walkrules' TWalkSource for one facet at a time. See docs\pathfinding.md.

  A reader of its own rather than tiles.pas' TTTBasic, so the tile command's behaviour stays as
  it is, and because a search needs things TTTBasic doesn't do:
  - Each 8x8 block is decoded once into ready-made TPathObj lists and cached. A search reads the
    same cells many times; TTTBasic seeks the files on every call.
  - tiledata is read whole, including the static tiles' height byte, which TTTBasic never reads
    and the step rules need.
  - It reads current installs the way the client does: Trammel from map1/staidx1/statics1 when
    the install has them (falling back to Felucca's files on old installs, which have none);
    each facet's width from its staidx size (Felucca/Trammel are 7168 wide on current clients,
    6144 on old ones); Ter Mur blocks 512 high.

  Land is turned into ClassicUO's PathObject form as ClassicUO does it (Pathfinder.cs
  CreateItemList, Land.cs ApplyStretch; BSD-2-Clause, see NOTICE): its height is the average of
  two opposite corners, and a textured land tile that isn't flat counts as "stretched". Whether a
  texture exists comes from texidx.mul, as in ClassicUO; without that file, texture 0 counts as
  none.

  Dif files (mapdif*, stadif*) are only used when asked for. The client applies them only when
  the server tells it to, which a script can't see, and current EA installs ship no mapdif*.

  Memory: a facet whose map exists only as UOP (mapNLegacyMUL.uop) is unpacked into memory by
  uopfile.LoadUopAsStream, as tiles.pas does -- about 90 MB for Felucca or Trammel. A facet is
  opened only when a search needs it. The block cache starts over after WALKMAP_MAX_BLOCKS
  decoded blocks.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, walkrules, uopfile;

const
  WALKMAP_MAX_BLOCKS = 32768;   // decoded 8x8 blocks kept before the cache starts over

  // Blocks per column (map height / 8) of each facet; the width comes from the files.
  FacetBlocksY : array[0..5] of Integer = (512, 512, 200, 256, 181, 512);

type
  TLandCell = packed record    // one land tile as stored in mapN.mul
    Graphic : Word;
    Z       : ShortInt;
  end;
  TLandBlock = array[0..63] of TLandCell;
  PLandBlock = ^TLandBlock;

  TCellBlock = record           // one decoded 8x8 block
    Start : array[0..64] of Word;     // the objects of cell i are Objs[Start[i]..Start[i+1]-1]
    Objs  : array of TPathObj;
  end;
  PCellBlock = ^TCellBlock;

  TWalkFacet = class
  private
    Map, StaIdx, Statics      : TStream;
    MapDif, StaDifIdx, StaDif : TStream;
    MapDifPos, StaDifPos      : array of Integer;   // per block: its entry in the dif files, -1 = none
    Land                      : array of PLandBlock;
    Cells                     : array of PCellBlock;
  public
    Facet   : Integer;          // the facet number
    FileNr  : Integer;          // the N of mapN/staidxN/staticsN actually read
    BlocksX : Integer;
    BlocksY : Integer;
    destructor Destroy; override;
    procedure  Flush;
  end;

  TWalkMap = class(TWalkSource)
  private
    FFolder      : String;
    FNewTileData : Boolean;
    FUseDifs     : Boolean;
    FTileDataOk  : Boolean;
    FFacets      : array[0..5] of TWalkFacet;
    FTried       : array[0..5] of Boolean;
    FCur         : TWalkFacet;
    FDecoded     : Integer;
    FLandRead    : Integer;
    LandFlags    : array of Cardinal;
    LandTex      : array of Word;
    StaticFlags  : array of Cardinal;
    StaticHeight : array of Byte;
    TexValid     : array of Boolean;
    FHasTexIdx   : Boolean;
    procedure LoadTileData;
    procedure LoadTexIdx;
    function  OpenFacet(F : Integer) : TWalkFacet;
    function  ReadLand(Fa : TWalkFacet; Block : Integer) : PLandBlock;
    function  LandCell(X, Y : Integer; out Cell : TLandCell) : Boolean;
    function  LandZ(X, Y : Integer) : Integer;
    function  LandObject(X, Y : Integer; const Cell : TLandCell; out Obj : TPathObj) : Boolean;
    function  Decode(Block, BX, BY : Integer) : PCellBlock;
    procedure Flush;
    function  GetWidth : Integer;
    function  GetHeight : Integer;
  public
    // Folder: the client folder (with or without a trailing backslash). NewTileData: tiledata
    // has 64-bit flags (TCstDB.FFLAGS and 1). Nothing is read from the map files until a facet
    // is selected.
    constructor Create(const Folder : String; NewTileData, UseDifs : Boolean);
    destructor  Destroy; override;
    // Makes Facet the one GetObjects answers for, opening its files on first use. False when
    // tiledata or the facet's files are missing.
    function  SelectFacet(Facet : Integer) : Boolean;
    function  GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean; override;
    // The static tile Graphic's tiledata flags (the low 32 bits) and height, for the walker's live
    // overlay: items and house pieces are looked up by graphic like statics. False when tiledata
    // isn't loaded yet (no facet selected) or has no such tile.
    function  StaticInfo(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean;
    property  Folder : String read FFolder;
    property  UseDifs : Boolean read FUseDifs;
    property  NewTileData : Boolean read FNewTileData;
    property  Width : Integer read GetWidth;      // of the selected facet, in tiles
    property  Height : Integer read GetHeight;
    function  FileNr : Integer;                   // the N of the mapN files it reads, -1 = none
  end;

// The tiledata format a file of Size bytes has: True for 64-bit flags. For callers without a
// client to ask (TCstDB.FFLAGS); a whole file of either format is told apart by its size.
function GuessNewTileData(Size : Int64) : Boolean;

implementation

const
  LAND_Z_OUTSIDE = -125;   // the height ClassicUO's Map.GetTileZ gives outside the map
  OLD_LAND_REC   = 26;     // flags(4) texture(2) name(20)
  NEW_LAND_REC   = 30;     // flags(8) texture(2) name(20)
  OLD_STATIC_REC = 37;     // flags(4) weight quality misc(2) unk quantity anim(2) unk hue
                           // stacking value height name(20)
  NEW_STATIC_REC = 41;     // the same with 8-byte flags

function GuessNewTileData(Size : Int64) : Boolean;
var
  Rest : Int64;
begin
  Rest := Size - 512*(4 + 32*NEW_LAND_REC);
  if (Rest >= 0) and (Rest mod (4 + 32*NEW_STATIC_REC) = 0) then Exit(True);
  Rest := Size - 512*(4 + 32*OLD_LAND_REC);
  if (Rest >= 0) and (Rest mod (4 + 32*OLD_STATIC_REC) = 0) then Exit(False);
  Result := True;   // neither fits exactly: assume a current client
end;

function OpenIfExists(const FileName : String) : TStream;
begin
  Result := nil;
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
end;

// The block numbers listed in a mapdifl/stadifl file, into Pos (block -> entry), later wins.
procedure LoadDifList(const FileName : String; var Pos : array of Integer);
var
  M     : TMemoryStream;
  i     : Integer;
  Block : Cardinal;
begin
  M := TMemoryStream.Create;
  try
    M.LoadFromFile(FileName);
    for i := 0 to M.Size div 4 - 1 do
    begin
      Block := PCardinal(PByte(M.Memory) + i*4)^;
      if Block < Cardinal(Length(Pos)) then Pos[Block] := i;
    end;
  finally
    M.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TWalkFacet.Destroy;
begin
  Flush;
  Map.Free;
  StaIdx.Free;
  Statics.Free;
  MapDif.Free;
  StaDifIdx.Free;
  StaDif.Free;
  inherited Destroy;
end;

procedure TWalkFacet.Flush;
var
  i : Integer;
begin
  for i := 0 to High(Cells) do
    if Cells[i] <> nil then
    begin
      Dispose(Cells[i]);
      Cells[i] := nil;
    end;
  for i := 0 to High(Land) do
    if Land[i] <> nil then
    begin
      Dispose(Land[i]);
      Land[i] := nil;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TWalkMap.Create(const Folder : String; NewTileData, UseDifs : Boolean);
begin
  inherited Create;
  FFolder := IncludeTrailingPathDelimiter(Folder);
  FNewTileData := NewTileData;
  FUseDifs := UseDifs;
end;

destructor TWalkMap.Destroy;
var
  i : Integer;
begin
  for i := 0 to 5 do
    FFacets[i].Free;
  inherited Destroy;
end;

procedure TWalkMap.LoadTileData;
var
  M         : TMemoryStream;
  P         : PByte;
  FlagSize  : Integer;
  LandRec   : Integer;
  StaticRec : Integer;
  Pos, i    : Int64;
begin
  if not FileExists(FFolder + 'tiledata.mul') then Exit;
  FlagSize := 4;
  if FNewTileData then FlagSize := 8;
  LandRec := FlagSize + 22;
  StaticRec := FlagSize + 33;

  M := TMemoryStream.Create;
  try
    M.LoadFromFile(FFolder + 'tiledata.mul');
    P := M.Memory;

    SetLength(LandFlags, $4000);
    SetLength(LandTex, $4000);
    Pos := 0;
    for i := 0 to $3FFF do
    begin
      if (i and 31) = 0 then Inc(Pos, 4);   // each group of 32 starts with a 4-byte header
      if Pos + LandRec > M.Size then Break;
      LandFlags[i] := PCardinal(P + Pos)^;
      LandTex[i] := PWord(P + Pos + FlagSize)^;
      Inc(Pos, LandRec);
    end;

    Pos := 512*(4 + 32*LandRec);            // statics start after the whole land section
    SetLength(StaticFlags, $10000);
    SetLength(StaticHeight, $10000);
    i := 0;
    while i < $10000 do
    begin
      if (i and 31) = 0 then Inc(Pos, 4);
      if Pos + StaticRec > M.Size then Break;
      StaticFlags[i] := PCardinal(P + Pos)^;
      StaticHeight[i] := P[Pos + FlagSize + 12];
      Inc(Pos, StaticRec);
      Inc(i);
    end;
    SetLength(StaticFlags, i);
    SetLength(StaticHeight, i);
    FTileDataOk := True;
  finally
    M.Free;
  end;
end;

// texidx.mul: 12-byte entries (offset, length, extra); a texture exists when its offset isn't
// negative and its length is positive (ClassicUO's GetValidRefEntry).
procedure TWalkMap.LoadTexIdx;
var
  M : TMemoryStream;
  i : Integer;
  P : PInteger;
begin
  if not FileExists(FFolder + 'texidx.mul') then Exit;
  M := TMemoryStream.Create;
  try
    M.LoadFromFile(FFolder + 'texidx.mul');
    SetLength(TexValid, M.Size div 12);
    for i := 0 to High(TexValid) do
    begin
      P := PInteger(PByte(M.Memory) + i*12);
      TexValid[i] := (P[0] >= 0) and (P[1] > 0);
    end;
    FHasTexIdx := True;
  finally
    M.Free;
  end;
end;

function TWalkMap.OpenFacet(F : Integer) : TWalkFacet;
var
  Fa : TWalkFacet;
  Nr : Integer;
  N  : String;

  function Has(Nr : Integer) : Boolean;
  var
    S : String;
  begin
    S := IntToStr(Nr);
    Result := FileExists(FFolder + 'staidx' + S + '.mul') and
      FileExists(FFolder + 'statics' + S + '.mul') and
      (FileExists(FFolder + 'map' + S + '.mul') or
       FileExists(FFolder + 'map' + S + 'LegacyMUL.uop'));
  end;

  procedure OpenDifs;
  var
    S : String;
  begin
    S := IntToStr(F);
    if FileExists(FFolder + 'mapdifl' + S + '.mul') and FileExists(FFolder + 'mapdif' + S + '.mul') then
    begin
      SetLength(Fa.MapDifPos, Fa.BlocksX*Fa.BlocksY);
      FillDWord(Fa.MapDifPos[0], Length(Fa.MapDifPos), $FFFFFFFF);
      LoadDifList(FFolder + 'mapdifl' + S + '.mul', Fa.MapDifPos);
      Fa.MapDif := OpenIfExists(FFolder + 'mapdif' + S + '.mul');
    end;
    if FileExists(FFolder + 'stadifl' + S + '.mul') and FileExists(FFolder + 'stadifi' + S + '.mul')
      and FileExists(FFolder + 'stadif' + S + '.mul') then
    begin
      SetLength(Fa.StaDifPos, Fa.BlocksX*Fa.BlocksY);
      FillDWord(Fa.StaDifPos[0], Length(Fa.StaDifPos), $FFFFFFFF);
      LoadDifList(FFolder + 'stadifl' + S + '.mul', Fa.StaDifPos);
      Fa.StaDifIdx := OpenIfExists(FFolder + 'stadifi' + S + '.mul');
      Fa.StaDif := OpenIfExists(FFolder + 'stadif' + S + '.mul');
    end;
  end;

begin
  Result := nil;
  Nr := F;
  if (F = 1) and not Has(1) then Nr := 0;   // old installs: Trammel shares Felucca's files
  if not Has(Nr) then Exit;
  N := IntToStr(Nr);

  Fa := TWalkFacet.Create;
  try
    Fa.Facet := F;
    Fa.FileNr := Nr;
    if FileExists(FFolder + 'map' + N + '.mul') then
      Fa.Map := TFileStream.Create(FFolder + 'map' + N + '.mul', fmOpenRead or fmShareDenyNone)
    else
      Fa.Map := LoadUopAsStream(FFolder + 'map' + N + 'LegacyMUL.uop',
        'build/map' + N + 'legacymul/');
    Fa.StaIdx := OpenIfExists(FFolder + 'staidx' + N + '.mul');
    Fa.Statics := OpenIfExists(FFolder + 'statics' + N + '.mul');
    if (Fa.Map = nil) or (Fa.StaIdx = nil) or (Fa.Statics = nil) then
    begin
      Fa.Free;
      Exit;
    end;

    Fa.BlocksY := FacetBlocksY[F];
    Fa.BlocksX := (Fa.StaIdx.Size div 12) div Fa.BlocksY;
    if Fa.BlocksX <= 0 then
    begin
      Fa.Free;
      Exit;
    end;
    SetLength(Fa.Land, Fa.BlocksX*Fa.BlocksY);
    SetLength(Fa.Cells, Fa.BlocksX*Fa.BlocksY);
    if FUseDifs then OpenDifs;
    Result := Fa;
  except
    Fa.Free;
    Result := nil;
  end;
end;

function TWalkMap.SelectFacet(Facet : Integer) : Boolean;
begin
  Result := False;
  FCur := nil;
  if (Facet < 0) or (Facet > 5) then Exit;
  if not FTried[Facet] then
  begin
    FTried[Facet] := True;
    if not FTileDataOk and (Length(LandFlags) = 0) then
    begin
      LoadTileData;
      LoadTexIdx;
    end;
    if FTileDataOk then
      FFacets[Facet] := OpenFacet(Facet);
  end;
  FCur := FFacets[Facet];
  Result := FCur <> nil;
end;

function TWalkMap.GetWidth : Integer;
begin
  Result := 0;
  if FCur <> nil then Result := FCur.BlocksX*8;
end;

function TWalkMap.GetHeight : Integer;
begin
  Result := 0;
  if FCur <> nil then Result := FCur.BlocksY*8;
end;

function TWalkMap.FileNr : Integer;
begin
  Result := -1;
  if FCur <> nil then Result := FCur.FileNr;
end;

procedure TWalkMap.Flush;
var
  i : Integer;
begin
  for i := 0 to 5 do
    if FFacets[i] <> nil then FFacets[i].Flush;
  FDecoded := 0;
  FLandRead := 0;
end;

function TWalkMap.ReadLand(Fa : TWalkFacet; Block : Integer) : PLandBlock;
var
  S   : TStream;
  Pos : Int64;
begin
  Result := Fa.Land[Block];
  if Result <> nil then Exit;

  S := Fa.Map;
  Pos := Int64(Block)*196;
  if (Length(Fa.MapDifPos) > 0) and (Fa.MapDifPos[Block] >= 0) and (Fa.MapDif <> nil) then
  begin
    S := Fa.MapDif;
    Pos := Int64(Fa.MapDifPos[Block])*196;
  end;

  New(Result);
  FillChar(Result^, SizeOf(TLandBlock), 0);   // a block the file doesn't have reads as void
  S.Seek(Pos + 4, soFromBeginning);           // skip the block header
  S.Read(Result^, SizeOf(TLandBlock));
  Fa.Land[Block] := Result;
  Inc(FLandRead);
end;

function TWalkMap.LandCell(X, Y : Integer; out Cell : TLandCell) : Boolean;
begin
  Result := (FCur <> nil) and (X >= 0) and (Y >= 0) and
    (X < FCur.BlocksX*8) and (Y < FCur.BlocksY*8);
  if not Result then Exit;
  Cell := ReadLand(FCur, (X shr 3)*FCur.BlocksY + (Y shr 3))^[(Y and 7)*8 + (X and 7)];
end;

function TWalkMap.LandZ(X, Y : Integer) : Integer;
var
  Cell : TLandCell;
begin
  if LandCell(X, Y, Cell) then Result := Cell.Z
  else Result := LAND_Z_OUTSIDE;
end;

// ClassicUO CreateItemList's land case, with the heights ApplyStretch gives it.
function TWalkMap.LandObject(X, Y : Integer; const Cell : TLandCell; out Obj : TPathObj) : Boolean;

  function NotFlat(Tile, Top, Right, Bottom, Left : Integer) : Boolean;
  begin
    Result := not ((Tile = Top) and (Tile = Right) and (Tile = Bottom) and (Tile = Left));
  end;

var
  G, Tex                  : Integer;
  Fl                      : Cardinal;
  Flat                    : Boolean;
  ZT, ZR, ZL, ZB, MinZ    : Integer;
  T10, T20, T01, T31      : Integer;
  T02, T32, T13, T23, Avg : Integer;
begin
  G := Cell.Graphic;
  Fl := 0;
  Tex := 0;
  if G < Length(LandFlags) then
  begin
    Fl := LandFlags[G];
    Tex := LandTex[G];
  end;
  Result := LandPathObj(G, Fl, Cell.Z, Obj);
  if not Result then Exit;

  ZT := Cell.Z;
  if FHasTexIdx then
    Flat := ((Tex = 0) and ((Fl and TDF_WET) <> 0)) or (Tex >= Length(TexValid)) or not TexValid[Tex]
  else
    Flat := Tex = 0;
  if Flat then Exit;   // LandPathObj's heights are the flat ones

  ZR := LandZ(X + 1, Y);
  ZL := LandZ(X, Y + 1);
  ZB := LandZ(X + 1, Y + 1);
  if Abs(ZT - ZB) <= Abs(ZL - ZR) then Avg := SarLongint(ZT + ZB, 1)
  else Avg := SarLongint(ZL + ZR, 1);
  MinZ := ZT;
  if ZR < MinZ then MinZ := ZR;
  if ZL < MinZ then MinZ := ZL;
  if ZB < MinZ then MinZ := ZB;

  T10 := LandZ(X, Y - 1);
  T20 := LandZ(X + 1, Y - 1);
  T01 := LandZ(X - 1, Y);
  T31 := LandZ(X + 2, Y);
  T02 := LandZ(X - 1, Y + 1);
  T32 := LandZ(X + 2, Y + 1);
  T13 := LandZ(X, Y + 2);
  T23 := LandZ(X + 1, Y + 2);
  Obj.Stretched := NotFlat(ZT, T10, ZR, ZL, T01) or NotFlat(ZR, T20, T31, ZB, ZT) or
    NotFlat(ZB, ZR, T32, T23, ZL) or NotFlat(ZL, ZT, ZB, T13, T02);

  Obj.Z := MinZ;
  Obj.AverageZ := Avg;
  Obj.Height := Avg - MinZ;
  Obj.CornerZ[0] := ZT;
  Obj.CornerZ[1] := ZR;
  Obj.CornerZ[2] := ZB;
  Obj.CornerZ[3] := ZL;
end;

function TWalkMap.Decode(Block, BX, BY : Integer) : PCellBlock;
type
  TStaticRec = packed record   // one record of staticsN.mul
    Graphic : Word;
    X, Y    : Byte;
    Z       : ShortInt;
    Hue     : Word;
  end;
var
  Fa      : TWalkFacet;
  Land    : TLandBlock;
  Recs    : array of TStaticRec;
  Idx     : packed record Start, Len, Extra : Cardinal; end;
  IdxS    : TStream;
  DataS   : TStream;
  IdxPos  : Int64;
  Objs    : array[0..63] of array of TPathObj;
  Cnt     : array[0..63] of Integer;
  Obj     : TPathObj;
  i, c, n : Integer;
begin
  Fa := FCur;
  if (FDecoded >= WALKMAP_MAX_BLOCKS) or (FLandRead >= 2*WALKMAP_MAX_BLOCKS) then Flush;

  Land := ReadLand(Fa, Block)^;
  FillChar(Cnt, SizeOf(Cnt), 0);
  for c := 0 to 63 do
    if LandObject(BX*8 + (c and 7), BY*8 + (c shr 3), Land[c], Obj) then
    begin
      SetLength(Objs[c], 4);
      Objs[c][0] := Obj;
      Cnt[c] := 1;
    end;

  IdxS := Fa.StaIdx;
  DataS := Fa.Statics;
  IdxPos := Int64(Block)*12;
  if (Length(Fa.StaDifPos) > 0) and (Fa.StaDifPos[Block] >= 0) and (Fa.StaDifIdx <> nil)
    and (Fa.StaDif <> nil) then
  begin
    IdxS := Fa.StaDifIdx;
    DataS := Fa.StaDif;
    IdxPos := Int64(Fa.StaDifPos[Block])*12;
  end;
  IdxS.Seek(IdxPos, soFromBeginning);
  if (IdxS.Read(Idx, 12) = 12) and (Idx.Start <> $FFFFFFFF) and (Idx.Len >= 7) then
  begin
    SetLength(Recs, Idx.Len div 7);
    DataS.Seek(Idx.Start, soFromBeginning);
    n := DataS.Read(Recs[0], Length(Recs)*7) div 7;
    for i := 0 to n-1 do
      if (Recs[i].X < 8) and (Recs[i].Y < 8) and (Recs[i].Graphic < Length(StaticFlags)) and
        StaticPathObj(StaticFlags[Recs[i].Graphic], StaticHeight[Recs[i].Graphic], Recs[i].Z, Obj) then
      begin
        c := Recs[i].Y*8 + Recs[i].X;
        if Cnt[c] >= MAX_CELL_OBJECTS-1 then Continue;
        if Cnt[c] >= Length(Objs[c]) then SetLength(Objs[c], Cnt[c]*2 + 4);
        Objs[c][Cnt[c]] := Obj;
        Inc(Cnt[c]);
      end;
  end;

  New(Result);
  n := 0;
  for c := 0 to 63 do
  begin
    Result^.Start[c] := n;
    Inc(n, Cnt[c]);
  end;
  Result^.Start[64] := n;
  SetLength(Result^.Objs, n);
  for c := 0 to 63 do
    for i := 0 to Cnt[c]-1 do
      Result^.Objs[Result^.Start[c] + i] := Objs[c][i];

  Fa.Cells[Block] := Result;
  Inc(FDecoded);
end;

function TWalkMap.StaticInfo(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean;
begin
  Result := (Graphic >= 0) and (Graphic < Length(StaticFlags));
  Flags := 0;
  Height := 0;
  if not Result then Exit;
  Flags := StaticFlags[Graphic];
  Height := StaticHeight[Graphic];
end;

function TWalkMap.GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean;
var
  BX, BY, Block, Cell, i : Integer;
  CB                     : PCellBlock;
begin
  List.Count := 0;
  Result := (FCur <> nil) and (X >= 0) and (Y >= 0) and
    (X < FCur.BlocksX*8) and (Y < FCur.BlocksY*8);
  if not Result then Exit;

  BX := X shr 3;
  BY := Y shr 3;
  Block := BX*FCur.BlocksY + BY;
  CB := FCur.Cells[Block];
  if CB = nil then CB := Decode(Block, BX, BY);
  Cell := (Y and 7)*8 + (X and 7);
  for i := CB^.Start[Cell] to CB^.Start[Cell+1]-1 do
    if not AddPathObj(List, CB^.Objs[i]) then Break;
end;

end.
