<#
  Generates a minimal synthetic UO client-data fixture set for TilesTests.pas, using
  the SAME offset formulas as the ported tiles.pas (computed here independently in
  PowerShell, not copy-pasted, as a cross-check) so the fixture and the test's
  expectations are both grounded in the documented .mul file format, not in whatever
  the Pascal code happens to do.

  Target tile: facet 0, world (x=3, y=2) -> block 0 (block = (x div 8)*512 + (y div 8)).
    Layer 0 (map):     TileType=100, z=5,  name="TestLand",    flags=$12345678
    Layer 1 (statics): TileType=200, z=10, name="TestStatic1", flags=$00000001
    Layer 2 (statics): TileType=201, z=11, name="TestStatic2", flags=$00000002
  Plus one statics entry at a DIFFERENT tile (x=5,y=5) in the same block, to prove
  GetLayerCount/GetTileData correctly filter by (x,y) and don't over-count.

  usedif=False is used in the tests, so no *dif*.mul override files are needed.
#>

$ErrorActionPreference = 'Stop'
# tests\fixtures\mul, relative to this script (tests\tools\).
$Dir = Join-Path (Split-Path $PSScriptRoot -Parent) 'fixtures\mul'
New-Item -ItemType Directory -Force -Path $Dir | Out-Null

function WriteBytesAt([byte[]]$buf, [int]$offset, [byte[]]$data) {
    for ($i = 0; $i -lt $data.Length; $i++) { $buf[$offset + $i] = $data[$i] }
}
function W16([UInt16]$v) { [BitConverter]::GetBytes($v) }
function W32([UInt32]$v) { [BitConverter]::GetBytes($v) }
function W8([byte]$v)    { , $v }
function WName([string]$s, [int]$len = 20) {
    $b = New-Object byte[] $len
    $enc = [System.Text.Encoding]::ASCII.GetBytes($s)
    [Array]::Copy($enc, $b, [Math]::Min($enc.Length, $len))
    return $b
}

# ---- map0.mul: one 196-byte block (4-byte header + 64*3-byte tiles) ----
$map = New-Object byte[] 196
# local (x=3,y=2) within the block -> offset 4 + y*24 + x*3 = 4 + 48 + 9 = 61
$off = 4 + 2*24 + 3*3
WriteBytesAt $map $off (W16 100)         # TileType
WriteBytesAt $map ($off+2) (W8 5)        # z (shortint 5)
[IO.File]::WriteAllBytes("$Dir\map0.mul", $map)

# ---- staidx0.mul: one 12-byte entry for block 0 -> start=0,len=21 (3*7 bytes) into statics0.mul ----
$staidx = New-Object byte[] 12
WriteBytesAt $staidx 0 (W32 0)     # start
WriteBytesAt $staidx 4 (W32 21)    # len = 3 entries * 7 bytes
WriteBytesAt $staidx 8 (W32 0)     # unknown
[IO.File]::WriteAllBytes("$Dir\staidx0.mul", $staidx)

# ---- statics0.mul: 3 packed 7-byte TStatics entries (word TileType, byte x, byte y, shortint z, word hue) ----
function StaticsEntry([UInt16]$tt, [byte]$x, [byte]$y, [byte]$z) {
    $e = New-Object byte[] 7
    WriteBytesAt $e 0 (W16 $tt)
    $e[2] = $x
    $e[3] = $y
    $e[4] = $z
    WriteBytesAt $e 5 (W16 0)   # hue (unused by any caller -- see tiles.pas header comment)
    return $e
}
$statics = New-Object byte[] 0
$statics += StaticsEntry 200 3 2 10   # layer 1 at (3,2)
$statics += StaticsEntry 201 3 2 11   # layer 2 at (3,2)
$statics += StaticsEntry 999 5 5 99   # different tile in the same block -- must NOT count for (3,2)
[IO.File]::WriteAllBytes("$Dir\statics0.mul", $statics)

# ---- tiledata.mul: FFLAGS=0 -> landdata_size=26, tiledata_size=37 ----
# Land region size = 512 groups * 32 tiles/group * 26 bytes = 425984, preceded by that
# many bytes of per-group 4-byte headers folded into the same seek formula.
$landDataSize = 26
$tileDataSize = 37
$landRegionBytes = 512 * (4 + 32 * $landDataSize)   # exact size tiles.pas seeks past for statics
$totalSize = $landRegionBytes + 4 * (1 + [Math]::Floor(201.0/32)) + 201 * $tileDataSize + $tileDataSize + 64
$td = New-Object byte[] $totalSize

# Land entry for TileType=100: offset = 4*(1 + 100 div 32) + 100*landDataSize
$landOff = 4 * (1 + [Math]::Floor(100.0/32)) + 100 * $landDataSize
WriteBytesAt $td $landOff (W32 0x12345678)                       # flags
WriteBytesAt $td ($landOff + ($landDataSize - 20)) (WName "TestLand")   # name occupies the LAST 20 bytes of the entry

# Static entry for TileType=200: offset = landRegionBytes + 4*(1+200 div 32) + 200*tileDataSize
$stat200Off = $landRegionBytes + 4 * (1 + [Math]::Floor(200.0/32)) + 200 * $tileDataSize
WriteBytesAt $td $stat200Off (W32 0x00000001)
WriteBytesAt $td ($stat200Off + ($tileDataSize - 20)) (WName "TestStatic1")

# Static entry for TileType=201: offset = landRegionBytes + 4*(1+201 div 32) + 201*tileDataSize
$stat201Off = $landRegionBytes + 4 * (1 + [Math]::Floor(201.0/32)) + 201 * $tileDataSize
WriteBytesAt $td $stat201Off (W32 0x00000002)
WriteBytesAt $td ($stat201Off + ($tileDataSize - 20)) (WName "TestStatic2")

[IO.File]::WriteAllBytes("$Dir\tiledata.mul", $td)

Write-Host "Fixtures written to $Dir"
Write-Host ("  map0.mul      {0} bytes" -f $map.Length)
Write-Host ("  staidx0.mul   {0} bytes" -f $staidx.Length)
Write-Host ("  statics0.mul  {0} bytes" -f $statics.Length)
Write-Host ("  tiledata.mul  {0} bytes (land@{1} static200@{2} static201@{3})" -f $td.Length, $landOff, $stat200Off, $stat201Off)
