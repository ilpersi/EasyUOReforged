unit tiles;

{
  Ported from the original Delphi 7 uo\tiles.pas. Reads local UO client data files
  (map0.mul/staidx0.mul/statics0.mul/tiledata.mul, plus their "dif" override
  counterparts) via plain TFileStream -- no process memory access, no OS-process
  dependency, so unlike most of uo\ this is testable against small synthetic fixture
  files rather than a live client (see Lazarus\tests\fixtures\mul\).

  One bug fixed, found while porting (present in the ORIGINAL Delphi code too --
  bitness-independent, not something the port introduced): TStatics was a plain
  (non-packed) record. Its on-disk format is exactly 7 bytes (word+byte+byte+
  shortint+word, no gaps), but a plain record pads the trailing `hue` field to a
  2-byte boundary (confirmed empirically: SizeOf=8, hue at offset 6, not 5), so the
  `file2.Read(statics,7)` calls throughout this unit were reading the on-disk hue
  bytes into the wrong offsets, corrupting `hue`. Harmless in practice -- `hue` is
  parsed but never read by any caller in this codebase -- but `packed` is the correct,
  free fix for a record that's explicitly modeling an exact on-disk byte layout, so
  it's applied here (TStaidx/TMap have no such gap and needed no change).
}

{$mode delphi}{$H+}

interface
uses classes, sysutils, uoclidata, uopfile;

const
  EnableTerMur = True;

type
	TStaidx = record //The record used in the staidx.mul files
		start:longword; //start determines the start offset of the 8x8block inside the statics.mul files
		len:longword; //length of the 8x8block inside the statics.mul files
		unknown:longword;
	end;

	TStatics = packed record //The record used in the statics.mul files, the statics are additional layers for one map tile
		TileType:word; //The index for the art.mul file
    x:byte; //The x-offset inside the block (from 0 to 7 ...)
    y:byte; //The y-offset inside the block (from 0 to 7 ...)
		z:shortint; //The altitude of the tile
		hue:word; //This is used to make some statics look different
	end;

	TMap = record
		TileType:word; //The index for the art.mul file
		z:shortint; //The altitude of the tile
	end;

  //The record and pointer on the record (bc of tlist) for the overrides
  PListRecord = ^TListRecord;
  TListRecord = record
    offset:longword;
    blocknumber:longword;
  end;

  TTTBasic = class
  private
    Cst : TCstDB;
    // fmap_mul/fmapdif_mul are TStream (not TFileStream) specifically so a facet whose
    // classic map0.mul is missing can fall back to a UOP-reconstructed TMemoryStream
    // (see openmapfiles/uopfile.pas) with zero change to any of the Seek/Read call sites
    // below -- both are TStream descendants supporting the identical interface. Every
    // other facet/file kind here stays classic-.mul-only (TFileStream); see openmapfiles'
    // own comment for the scope reasoning.
    fmap_mul, fmapdif_mul : array[0..5] of TStream;
    fstaidx_mul, fstatics_mul:array[0..5] of TFileStream; //Basic files
    fstadifi_mul, fstadif_mul:array[0..5] of TFileStream; //Override files (aka dif files)
    ftiledata_mul:TFileStream;
    fmapdifblocks, fstadifblocks:array[0..5] of TList;
    fusedifdata:boolean;
    function BlockOverride(var list:TList; blocknumber:longword; var posi:longword):boolean;
    function GetBlockNumber(x, y:word; facet:byte; var BlockNumber:longword) : boolean;
  public
    constructor init(p:string; usedif:boolean; CstDB : TCstDB);
    function GetLayerCount(x, y:word; facet:byte; var tilecnt:byte):boolean;
    function GetTileData(x, y:word; facet:byte; layer:byte; var TileType:word;
      var tilez:shortint; var TileName:string; var tileflags:longword):boolean;
    //function GetTileTypeInfo(tiletype:word; static:boolean; var TileName:string;
    //  var tileflags:longword):boolean;
    destructor destroy; override;
  end;


implementation

