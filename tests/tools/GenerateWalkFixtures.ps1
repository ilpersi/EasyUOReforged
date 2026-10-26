<#
  Generates the synthetic client-data fixture set for WalkMapTests.pas (uo\walkmap.pas, the
  pathfinder's world model) into tests\fixtures\walk. Every offset is computed here from the
  documented .mul formats, independently of the Pascal reader, as a cross-check.

  Facet 4 (Tokuno: 181 blocks per column) with ONE column of blocks, so the map is 8 tiles
  wide and 1448 high: map4.mul is 181 blocks of 196 bytes (4-byte header, then 64 cells of
  graphic:uint16 z:sbyte, cell = y*8 + x), staidx4.mul 181 entries of 12 bytes (start, length,
  extra; start $FFFFFFFF = no statics), statics4.mul records of 7 bytes (graphic:uint16, x, y
  inside the block, z:sbyte, hue:uint16).

  Land: grass (graphic 3, texture 1) at z 0 everywhere, except
    (5,2)  water (graphic $A8: Wet|Impassable, no texture), z -5
    (6,2)  a void tile (graphic 2)
    block 2 (y 16..23): a slope rising east, z = x*4
  Statics:
    (3,4)   wall  (graphic 1: Impassable, height 20) at z 0
    (4,4)   stair (graphic 3: Surface|Bridge, height 5) at z 5
    (1,10)  floor (graphic 2: Surface, height 0) at z 20, and a decoration (graphic 4:
            Background only, height 3) at z 0, which the pathfinder ignores

  tiledata.mul in the NEW format (64-bit flags): 512 land groups of (4-byte header + 32 x 30
  bytes: flags:uint64, texture:uint16, name[20]), then one static group of (4 + 32 x 41 bytes:
  flags:uint64, weight, quality, misc:uint16, unk, quantity, anim:uint16, unk, hue, stacking,
  value, height, name[20]). Some flags carry a bit above 31, which must not matter (the reader
  keeps the low 32 bits).

  texidx.mul: entry 0 missing (offset -1), entry 1 present.

  Dif files (read only with dif files on):
    mapdifl4/mapdif4.mul override block 0 with grass at z 7.
    stadifl4/stadifi4/stadif4.mul override block 1 with a single wall at (1,10) z 0.
#>

$ErrorActionPreference = 'Stop'
$Dir = Join-Path (Split-Path $PSScriptRoot -Parent) 'fixtures\walk'
New-Item -ItemType Directory -Force -Path $Dir | Out-Null

$BlocksY = 181

function WriteFile([string]$name, [byte[]]$bytes) {
    [System.IO.File]::WriteAllBytes((Join-Path $Dir $name), $bytes)
}

function U16([int]$v) { [BitConverter]::GetBytes([uint16]($v -band 0xFFFF)) }
function U32([long]$v) { [BitConverter]::GetBytes([uint32]($v -band 0xFFFFFFFFL)) }
function U64([UInt64]$v) { [BitConverter]::GetBytes($v) }
function Name20([string]$s) {
    $b = New-Object byte[] 20
    $a = [Text.Encoding]::ASCII.GetBytes($s)
    [Array]::Copy($a, $b, [Math]::Min($a.Length, 20))
    $b
}
function Put([byte[]]$buf, [int]$offset, [byte[]]$data) {
    [Array]::Copy($data, 0, $buf, $offset, $data.Length)
}

# --- tiledata.mul (new format) ----------------------------------------------------------
$LandRec = 30
$StaticRec = 41
$LandSection = 512 * (4 + 32 * $LandRec)
$Tiledata = New-Object byte[] ($LandSection + 4 + 32 * $StaticRec)

function LandEntry([int]$id, [UInt64]$flags, [int]$tex, [string]$name) {
    $off = 4 * ([Math]::Floor($id / 32) + 1) + $id * $LandRec
    Put $Tiledata $off (U64 $flags)
    Put $Tiledata ($off + 8) (U16 $tex)
    Put $Tiledata ($off + 10) (Name20 $name)
}
function StaticEntry([int]$id, [UInt64]$flags, [int]$height, [string]$name) {
    $off = $LandSection + 4 * ([Math]::Floor($id / 32) + 1) + $id * $StaticRec
    Put $Tiledata $off (U64 $flags)
    $Tiledata[$off + 8 + 12] = [byte]$height          # after weight..value (12 bytes)
    Put $Tiledata ($off + 8 + 13) (Name20 $name)
}

LandEntry 2 0 0 'void'
LandEntry 3 0x100000000 1 'grass'                      # bit 32 set: must be ignored
LandEntry 0xA8 0xC0 0 'water'                          # Wet | Impassable
StaticEntry 1 0x10000000040 20 'wall'                  # Impassable (+ bit 40)
StaticEntry 2 0x200 0 'floor'                          # Surface
StaticEntry 3 0x600 5 'stair'                          # Surface | Bridge
StaticEntry 4 0x1 3 'decoration'                       # Background only
WriteFile 'tiledata.mul' $Tiledata

# --- texidx.mul ---------------------------------------------------------------------------
$Tex = New-Object byte[] 24
Put $Tex 0 (U32 0xFFFFFFFF)                            # entry 0: no texture
Put $Tex 12 (U32 0)                                    # entry 1: offset 0, length 8192
Put $Tex 16 (U32 8192)
WriteFile 'texidx.mul' $Tex

# --- map4.mul -------------------------------------------------------------------------------
$Map = New-Object byte[] ($BlocksY * 196)
function SetLand([byte[]]$buf, [int]$block, [int]$x, [int]$y, [int]$graphic, [int]$z) {
    $off = $block * 196 + 4 + ($y * 8 + $x) * 3
    Put $buf $off (U16 $graphic)
    $buf[$off + 2] = [byte]($z -band 0xFF)
}
for ($b = 0; $b -lt $BlocksY; $b++) {
    for ($y = 0; $y -lt 8; $y++) { for ($x = 0; $x -lt 8; $x++) { SetLand $Map $b $x $y 3 0 } }
}
SetLand $Map 0 5 2 0xA8 -5
SetLand $Map 0 6 2 2 0
for ($y = 0; $y -lt 8; $y++) { for ($x = 0; $x -lt 8; $x++) { SetLand $Map 2 $x $y 3 ($x * 4) } }
WriteFile 'map4.mul' $Map

# --- staidx4.mul / statics4.mul -------------------------------------------------------------
function StaticRecord([int]$graphic, [int]$x, [int]$y, [int]$z) {
    $r = New-Object byte[] 7
    Put $r 0 (U16 $graphic)
    $r[2] = [byte]$x
    $r[3] = [byte]$y
    $r[4] = [byte]($z -band 0xFF)
    $r
}
$Block0 = (StaticRecord 1 3 4 0) + (StaticRecord 3 4 4 5)
$Block1 = (StaticRecord 2 1 2 20) + (StaticRecord 4 1 2 0)   # (1,10) is local (1,2) of block 1
$Statics = [byte[]]($Block0 + $Block1)
WriteFile 'statics4.mul' $Statics

$Idx = New-Object byte[] ($BlocksY * 12)
for ($b = 0; $b -lt $BlocksY; $b++) { Put $Idx ($b * 12) (U32 0xFFFFFFFF) }
Put $Idx 0 (U32 0)
Put $Idx 4 (U32 $Block0.Length)
Put $Idx 12 (U32 $Block0.Length)
Put $Idx 16 (U32 $Block1.Length)
WriteFile 'staidx4.mul' $Idx

# --- dif files ---------------------------------------------------------------------------------
WriteFile 'mapdifl4.mul' (U32 0)
$MapDif = New-Object byte[] 196
for ($y = 0; $y -lt 8; $y++) { for ($x = 0; $x -lt 8; $x++) { SetLand $MapDif 0 $x $y 3 7 } }
WriteFile 'mapdif4.mul' $MapDif

WriteFile 'stadifl4.mul' (U32 1)
$DifRec = StaticRecord 1 1 2 0
WriteFile 'stadif4.mul' $DifRec
WriteFile 'stadifi4.mul' ([byte[]]((U32 0) + (U32 $DifRec.Length) + (U32 0)))

Write-Host "Wrote walk fixtures to $Dir"
