<#
  One-off (but re-runnable) derivation tool: converts the CURRENT flat, 222-version
  uoclidata.pas table (221 exact-string ClientList entries, each pointing at a full
  ~80-field SysVarNNNNN table) into a sparse milestone/delta dataset -- one small delta
  array per point where the resolved state actually CHANGED relative to the immediately
  preceding (older) version, applied cumulatively at runtime by the new TCstDB.Update.

  This is a pure MECHANICAL re-encoding, not independent research: every value below
  still traces back to exactly the same hand-verified data already sitting in the flat
  table (and, transitively, to the untouched original Delphi 7 source, via
  VerifyCstDbData.ps1's own byte-for-byte cross-check against it). No new addresses are
  invented here.

  Algorithm:
    1. Parse the current (still-flat) uoclidata.pas with the same regex approach
       VerifyCstDbData.ps1 already uses.
    2. Walk all 222 versions in the file's OWN existing order (index 0 = newest client,
       ClientList's own hand-curated order), reversed here to oldest -> newest. This
       deliberately does NOT re-sort by a derived version comparator -- the file's order
       already correctly places two genuinely irregular strings (5.0.1d1 sits between
       5.0.1d and 5.0.1c; 5.0.1a1 sits between 5.0.1a and 5.0.0b) that a naive zero-padded
       string comparator would get backwards.
    3. For each version, diff its own table's full field map against the immediately
       preceding version's (walking oldest->newest) -- a non-empty diff is a new
       milestone; an empty diff means this version shares its predecessor's milestone.
       A field that goes from set to unset between two versions is emitted as an
       explicit ...Val: $00000000 delta row (NOT simply omitted), since application is
       cumulative and omitting it would leave the older nonzero value in place.
    4. VALIDATION GATE (before any Pascal is written): re-resolve every one of the 222
       versions purely from the new delta model (a PowerShell re-implementation of the
       cumulative-apply algorithm) and diff field-for-field against step 1's direct flat-
       table resolution. Any mismatch is a hard stop.
    5. Only after a 100% match, emit the new Pascal source (delta arrays + Milestones[] +
       VersionIndex[]) to a separate output file for manual splicing into uoclidata.pas --
       this script never touches uoclidata.pas itself.

  This script's own validation gate proves internal self-consistency (the generated model
  reconstructs the flat table it was derived from). It does NOT by itself prove the
  REWRITTEN PASCAL Update()/ExactMatchMilestoneIndex/FloorMilestoneIndex agree with this
  model -- that's what re-running the real FPCUnit TestAllVersionsAgainstGoldenFixture
  against the finished hand-written Pascal is for (a second, independent check).

  Usage: pwsh -File DeriveCstDbMilestones.ps1
#>

$ErrorActionPreference = 'Stop'

# Relative to this script (tests\tools\): the port's own uoclidata.pas, and a
# generated-block output file dropped next to this script.
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$SrcFile = Join-Path $RepoRoot 'uo\uoclidata.pas'
$OutFile = Join-Path $PSScriptRoot 'uoclidata_generated_block.txt'

# ---- 1. Parse (same approach as VerifyCstDbData.ps1's Parse-CstDbFile) ----
function Parse-CstDbFile {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw
    $tables = @{}
    $tableRegex = [regex]::new('(?ms)^\s*(SysVar\w+)\s*:\s*array\[0\.\.\d+\]\s*of\s*TSysVarList\s*=\s*\((.*?)\n\s*\);', 'None')
    foreach ($m in $tableRegex.Matches($text)) {
        $name = $m.Groups[1].Value
        $body = $m.Groups[2].Value
        $entries = New-Object System.Collections.Generic.List[Object]
        $entryRegex = [regex]::new('\(Expr:\s*(\w+)\s*;\s*Val:\s*\$([0-9A-Fa-f]+)\)')
        foreach ($e in $entryRegex.Matches($body)) {
            $entries.Add(@{ Field = $e.Groups[1].Value; Val = $e.Groups[2].Value.ToUpper() })
        }
        $tables[$name] = $entries
    }
    $clientList = New-Object System.Collections.Generic.List[Object]
    $clRegex = [regex]::new("\(Cli:\s*'([^']+)';\s*List:\s*@(\w+)\s*;?\s*\)")
    foreach ($m in $clRegex.Matches($text)) {
        $clientList.Add(@{ Cli = $m.Groups[1].Value; Table = $m.Groups[2].Value })
    }
    return @{ Tables = $tables; ClientList = $clientList }
}

Write-Host "Parsing $SrcFile ..."
$parsed = Parse-CstDbFile -Path $SrcFile
Write-Host "  tables=$($parsed.Tables.Count) clientListRows=$($parsed.ClientList.Count)"