{-----------------------------------------------------------------------------
  Procedure : init
  Purpose   : Create the Object
              Assign all the nessecary filestream
              Load the Difblockindex into a TList when usedif = true
  Arguments : p:String - The Path to the UO Directory
              usedif:boolean - if the override data from the dif files should be used
  Result    : None
-----------------------------------------------------------------------------}
constructor TTTBasic.init(p:string; usedif:boolean; CstDB : TCstDB);
  //open the layer0 file (the basic map)
  // Classic mapN.mul is preferred; falls back to the UOP-packaged equivalent
  // (mapNLegacyMUL.uop) only when the classic file is missing -- added for a real,
  // confirmed case: an EA "Ultima Online Classic" install ships UOP-packed maps with
  // no classic map*.mul files at all (see uopfile.pas's own header comment for how
  // that format was validated: byte-for-byte identical to a from-scratch independent
  // reconstruction of a real file on this machine). Every install that already has
  // the classic files sees zero behavior change here -- FileExists is checked first,
  // exactly matching this constructor's existing fileexists-gated pattern for facets
  // 2-5, now applied uniformly to all six instead of leaving facets 0/1 unconditional
  // (they used to always attempt TFileStream.Create and raise immediately if the file
  // was missing; now they fall back to UOP like every other facet, and only end up
  // nil -- same as any other facet whose map data genuinely isn't available in either
  // format -- in the essentially-impossible case where neither exists at all).
  procedure openmapfiles;
    procedure OpenMapFacet(Facet : Integer; const BaseName : String);
    begin
      if fileexists(p + BaseName + '.mul') then
        fmap_mul[Facet] := TFileStream.Create(p + BaseName + '.mul',
          (fmOpenRead or fmShareDenyNone))
      else
        fmap_mul[Facet] := LoadUopAsStream(p + BaseName + 'LegacyMUL.uop',
          'build/' + LowerCase(BaseName) + 'legacymul/');
    end;
  begin
    // Facet 1 intentionally loads from the SAME source as facet 0 (map0, never
    // map1) -- Trammel and Felucca share identical map geometry in classic UO; this
    // is pre-existing behavior (present before this change), not something new here.
    OpenMapFacet(0, 'map0');
    OpenMapFacet(1, 'map0');
    OpenMapFacet(2, 'map2');
    OpenMapFacet(3, 'map3');
    OpenMapFacet(4, 'map4');
    OpenMapFacet(5, 'map5');
  end;
  //open the index files for the statics.mul file
  procedure openstaidxfiles;
  begin
    fstaidx_mul[0] := TFileStream.Create(p + 'staidx0.mul', (fmOpenRead or
      fmShareDenyNone));
    fstaidx_mul[1] := TFileStream.Create(p + 'staidx0.mul', (fmOpenRead or
      fmShareDenyNone));
    if fileexists(p + 'staidx2.mul') then
      fstaidx_mul[2] := TFileStream.Create(p + 'staidx2.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'staidx3.mul') then
      fstaidx_mul[3] := TFileStream.Create(p + 'staidx3.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'staidx4.mul') then
      fstaidx_mul[4] := TFileStream.Create(p + 'staidx4.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'staidx5.mul') then
      fstaidx_mul[5] := TFileStream.Create(p + 'staidx5.mul', (fmOpenRead or
        fmShareDenyNone));
  end;
  //open the statics files, here all the additional layers are stored
  procedure openstaticsfiles;
  begin
    fstatics_mul[0] := TFileStream.Create(p + 'statics0.mul', (fmOpenRead or
      fmShareDenyNone));
    fstatics_mul[1] := TFileStream.Create(p + 'statics0.mul', (fmOpenRead or
      fmShareDenyNone));
    if fileexists(p + 'statics2.mul') then
      fstatics_mul[2] := TFileStream.Create(p + 'statics2.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'statics3.mul') then
      fstatics_mul[3] := TFileStream.Create(p + 'statics3.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'statics4.mul') then
      fstatics_mul[4] := TFileStream.Create(p + 'statics4.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'statics5.mul') then
      fstatics_mul[5] := TFileStream.Create(p + 'statics5.mul', (fmOpenRead or
        fmShareDenyNone));
  end;

  //This is used to load the blocks that need to be overriden into an TList
  procedure LoadList(var list:TList; filename:string);
    function Find(value:longword; var Index: Longword): Boolean;
    var
      L, H, I, C: Integer;
    begin
      Result := False;
      L := 0;
      H := list.count - 1;
      while L <= H do
      begin
        I := (L + H) shr 1;
        C := PListRecord(list[I])^.blocknumber - value;
        if C < 0 then L := I + 1 else
        begin
          H := I - 1;
          if C = 0 then
          begin
            Result := True;
            L := I;
          end;
        end;
      end;
      Index := L;
    end;
  var tempmemstream:TMemoryStream;
      tempblock:longword;
      i, j:longword;
      h:PListRecord;
  begin
    tempmemstream := TMemoryStream.Create;
    tempmemstream.LoadFromFile(filename);
    tempmemstream.seek(0, sofrombeginning);
    list := TList.Create;
    list.Clear;
    for i := 0 to tempmemstream.Size div 4 - 1 do
    begin
      tempmemstream.Read(tempblock, 4);
      if find(tempblock, j)
      then PListRecord(list[j])^.offset := i
      else
      begin
        new(h);
        h^.offset := i;
        h^.blocknumber := tempblock;
        list.Insert(j, h);
      end;
    end;
    tempmemstream.Free;
    list.Capacity := list.Count;
  end;

  //the override files for the maplayer (layer0)
  //it contains all the 8x8 blocks to override
  procedure readmapdifblocks;
  begin
    LoadList(fmapdifblocks[0], p + 'mapdifl0.mul');
    LoadList(fmapdifblocks[1], p + 'mapdifl1.mul');
    if fileexists(p + 'mapdifl2.mul') then
      LoadList(fmapdifblocks[2], p + 'mapdifl2.mul');
    if fileexists(p + 'mapdifl3.mul') then
      LoadList(fmapdifblocks[3], p + 'mapdifl3.mul');
    if fileexists(p + 'mapdifl4.mul') then
      LoadList(fmapdifblocks[4], p + 'mapdifl4.mul');
    if fileexists(p + 'mapdifl5.mul') then
      LoadList(fmapdifblocks[5], p + 'mapdifl5.mul');
  end;
  //the override files for the statics (layer>0)
  //it contains all the 8x8 blocks to override
  procedure readstadifblocks;
    begin
    LoadList(fstadifblocks[0], p + 'stadifl0.mul');
    LoadList(fstadifblocks[1], p + 'stadifl1.mul');
    if fileexists(p + 'stadifl2.mul') then
      LoadList(fstadifblocks[2], p + 'stadifl2.mul');
    if fileexists(p + 'stadifl3.mul') then
      LoadList(fstadifblocks[3], p + 'stadifl3.mul');
    if fileexists(p + 'stadifl4.mul') then
      LoadList(fstadifblocks[4], p + 'stadifl4.mul');
    if fileexists(p + 'stadifl5.mul') then
      LoadList(fstadifblocks[5], p + 'stadifl5.mul');
  end;

  //equivalent to map.mul files, just the overrides for it
  procedure openmapdiffiles;
  begin
    fmapdif_mul[0] := TFileStream.Create(p + 'mapdif0.mul', (fmOpenRead or
      fmShareDenyNone));
    fmapdif_mul[1] := TFileStream.Create(p + 'mapdif1.mul', (fmOpenRead or
      fmShareDenyNone));
    if fileexists(p + 'mapdif2.mul') then
      fmapdif_mul[2] := TFileStream.Create(p + 'mapdif2.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'mapdif3.mul') then
      fmapdif_mul[3] := TFileStream.Create(p + 'mapdif3.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'mapdif4.mul') then
      fmapdif_mul[4] := TFileStream.Create(p + 'mapdif4.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'mapdif5.mul') then
      fmapdif_mul[5] := TFileStream.Create(p + 'mapdif5.mul', (fmOpenRead or
        fmShareDenyNone));
  end;
  //equivalent to staidx.mul, just the overrides for it
  procedure openstadififiles;
  begin
    fstadifi_mul[0] := TFileStream.Create(p + 'stadifi0.mul', (fmOpenRead or
      fmShareDenyNone));
    fstadifi_mul[1] := TFileStream.Create(p + 'stadifi1.mul', (fmOpenRead or
      fmShareDenyNone));
    if fileexists(p + 'stadifi2.mul') then
      fstadifi_mul[2] := TFileStream.Create(p + 'stadifi2.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'stadifi3.mul') then
      fstadifi_mul[3] := TFileStream.Create(p + 'stadifi3.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'stadifi4.mul') then
      fstadifi_mul[4] := TFileStream.Create(p + 'stadifi4.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'stadifi5.mul') then
      fstadifi_mul[5] := TFileStream.Create(p + 'stadifi5.mul', (fmOpenRead or
        fmShareDenyNone));
  end;
  //equivalent to statics.mul, just the overrides for it
  procedure openstadiffiles;
  begin
    fstadif_mul[0] := TFileStream.Create(p + 'stadif0.mul', (fmOpenRead or
      fmShareDenyNone));
    fstadif_mul[1] := TFileStream.Create(p + 'stadif1.mul', (fmOpenRead or
      fmShareDenyNone));
    if fileexists(p + 'stadif2.mul') then
      fstadif_mul[2] := TFileStream.Create(p + 'stadif2.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'stadif3.mul') then
      fstadif_mul[3] := TFileStream.Create(p + 'stadif3.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'stadif4.mul') then
      fstadif_mul[4] := TFileStream.Create(p + 'stadif4.mul', (fmOpenRead or
        fmShareDenyNone));
    if fileexists(p + 'stadif5.mul') then
      fstadif_mul[5] := TFileStream.Create(p + 'stadif5.mul', (fmOpenRead or
        fmShareDenyNone));
  end;

begin
  inherited Create;
    Cst:=CstDB;
    if not (p[length(p)] = '\') then
      p := p + '\';
    openmapfiles;
    openstaidxfiles;
    openstaticsfiles;
    ftiledata_mul := TFileStream.Create(p + 'tiledata.mul', (fmOpenRead or
      fmShareDenyNone));
    fusedifdata := usedif;
    if fusedifdata then
    begin
      readmapdifblocks;
      openmapdiffiles;
      readstadifblocks;
      openstadififiles;
      openstadiffiles;
    end;
end;

{-----------------------------------------------------------------------------
  Procedure : BlockOverride
  Purpose   : Scan for [blocknumber] in the Tlist to check for 8x8blocks to
                override
              Uses binary search method
  Arguments : list:TList - The list to scan
              blocknumber:longword - The blocknumber to search
  Result    : posi:longword -> Position of the 8x8block in the dif files
              BlockOverride:boolean -> True if there is an override for the block
-----------------------------------------------------------------------------}
function TTTBasic.BlockOverride(var list:TList; blocknumber:longword;
  var posi:longword):boolean;
var
  L, H, I, C: Integer;
begin
  Result := False;
  if list = nil then exit;
  if (blocknumber > PListRecord(list.Last)^.blocknumber) or
    (blocknumber < PListRecord(list.First)^.blocknumber) then exit;
  if list = nil then Exit;
  L := 0;
  H := list.count - 1;
  while L <= H do
  begin
    I := (L + H) shr 1;
    C := PListRecord(list[I])^.blocknumber - blocknumber;
    if C < 0 then L := I + 1 else
    begin
      H := I - 1;
      if C = 0 then
      begin
        Result := True;
        L := I;
      end;
    end;
  end;
  posi := PListRecord(list[L])^.offset;
end;


{-----------------------------------------------------------------------------
  Procedure : GetBlockNumber
  Purpose   : This function is used to get the identifier of the 8x8 block a
                tile is in.
              Also checks if a tile is out of maprange, so it wont create
                blocknumbers that lead to exceeding the file size.
  Arguments : x, y:word - The worldcoordinates of the tile
              facet:byte - The facet of the tile
  Result    : BlockNumber:longword -> The Identifier of the 8x8Block
              GetBlockNumber:boolean -> Will be false in case of problems
-----------------------------------------------------------------------------}
function TTTBasic.GetBlockNumber(x, y:word; facet:byte; var BlockNumber:longword)
  :boolean;
begin
  result := false;
	case facet of
		0, 1:
      if (x<6144) and (y<4096) then
      begin
        BlockNumber := ((X div 8) * 512) + (Y div 8);
        result := true;
      end;
		2:
      if (x<2304) and (y<1600) then
      begin
			  BlockNumber := ((X div 8) * 200) + (Y div 8);
			  result := true;
      end;
		3:
      if (x<2560) and (y<2048) then
      begin
			  BlockNumber := ((X div 8) * 256) + (Y div 8);
			  result := true;
      end;
    4:
      if (x<1448) and (y<1448) then
      begin
			  BlockNumber := ((X div 8) * 181) + (Y div 8);
			  result := true;
      end;
    5:
      if (x<1280) and (y<4096) and EnableTerMur then
      begin
			  BlockNumber := ((X div 8) * 196) + (Y div 8);
			  result := true;
      end;

	end;
end;

{-----------------------------------------------------------------------------
  Procedure : GetLayerCount
  Purpose   : This function is used to count the layers on a single tile
  Arguments : x, y:word - The worldcoordinates of the tile
              facet:byte - The facet of the tile
  Result    : LayerCount:byte -> The amount of layers to be found on the tile
                without the map layer (map layer = layer 0)
              GetLayerCount:boolean -> Will be false in case of problems
-----------------------------------------------------------------------------}
function TTTBasic.GetLayerCount(x, y:word; facet:byte; var tilecnt:byte):boolean;
  //The counting function, it counts the layers without knowing if working in an
  //override file or not
  function CountLayers(var file1, file2:TFileStream; var tilecnt:byte):boolean;
  var
    staidx:TStaidx;
	  statics:TStatics;
	  i:word;
  begin
    if (file1.Read(staidx, 12) = 12) and not (staidx.start = $FFFFFFFF) then
    begin
      file2.Seek(staidx.start, soFromBeginning);
      for i := 1 to (staidx.len div 7) do
        if file2.Read(statics, 7) = 7 then
          if (statics.x = x) and (statics.y = y) then
            inc(tilecnt);
    end;
    result := true;
  end;
var
	blocknumber:longword;
  difpos:longword;
begin
	result := false;
  tilecnt := 0;
  if GetBlockNumber(x, y, facet, BlockNumber) then
  begin
    x := x mod 8; y := y mod 8;
    if fusedifdata and BlockOverride(fstadifblocks[facet], BlockNumber, difpos) then
    begin
      fstadifi_mul[facet].Seek(difpos * 12, soFromBeginning);
      result := CountLayers(fstadifi_mul[facet], fstadif_mul[facet], tilecnt);
    end
    else
    begin
      fstaidx_mul[facet].Seek(BlockNumber * 12, soFromBeginning);
      result := CountLayers(fstaidx_mul[facet], fstatics_mul[facet], tilecnt);
    end;
  end;
end;

{-----------------------------------------------------------------------------
  Procedure : GetTileData
  Purpose   : This function is used to get the altitude and type of a tile
  Arguments : x, y:word - The worldcoordinates of the tile
              facet:byte - The facet of the tile
              layer:byte - The layer of the tile
  Result    : TileType:word -> The TileType of the tile
              z:shortint -> The Altitude of the tile
              GetTileData:boolean -> Will be False in case of problems
-----------------------------------------------------------------------------}
function TTTBasic.GetTileData(x, y:word; facet:byte; layer:byte;
  var TileType:word; var tilez:shortint; var TileName:string;
  var tileflags:longword):boolean;
  //The TileData is stored in the statics or stadif.mul (layer > 0)
  //Works as with diffiles as with the normal files
  function FromSta(var file1, file2:TFileStream; var tiletype:word;
    var tilez:shortint):boolean;
  var
    staidx:TStaidx;
	  statics:TStatics;
	  i:word;
	  stopoffset:longword;
  begin
    result := false;
    if (file1.Read(staidx, 12) = 12) and not (staidx.start = $FFFFFFFF) then
    begin
      stopoffset := staidx.start + staidx.len;
      file2.Seek(staidx.start, soFromBeginning);
      for i := 1 to layer do
        repeat file2.Read(statics, 7);
        until ((statics.x = x) and (statics.y = y))
          or (file2.Position > stopoffset);
      if (file2.Position <= stopoffset) then
      begin
        TileType := statics.TileType;
        tilez := statics.z;
        result := true;
      end;
    end;
  end;
  //Take the TileData out of the mapfile (layer=0)
  //Works as with diffiles as with the normal files
  // file1 is TStream, not TFileStream, because its two callers below pass fmap_mul[]
  // (may be a UOP-backed TMemoryStream) and fmapdif_mul[] (always TFileStream) --
  // var parameters require the argument's DECLARED type to match exactly, and both
  // fields are declared TStream for exactly this reason (see this class' own field
  // comment). Both are read-only here regardless of the concrete class.
  function FromMap(var file1:TStream; var tiletype:word; var tilez:shortint)
    :boolean;
  var
	  map:TMap;
  begin
    file1.Read(map, 3);
    TileType := map.TileType;
    tilez := map.z;
    result := true;
  end;
var
	blocknumber:longword;
  difpos:longword;
  temptilename:array[0..19] of char;
  landdata_size : Cardinal;
  tiledata_size : Cardinal;
begin

  landdata_size := 26 + 4*(Cst.FFLAGS and 1);
  tiledata_size := 37 + 4*(Cst.FFLAGS and 1);

  result := false;
  if GetBlockNumber(x, y, facet, blocknumber) then
  begin
    x := x mod 8; y := y mod 8;
    if layer > 0 then
      begin
        if fusedifdata and BlockOverride(fstadifblocks[facet], BlockNumber, difpos) then
        begin
          fstadifi_mul[facet].Seek(difpos * 12, soFromBeginning);
          result := fromsta(fstadifi_mul[facet], fstadif_mul[facet], tiletype,
            tilez);
        end
        else
        begin
          fstaidx_mul[facet].Seek(blocknumber * 12, soFromBeginning);
          result := fromsta(fstaidx_mul[facet], fstatics_mul[facet], tiletype,
            tilez);
        end;
        ftiledata_mul.Seek(512*(4+32*landdata_size) + 4 * (1 + TileType div 32) + TileType * tiledata_size,
          soFromBeginning);
        ftiledata_mul.Read(tileflags, 4);
        ftiledata_mul.Seek(tiledata_size-24,soFromCurrent);
        ftiledata_mul.Read(temptilename, 20);
      end
      else
      begin
        if fusedifdata and BlockOverride(fmapdifblocks[facet], BlockNumber, difpos) then
        begin
          fmapdif_mul[facet].Seek(4 + (difpos * 196) + (y * 24) + (x * 3),
            soFromBeginning);
          result := frommap(fmapdif_mul[facet], tiletype, tilez);
        end
        else
        begin
          fmap_mul[facet].Seek(4 + (blocknumber * 196) + (y * 24) + (x * 3),
            soFromBeginning);
          result := frommap(fmap_mul[facet], tiletype, tilez);
        end;
        ftiledata_mul.Seek(4 * (1 + TileType div 32) + (TileType * landdata_size),
          soFromBeginning);
        ftiledata_mul.Read(tileflags, 4);
        ftiledata_mul.Seek(landdata_size-24, soFromCurrent);
        ftiledata_mul.Read(temptilename, 20);
      end;
    tilename := trim(temptilename);
  end;
end;




{function TTTBasic.GetTileTypeInfo(tiletype:word; static:boolean;
  var TileName:string; var tileflags:longword):boolean;
var temptilename:array[0..19] of char;
begin
  result := false;
  if static then
  begin
    ftiledata_mul.Seek($68800 + 4 * (1 + TileType div 32) + TileType * 37,
      soFromBeginning);
    ftiledata_mul.Read(tileflags, 4);
    ftiledata_mul.Seek(13, soFromCurrent);
    ftiledata_mul.Read(temptilename, 20);
  end
  else
  begin
    ftiledata_mul.Seek(4 * (1 + TileType div 32) + (TileType * 26),
      soFromBeginning);
    ftiledata_mul.Read(tileflags, 4);
    ftiledata_mul.Seek(2, soFromCurrent);
    ftiledata_mul.Read(temptilename, 20);
  end;
  tilename := trim(temptilename);
end;}






//Before destroying free everything ....
destructor TTTBasic.destroy;
var i:byte;
    j:word;
begin
  ftiledata_mul.free;
  for i := 0 to 5 do
  begin
    fmap_mul[i].free;
    fstaidx_mul[i].free;
    fstatics_mul[i].free;
    fmapdif_mul[i].free;
    fstadifi_mul[i].free;
    fstadif_mul[i].free;
    if fmapdifblocks[i] <> nil then
    begin
      for j := 0 to fmapdifblocks[i].Count - 1 do
        dispose(PListRecord(fmapdifblocks[i][j]));
      fmapdifblocks[i].free;
    end;
    if fstadifblocks[i] <> nil then
    begin
      for j := 0 to fstadifblocks[i].Count - 1 do
        dispose(PListRecord(fstadifblocks[i][j]));
      fstadifblocks[i].free;
    end;
  end;
  inherited destroy;
end;

end.
