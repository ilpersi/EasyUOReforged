# Maps the perf_samples_<workload>.txt files written by PerfBenchTests (sampler enabled with
# EUO_PERF_SAMPLE=1) to routine names and prints a flat profile per workload.
#
# The sampler records instruction-pointer RVAs. Routine names come from the COFF symbol table of
# the benchmark exe (RunBench.exe is built with -g), read with the objdump that ships with FPC:
# a symbol in section 1 (.text) lives at RVA = <.text VMA - ImageBase> + <symbol value>.
param(
  [Parameter(Mandatory)][string]$Exe,
  [int]$Top = 25
)

$ErrorActionPreference = 'Stop'

function Find-ObjDump {
  $cmd = Get-Command objdump -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($d in $env:LAZARUS_DIR, 'C:\Lazarus', "$env:ProgramFiles\Lazarus", 'D:\Program Files\Lazarus') {
    if (-not $d) { continue }
    $p = Get-ChildItem (Join-Path $d 'fpc') -Recurse -Filter objdump.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { return $p.FullName }
  }
  throw 'objdump.exe not found (it ships with Lazarus under fpc\<ver>\bin\<target>).'
}

$ObjDump = Find-ObjDump

# .text section RVA = VMA - ImageBase. objdump -p prints the ImageBase.
$imageBase = $null
foreach ($l in (& $ObjDump -p $Exe)) {
  if ($l -match '^ImageBase\s+([0-9a-fA-F]+)') { $imageBase = [Convert]::ToUInt64($matches[1], 16); break }
}
$textVma = $null
foreach ($l in (& $ObjDump -h $Exe)) {
  if ($l -match '^\s*\d+\s+\.text\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)') { $textVma = [Convert]::ToUInt64($matches[1], 16); break }
}
if ($null -eq $imageBase -or $null -eq $textVma) { throw "Could not read ImageBase/.text from $Exe" }
$textRva = $textVma - $imageBase

# Symbol table: only .text (sec 1) symbols.
$syms = New-Object System.Collections.Generic.List[object]
foreach ($l in (& $ObjDump -t $Exe)) {
  if ($l -match '\(sec\s+1\)\(fl .*?\) \(nx \d+\) 0x([0-9a-fA-F]+) (\S+)$') {
    $name = $matches[2]
    if ($name.StartsWith('.') -or $name.StartsWith('$')) { continue }
    $syms.Add([pscustomobject]@{ Rva = $textRva + [Convert]::ToUInt64($matches[1], 16); Name = $name })
  }
}
$sorted = $syms | Sort-Object Rva
$rvas = [uint64[]]($sorted | ForEach-Object { $_.Rva })
$names = [string[]]($sorted | ForEach-Object { $_.Name })

function Tidy([string]$n) {
  # FPC mangling: UNIT$_$CLASS_$__$$_METHOD$PARAMS -> UNIT.CLASS.METHOD
  $n = $n -replace '\$_\$', '.' -replace '_\$__\$\$_', '.' -replace '\$\$_', '.'
  $n = $n -replace '\$.*$', ''
  $n
}

function Resolve-Rva([uint64]$rva) {
  $i = [Array]::BinarySearch($rvas, $rva)
  if ($i -lt 0) { $i = (-bnot $i) - 1 }
  if ($i -lt 0) { return '<before .text>' }
  Tidy $names[$i]
}

# Samples outside the exe (ntdll, kernel32, ...) are keyed "<module path>|<RVA>". Name them by the
# nearest preceding export of that DLL -- coarse (only exported routines have names), but enough
# to tell "waiting in a lock" from "allocating" from "in a syscall stub".
$modCache = @{}
function Get-ModuleExports([string]$path) {
  if ($modCache.ContainsKey($path)) { return $modCache[$path] }
  $eat = @{}
  $nameOf = @{}
  $section = ''
  # objdump.exe is a 32-bit program: handed C:\Windows\System32\x.dll, Windows' file-system
  # redirection silently gives it the 32-bit copy from SysWOW64 and every RVA is wrong. This
  # (64-bit) PowerShell sees the real file, so copy it somewhere neutral first.
  $copyDir = Join-Path $env:TEMP 'euo_perf_mods'
  New-Item -ItemType Directory -Force $copyDir | Out-Null
  $local = Join-Path $copyDir (Split-Path $path -Leaf)
  Copy-Item $path $local -Force
  foreach ($l in (& $ObjDump -p $local)) {
    if ($l -match '^Export Address Table --') { $section = 'eat'; continue }
    if ($l -match '^\[Ordinal/Name Pointer\] Table') { $section = 'names'; continue }
    if ($section -eq 'eat' -and $l -match '\[\s*(\d+)\]\s+\+base\[\s*\d+\]\s+([0-9a-fA-F]+) Export RVA') {
      $eat[[int]$matches[1]] = [Convert]::ToUInt64($matches[2], 16)
    } elseif ($section -eq 'names' -and $l -match '^\s*\[\s*(\d+)\]\s+(\S+)\s*$') {
      $nameOf[[int]$matches[1]] = $matches[2]
    }
  }
  $list = foreach ($k in $nameOf.Keys) { if ($eat.ContainsKey($k)) { [pscustomobject]@{ Rva = $eat[$k]; Name = $nameOf[$k] } } }
  $s = @($list | Sort-Object Rva)
  $r = [pscustomobject]@{
    Rvas  = [uint64[]]@($s | ForEach-Object { $_.Rva })
    Names = [string[]]@($s | ForEach-Object { $_.Name })
  }
  $modCache[$path] = $r
  $r
}