if ($parsed.ClientList.Count -eq 0) {
    $msg = "Found 0 old-shape '(Cli: ...; List: @Table)' rows. This is EXPECTED once " +
        "uoclidata.pas already holds the milestone/delta model this script produces -- " +
        "its '(Cli: ...; Milestone: N)' VersionIndex rows are a different shape this " +
        "script does not parse (by design; there is no flat per-version table left to " +
        "derive FROM at that point). To add ONE new version, follow " +
        "docs\adding-client-support.md's step 6 by hand instead. To re-run this script " +
        "for a bulk change, first restore uoclidata.pas to (or build a scratch copy in) " +
        "its pre-redesign flat shape -- e.g. check out the commit just before the " +
        "milestone/delta redesign, add your new version(s) there as ordinary flat " +
        "entries, then run this script against THAT file."
    throw $msg
}
if ($parsed.ClientList.Count -ne 222) {
    $msg = "NOTE: found $($parsed.ClientList.Count) old-shape rows, not the 222 this " +
        "script was last run against -- proceeding anyway, but double-check this " +
        "is the flat-shaped source file you actually meant to derive from."
    Write-Host $msg -ForegroundColor Yellow
}

function Resolve-Fields($tableName) {
    $r = @{}
    foreach ($e in $parsed.Tables[$tableName]) {
        if ($e.Field -ne 'LISTEND') { $r[$e.Field] = $e.Val }
    }
    return $r
}

# ---- 2. FormatCliVer port (Gemini's normalizer, ported verbatim) ----
function Format-CliVer([string]$CliVer) {
    $s = $CliVer.ToLowerInvariant()
    $suffix = ''
    for ($p = 0; $p -lt $s.Length; $p++) {
        if ($s[$p] -ge 'a' -and $s[$p] -le 'z') {
            $suffix = '.' + $s[$p]
            $s = $s.Substring(0, $p)
            break
        }
    }
    $parts = $s.Split('.')
    $padded = $parts | ForEach-Object { $_.PadLeft(3, '0') }
    return ($padded -join '.') + $suffix
}

# ---- 3. Walk oldest -> newest, diffing against the running previous state ----
# $parsed.ClientList is newest-first (index 0 = newest); reverse for the oldest-first walk.
$oldestFirst = [System.Collections.Generic.List[Object]]::new($parsed.ClientList)
$oldestFirst.Reverse()

$milestonesOldestFirst = New-Object System.Collections.Generic.List[Object]   # {NormVer, Delta, Cli}
$versionMilestoneOldestFirst = New-Object 'int[]' $oldestFirst.Count

$prevResolved = @{}
for ($i = 0; $i -lt $oldestFirst.Count; $i++) {
    $row = $oldestFirst[$i]
    $resolved = Resolve-Fields $row.Table

    $delta = @{}
    $keys = @($resolved.Keys) + @($prevResolved.Keys) | Select-Object -Unique
    foreach ($k in $keys) {
        $newVal = if ($resolved.ContainsKey($k)) { $resolved[$k] } else { '00000000' }
        $oldVal = if ($prevResolved.ContainsKey($k)) { $prevResolved[$k] } else { '00000000' }
        if ($newVal -ne $oldVal) { $delta[$k] = $newVal }
    }

    if ($delta.Count -gt 0 -or $milestonesOldestFirst.Count -eq 0) {
        $milestonesOldestFirst.Add(@{ NormVer = (Format-CliVer $row.Cli); Delta = $delta; Cli = $row.Cli })
    }
    $versionMilestoneOldestFirst[$i] = $milestonesOldestFirst.Count - 1
    $prevResolved = $resolved
}

Write-Host "Derived $($milestonesOldestFirst.Count) milestones from $($oldestFirst.Count) versions."

# ---- 4. Validation gate: re-resolve all 222 versions purely from the new model ----
$mismatches = 0
$totalChecks = 0
for ($i = 0; $i -lt $oldestFirst.Count; $i++) {
    $row = $oldestFirst[$i]
    $expected = Resolve-Fields $row.Table
    $mIdx = $versionMilestoneOldestFirst[$i]

    $got = @{}
    for ($m = 0; $m -le $mIdx; $m++) {
        foreach ($k in $milestonesOldestFirst[$m].Delta.Keys) {
            $got[$k] = $milestonesOldestFirst[$m].Delta[$k]
        }
    }

    $allKeys = @($expected.Keys) + @($got.Keys) | Select-Object -Unique
    foreach ($k in $allKeys) {
        $totalChecks++
        $e = if ($expected.ContainsKey($k)) { $expected[$k] } else { '00000000' }
        $g = if ($got.ContainsKey($k)) { $got[$k] } else { '00000000' }
        if ($e -ne $g) {
            $mismatches++
            Write-Host "MISMATCH version '$($row.Cli)' field $k : expected $e got $g" -ForegroundColor Red
        }
    }
}

