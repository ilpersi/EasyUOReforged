# Writes tests\fixtures\gumpreply\replies.txt: the $B1 gump answers exevent GumpReply must send, built
# here from the client's layout (docs\gump-analysis.md section 11) and NOT from the Pascal code, as a
# cross-check of uo\uogumpreply.pas (GumpReplyTests reads the file).
#
# Each case gives the words a script writes after the gump, and next to them, spelled out plainly, what
# those words mean: the button, the switches and each text as the server must see it. The packet:
#   $B1, length (2 bytes, low byte first, as the client's packet builder keeps it), serial, type ID,
#   button, switch count, switch IDs, text count, then per text its ID (2), its length in characters (2)
#   and its UTF-16 characters, everything after the length big-endian. A text is cut at 239 characters.
#
# Line format (UTF-8): name|serial hex|type ID hex|words|packet hex

$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot '..\fixtures\gumpreply'
New-Item -ItemType Directory -Force $out | Out-Null

function BE([uint64]$v, [int]$n) {
  $b = New-Object byte[] $n
  for ($i = $n - 1; $i -ge 0; $i--) { $b[$i] = [byte]($v -band 0xFF); $v = $v -shr 8 }
  return ,$b
}

function Packet([uint32]$serial, [uint32]$type, [uint32]$button, [uint32[]]$switches, $texts) {
  $body = New-Object System.Collections.Generic.List[byte]
  $body.AddRange((BE $serial 4)); $body.AddRange((BE $type 4)); $body.AddRange((BE $button 4))
  $body.AddRange((BE $switches.Count 4))
  foreach ($s in $switches) { $body.AddRange((BE $s 4)) }
  $body.AddRange((BE $texts.Count 4))
  foreach ($t in $texts) {
    $txt = [string]$t[1]
    if ($txt.Length -gt 239) { $txt = $txt.Substring(0, 239) }
    $body.AddRange((BE $t[0] 2)); $body.AddRange((BE $txt.Length 2))
    $body.AddRange([Text.Encoding]::BigEndianUnicode.GetBytes($txt))
  }
  $len = $body.Count + 3
  $p = New-Object System.Collections.Generic.List[byte]
  $p.Add(0xB1); $p.Add([byte]($len -band 0xFF)); $p.Add([byte](($len -shr 8) -band 0xFF))
  $p.AddRange($body)
  return ($p | ForEach-Object { $_.ToString('X2') }) -join ''
}

$x300 = 'x' * 300
$cases = @(
  # name, serial, type, words, button, switches, texts (id, text)
  @('close',      0x0E, 0x9E26D92Du, '0 -',                        0, @(),                 @()),
  @('closeshort', 0x0E, 0x9E26D92Du, '0',                          0, @(),                 @()),
  @('switches',   0x10, 0x9ECCBC5Cu, '1 3/7',                      1, @(3, 7),             @()),
  @('texts',      0x10, 0x9ECCBC5Cu, '1 3/7 5:hello_world 6:',     1, @(3, 7),             @(@(5, 'hello world'), @(6, ''))),
  @('textsonly',  0x11, 0x2410,     '7 5:x',                      7, @(),                 @(,@(5, 'x'))),
  @('escapes',    0x12, 0x1,        '2 - 1:a\_b\\c 2:50%_off;_see,_more.',
                                                                  2, @(),                 @(@(1, 'a_b\c'), @(2, '50% off; see, more.'))),
  @('control',    0x13, 0x1,        '3 - 4:tab\09here',           3, @(),                 @(,@(4, "tab`there"))),
  @('unicode',    0x14, 0x1,        "4 - 3:caf$([char]0xE9)_$([char]0xFC)",
                                                                  4, @(),                 @(,@(3, "caf$([char]0xE9) $([char]0xFC)"))),
  @('long',       0x15, 0x1,        "5 - 9:$x300",                5, @(),                 @(,@(9, $x300))),
  @('bignumbers', 0xFFFFFFFFu, 0xFFFFFFFFu, '4294967295 1/4294967295 65535:z',
                                                                  4294967295, @(1, 4294967295), @(,@(65535, 'z')))
)

$lines = foreach ($c in $cases) {
  $hex = Packet $c[1] $c[2] $c[4] ([uint32[]]$c[5]) $c[6]
  '{0}|{1:X8}|{2:X8}|{3}|{4}' -f $c[0], $c[1], $c[2], $c[3], $hex
}
$file = Join-Path $out 'replies.txt'
[IO.File]::WriteAllLines($file, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
Write-Host "wrote $file ($($lines.Count) cases)"
