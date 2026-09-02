<#
  Generates tests\fixtures\uop -- the same tiny synthetic tile data GenerateMulFixtures.ps1
  produces, but with map0.mul repackaged into a minimal, valid MythicPackage (.uop)
  container (map0LegacyMUL.uop) and NO map0.mul present at all, so TilesTests.pas can
  exercise TTTBasic's classic-preferred/UOP-fallback path (see tiles.pas's own
  openmapfiles comment and uopfile.pas) end to end against a real, from-scratch-built
  container -- not just the one real file on this machine the feature was originally
  validated against.

  The UOP header/block-table layout and the HashLittle2 name-hash algorithm are both
  implemented HERE independently (not copied from uopfile.pas's Pascal source), matching
  this script's own sibling's stated cross-check philosophy: fixture and implementation
  are two separate implementations of the same documented format, so a bug in one is very
  unlikely to be mirrored by an identical bug in the other. HashLittle2 here is itself a
  THIRD independent implementation of Bob Jenkins' lookup3.c hashlittle2, after uopfile.pas's
  Pascal port and the Python prototype used to validate it against a real file during
  development -- if all three agree (they do: this script's own output round-trips
  correctly through TilesTests' new UOP-fixture test), that's strong, not just plausible,
  confidence the algorithm is right.

  Depends on GenerateMulFixtures.ps1 having already been run (reuses its map0.mul as the
  payload to repackage, and expects staidx0.mul/statics0.mul/tiledata.mul to already exist
  in the same shape).

  Usage: pwsh -File GenerateMulFixtures.ps1 ; pwsh -File GenerateUopFixture.ps1
#>

$ErrorActionPreference = 'Stop'
$MulDir = "D:\Dropbox\Delphi\EasyUOLazarus\Lazarus\tests\fixtures\mul"
$UopDir = "D:\Dropbox\Delphi\EasyUOLazarus\Lazarus\tests\fixtures\uop"
New-Item -ItemType Directory -Force -Path $UopDir | Out-Null

foreach ($f in 'staidx0.mul', 'statics0.mul', 'tiledata.mul') {
    Copy-Item -LiteralPath (Join-Path $MulDir $f) -Destination (Join-Path $UopDir $f) -Force
}

# ---- HashLittle2 (Bob Jenkins' lookup3.c), independent PowerShell port ----
# All arithmetic done in UInt64 with an explicit -band 0xFFFFFFFF mask after every
# add/subtract, rather than UInt32 directly -- PowerShell's own arithmetic operators
# promote through a signed intermediate type first, so casting a wrapped-around
# UInt32-range computation straight back to [UInt32] throws ("value was either too
# large or too small") the moment a subtraction goes negative. Masking in UInt64 space
# sidesteps that entirely and is exactly equivalent to real 32-bit unsigned wraparound.
$M32 = [UInt64]4294967295   # 0xFFFFFFFF -- written in decimal since PowerShell parses the
                            # hex literal 0xFFFFFFFF as a (negative) Int32 first, which
                            # then fails to convert straight to UInt64
function Rot32([UInt64]$x, [int]$k) {
    return (($x -shl $k) -bor ($x -shr (32 - $k))) -band $M32
}
function HashLittle2([byte[]]$data, [UInt64]$initval) {
    $length = [UInt64]$data.Length
    $a = ([UInt64]3735928559 + $length + $initval) -band $M32   # 0xdeadbeef, in decimal for the same reason as $M32 above
    $b = $a
    $c = ($a + $initval) -band $M32

    $off = 0
    $len = $data.Length
    while ($len -gt 12) {
        $a = ($a + $data[$off+0] + ([UInt64]$data[$off+1] -shl 8) + ([UInt64]$data[$off+2] -shl 16) + ([UInt64]$data[$off+3] -shl 24)) -band $M32
        $b = ($b + $data[$off+4] + ([UInt64]$data[$off+5] -shl 8) + ([UInt64]$data[$off+6] -shl 16) + ([UInt64]$data[$off+7] -shl 24)) -band $M32
        $c = ($c + $data[$off+8] + ([UInt64]$data[$off+9] -shl 8) + ([UInt64]$data[$off+10] -shl 16) + ([UInt64]$data[$off+11] -shl 24)) -band $M32

        $a = ($a - $c) -band $M32; $a = $a -bxor (Rot32 $c 4);  $c = ($c + $b) -band $M32
        $b = ($b - $a) -band $M32; $b = $b -bxor (Rot32 $a 6);  $a = ($a + $c) -band $M32
        $c = ($c - $b) -band $M32; $c = $c -bxor (Rot32 $b 8);  $b = ($b + $a) -band $M32
        $a = ($a - $c) -band $M32; $a = $a -bxor (Rot32 $c 16); $c = ($c + $b) -band $M32
        $b = ($b - $a) -band $M32; $b = $b -bxor (Rot32 $a 19); $a = ($a + $c) -band $M32
        $c = ($c - $b) -band $M32; $c = $c -bxor (Rot32 $b 4);  $b = ($b + $a) -band $M32

        $len -= 12
        $off += 12
    }

    $tail = New-Object byte[] 12
    if ($len -gt 0) { [Array]::Copy($data, $off, $tail, 0, $len) }

    if ($len -eq 0) { return @($c, $b) }

    if ($len -ge 12) { $c = ($c + ([UInt64]$tail[11] -shl 24)) -band $M32 }
    if ($len -ge 11) { $c = ($c + ([UInt64]$tail[10] -shl 16)) -band $M32 }
    if ($len -ge 10) { $c = ($c + ([UInt64]$tail[9] -shl 8)) -band $M32 }
    if ($len -ge 9)  { $c = ($c + $tail[8]) -band $M32 }
    if ($len -ge 8)  { $b = ($b + ([UInt64]$tail[7] -shl 24)) -band $M32 }
    if ($len -ge 7)  { $b = ($b + ([UInt64]$tail[6] -shl 16)) -band $M32 }
    if ($len -ge 6)  { $b = ($b + ([UInt64]$tail[5] -shl 8)) -band $M32 }
    if ($len -ge 5)  { $b = ($b + $tail[4]) -band $M32 }
    if ($len -ge 4)  { $a = ($a + ([UInt64]$tail[3] -shl 24)) -band $M32 }
    if ($len -ge 3)  { $a = ($a + ([UInt64]$tail[2] -shl 16)) -band $M32 }
    if ($len -ge 2)  { $a = ($a + ([UInt64]$tail[1] -shl 8)) -band $M32 }
    $a = ($a + $tail[0]) -band $M32

    $c = $c -bxor $b; $c = ($c - (Rot32 $b 14)) -band $M32
    $a = $a -bxor $c; $a = ($a - (Rot32 $c 11)) -band $M32
    $b = $b -bxor $a; $b = ($b - (Rot32 $a 25)) -band $M32
    $c = $c -bxor $b; $c = ($c - (Rot32 $b 16)) -band $M32
    $a = $a -bxor $c; $a = ($a - (Rot32 $c 4)) -band $M32
    $b = $b -bxor $a; $b = ($b - (Rot32 $a 14)) -band $M32
    $c = $c -bxor $b; $c = ($c - (Rot32 $b 24)) -band $M32

    return @($c, $b)
}
function UopHash([string]$name) {
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($name)
    $r = HashLittle2 $bytes ([UInt64]0)
    return [UInt64](($r[1] -shl 32) -bor $r[0])
}

# ---- Build the container: header + one block (1 entry) + the entry's raw (Flag=0) data ----
$payload = [IO.File]::ReadAllBytes((Join-Path $MulDir 'map0.mul'))   # 196 bytes, Flag=0 (stored)
$entryName = 'build/map0legacymul/00000000.dat'
$hash = UopHash $entryName

# Layout: [0..27] header (28 bytes) ; [28..] block table ; [after that] raw payload.
$headerLen = 28
$blockTableOffset = $headerLen
$blockHeaderLen = 12       # EntryCount:UInt32 + NextBlockOffset:Int64
$entryLen = 34             # DataOffset:Int64 + HeaderLength:UInt32 + CompressedSize:UInt32
                            # + DecompressedSize:UInt32 + Hash:UInt64 + DataCRC:UInt32 + Flag:UInt16
$dataOffset = $blockTableOffset + $blockHeaderLen + $entryLen

$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter($ms)

# Header
$bw.Write([byte[]][char[]]'MYP')            # 'MYP'
$bw.Write([byte]0)                          # trailing NUL of the 4-byte magic
$bw.Write([UInt32]5)                        # version (matches the real file's own value)
$bw.Write([UInt32]0)                        # misc/build-signature -- unused by the reader
$bw.Write([Int64]$blockTableOffset)         # first block-table offset
$bw.Write([UInt32]1)                        # block size (entries/block) -- unused by the reader
$bw.Write([UInt32]1)                        # file count -- unused by the reader (walks by hash)

# Block table: 1 block, 1 entry, no next block
$bw.Write([UInt32]1)                        # entry count in this block
$bw.Write([Int64]0)                         # next block offset (0 = end of chain)
$bw.Write([Int64]$dataOffset)               # entry.DataOffset
$bw.Write([UInt32]0)                        # entry.HeaderLength (no per-entry header, data starts right at DataOffset)
$bw.Write([UInt32]$payload.Length)          # entry.CompressedSize
$bw.Write([UInt32]$payload.Length)          # entry.DecompressedSize (Flag=0 -> same as compressed)
$bw.Write([UInt64]$hash)                    # entry.Hash
$bw.Write([UInt32]0)                        # entry.DataCRC -- unused by the reader
$bw.Write([UInt16]0)                        # entry.CompressionFlag = 0 (stored raw)

# Payload
$bw.Write($payload)

$bw.Flush()
$bytes = $ms.ToArray()
[IO.File]::WriteAllBytes((Join-Path $UopDir 'map0LegacyMUL.uop'), $bytes)

Write-Host "Fixture written to $UopDir"
Write-Host ("  map0LegacyMUL.uop  {0} bytes (entry '{1}' hash=0x{2:X16} at offset {3})" -f `
    $bytes.Length, $entryName, $hash, $dataOffset)
Write-Host "  staidx0.mul / statics0.mul / tiledata.mul copied from $MulDir unchanged"