Write-Host "Validation: $totalChecks (version,field) checks, $mismatches mismatches."
if ($mismatches -gt 0) {
    Write-Host "`nRESULT: DERIVATION FAILED -- not writing any output." -ForegroundColor Red
    exit 1
}
Write-Host "`nRESULT: derivation is self-consistent (100% match against the flat table)." -ForegroundColor Green

# ---- 5. Emit Pascal source ----
# Final arrays are newest-first (index 0 = newest milestone/version), matching the new
# Update()'s "for Cnt := High(Milestones) downto MIdx" cumulative-apply direction and the
# original ClientList's own established newest-first ordering convention.
$milestonesNewestFirst = [System.Collections.Generic.List[Object]]::new($milestonesOldestFirst)
$milestonesNewestFirst.Reverse()
$M = $milestonesNewestFirst.Count

$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine("////////////////////////////////////////////////////////////////////////////////")
$null = $sb.AppendLine("// Generated by Lazarus\tests\tools\DeriveCstDbMilestones.ps1 -- DO NOT hand-edit")
$null = $sb.AppendLine("// the VALUES below; re-run the script against an updated flat table instead, or")
$null = $sb.AppendLine("// (for a genuinely NEW client version with no flat-table precedent) hand-author a")
$null = $sb.AppendLine("// new milestone following this same shape -- see docs\adding-client-support.md.")
$null = $sb.AppendLine("// Each SysVarMSn array holds only the fields that changed at that milestone,")
$null = $sb.AppendLine("// relative to the cumulative state of every OLDER milestone (index n+1..High).")
$null = $sb.AppendLine("// See TCstDB.Update's header comment for the exact cumulative-apply algorithm.")
$null = $sb.AppendLine("////////////////////////////////////////////////////////////////////////////////")
$null = $sb.AppendLine()

for ($k = 0; $k -lt $M; $k++) {
    $ms = $milestonesNewestFirst[$k]
    $name = "SysVarMS$k"
    $null = $sb.AppendLine("// Milestone $k -- first introduced at client '$($ms.Cli)' (normalized '$($ms.NormVer)')")
    if ($ms.Cli -eq '7.0.108.0' -or $ms.Cli -eq '7.0.99.1') {
        $null = $sb.AppendLine("// {TODO: reattach the full header comment from the pre-redesign uoclidata.pas's")
        $null = $sb.AppendLine("// SysVar$($ms.Cli.Replace('.',''))'s (see git history) explaining F_SYSMSGDIRECT/")
        $null = $sb.AppendLine("// F_JOURNALDIRECT/B_JCOL/B_JKIND/B_JNEXTPTR/C_SYSMSG for this client generation.}")
    }
    $fieldNames = @($ms.Delta.Keys) | Sort-Object
    $null = $sb.AppendLine("$name : array[0..$($fieldNames.Count)] of TSysVarList = (")
    foreach ($f in $fieldNames) {
        $null = $sb.AppendLine("  (Expr: $f; Val: `$$($ms.Delta[$f])),")
    }
    $null = $sb.AppendLine("  (Expr: LISTEND; Val: 0)")
    $null = $sb.AppendLine(");")
    $null = $sb.AppendLine()
}

$null = $sb.AppendLine("Milestones : array[0..$($M-1)] of TMilestoneEntry = (")
for ($k = 0; $k -lt $M; $k++) {
    $ms = $milestonesNewestFirst[$k]
    $comma = if ($k -lt $M - 1) { ',' } else { '' }
    $null = $sb.AppendLine("  (NormVer: '$($ms.NormVer)'; List: @SysVarMS$k)$comma")
}
$null = $sb.AppendLine(");")
$null = $sb.AppendLine()

$V = $oldestFirst.Count
$null = $sb.AppendLine("VersionIndex : array[0..$($V-1)] of TVersionIndexEntry = (")
for ($i = 0; $i -lt $V; $i++) {
    # newest-first output, matching the original ClientList's own ordering
    $srcIdx = $V - 1 - $i
    $row = $oldestFirst[$srcIdx]
    $finalMilestone = $M - 1 - $versionMilestoneOldestFirst[$srcIdx]
    $comma = if ($i -lt $V - 1) { ',' } else { '' }
    $null = $sb.AppendLine("  (Cli: '$($row.Cli)'; Milestone: $finalMilestone)$comma")
}
$null = $sb.AppendLine(");")

Set-Content -LiteralPath $OutFile -Value $sb.ToString() -Encoding UTF8
Write-Host "`nWrote generated block: $OutFile"
Write-Host "  milestones=$M versions=$V (vs. 140 tables / 222 versions in the flat original)"