function Resolve-Key([string]$key) {
  if ($key -notmatch '\|') { return Resolve-Rva ([Convert]::ToUInt64($key, 16)) }
  $mod, $hex = $key -split '\|', 2
  $rva = [Convert]::ToUInt64($hex, 16)
  $ex = Get-ModuleExports $mod
  $i = [Array]::BinarySearch($ex.Rvas, $rva)
  if ($i -lt 0) { $i = (-bnot $i) - 1 }
  $leaf = Split-Path $mod -Leaf
  if ($i -lt 0) { return "$leaf!<unknown>" }
  "$leaf!" + $ex.Names[$i]
}

function Show-Table($counts, [int]$total, [string]$title) {
  "  -- $title"
  $counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $Top | ForEach-Object {
    '  {0,6:N1}%  {1,6}  {2}' -f (100.0 * $_.Value / $total), $_.Value, $_.Key
  }
}

# Each sample line is "<leaf key>;<caller RVA> <caller RVA> ..." (innermost first). Three views:
#   self      -- the routine the instruction pointer was in (system DLLs by nearest export)
#   via       -- for samples that were inside a system DLL: the innermost exe routine on the stack
#   inclusive -- every distinct exe routine on the (exact, unwound) stack, plus the leaf if it is in the exe.
$dir = Split-Path $Exe -Parent
$grand = @{ self = @{}; via = @{}; incl = @{}; chain = @{}; total = 0 }
foreach ($f in Get-ChildItem $dir -Filter 'perf_samples_*.txt' | Sort-Object Name) {
  $work = $f.BaseName -replace '^perf_samples_', ''
  $self = @{}; $via = @{}; $incl = @{}
  $total = 0; $outside = 0
  foreach ($l in Get-Content $f) {
    if ($l -match '^total=') { continue }
    $semi = $l.LastIndexOf(';')
    $leafKey = $l.Substring(0, $semi)
    $callers = @($l.Substring($semi + 1).Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    $total++
    $leaf = Resolve-Key $leafKey
    $self[$leaf] = $self[$leaf] + 1
    $frames = New-Object System.Collections.Generic.List[string]
    # Frames are exact unwinder output. All but a leaf that is itself in the exe are return
    # addresses, so look up RVA-1 (a CALL that ends a routine would otherwise land in the next one).
    $leafInExe = $leafKey -notmatch '\|'
    for ($ci = 0; $ci -lt $callers.Count; $ci++) {
      $adj = if ($leafInExe -and $ci -eq 0) { 0 } else { 1 }
      $frames.Add((Resolve-Rva ([Convert]::ToUInt64($callers[$ci], 16) - $adj)))
    }
    $set = @{}
    if ($leafKey -notmatch '\|') { $set[$leaf] = $true } else {
      $outside++
      if ($frames.Count -gt 0) { $via[$frames[0]] = $via[$frames[0]] + 1 } else { $via['<no exe frame>'] = $via['<no exe frame>'] + 1 }
    }
    foreach ($fr in $frames) { $set[$fr] = $true }
    $st = if ($leafInExe) { 1 } else { 0 }   # frame 0 is the leaf itself when it is in the exe
    $take = [Math]::Min($frames.Count - $st, 4)
    if ($take -gt 0) { $ck = (@($leaf) + @($frames[$st..($st + $take - 1)]) -join ' <- '); $grand.chain[$ck] = $grand.chain[$ck] + 1 }
    foreach ($k in $set.Keys) { $incl[$k] = $incl[$k] + 1 }
  }
  foreach ($k in $self.Keys) { $grand.self[$k] = $grand.self[$k] + $self[$k] }
  foreach ($k in $via.Keys)  { $grand.via[$k]  = $grand.via[$k]  + $via[$k] }
  foreach ($k in $incl.Keys) { $grand.incl[$k] = $grand.incl[$k] + $incl[$k] }
  $grand.total += $total
  "`n=== $work  ($total samples, $outside = {0:N0}% inside system DLLs)" -f (100.0 * $outside / [Math]::Max($total, 1))
  Show-Table $self $total 'self'
  Show-Table $via ([Math]::Max($outside, 1)) 'called from (innermost exe routine, samples inside system DLLs only)'
  Show-Table $incl $total 'inclusive'
}

"`n=== ALL WORKLOADS  ($($grand.total) samples)"
Show-Table $grand.self $grand.total 'self'
Show-Table $grand.via  $grand.total 'called from (of all samples)'
Show-Table $grand.incl $grand.total 'inclusive'
Show-Table $grand.chain $grand.total 'top call chains: leaf <- callers (leaf outside the exe repeats its first exe caller)'
