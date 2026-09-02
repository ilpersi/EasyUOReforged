<#
  One-off (but re-runnable) golden-fixture generator for uoclidata.pas / TCstDB.

  Parses the per-version SysVarNNNNN tables + ClientList array straight out of the
  UNTOUCHED ORIGINAL Delphi 7 source (never the Lazarus port), using plain regex (no
  compiler needed), and emits a JSON golden fixture (tests\fixtures\uoclidata_golden.json)
  of the resulting (version, field) -> value data -- consumed by CstDbTests.pas's
  TestAllVersionsAgainstGoldenFixture, which exercises the real, running TCstDB against it.

  Originally this script ALSO diffed the ported file's own SysVarNNNNN/ClientList tables
  against the original's, byte-for-byte, before trusting them as a source for the golden
  JSON -- appropriate when the port was a flat, one-table-per-version transplant (proving
  the transplant was exact). That structural-equality check was retired when uoclidata.pas
  was re-architected into a milestone/delta model (see that file's own header comment):
  the ported file no longer has one full table per version to diff row-for-row against the
  original at all, by design -- most fields simply don't appear in most milestones' delta
  arrays anymore, because they didn't change. That is not a regression to chase.

  The golden JSON itself remains completely valid ground truth regardless of the port's
  internal data shape -- it is built ONLY from the original file below, and the actual
  proof the port is still correct is CstDbTests.pas's TestAllVersionsAgainstGoldenFixture,
  which calls the real, running (milestone/delta-resolving) TCstDB.Update and checks its
  getters against this same fixture. That is a completely independent, stronger check than
  a static text diff ever was.

  Usage: pwsh -File VerifyCstDbData.ps1 -OrigFile <path to the original Delphi 7 uoclidata.pas>
#>

param(
    # The UNTOUCHED original Delphi 7 uo\uoclidata.pas. This file is NOT part of
    # this repository -- it lives in the private archive of the pre-port source.
    # Pass its path explicitly.
    [Parameter(Mandatory = $true)]
    [string]$OrigFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OrigFile)) {
    throw "Original source not found: $OrigFile"
}

# tests\fixtures\uoclidata_golden.json, relative to this script (tests\tools\).
$OutJson = Join-Path (Split-Path $PSScriptRoot -Parent) 'fixtures\uoclidata_golden.json'

function Parse-CstDbFile {
    param([string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw

    # 1. Parse every SysVarNNNNN table into: tablename -> ordered [ [field, hexvalue], ... ]
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

    # 2. Parse ClientList: version string -> tablename
    $clientList = New-Object System.Collections.Generic.List[Object]
    $clRegex = [regex]::new("\(Cli:\s*'([^']+)';\s*List:\s*@(\w+)\s*;?\s*\)")
    foreach ($m in $clRegex.Matches($text)) {
        $clientList.Add(@{ Cli = $m.Groups[1].Value; Table = $m.Groups[2].Value })
    }

    return @{ Tables = $tables; ClientList = $clientList }
}

Write-Host "Parsing original: $OrigFile"
$orig = Parse-CstDbFile -Path $OrigFile
Write-Host "  tables=$($orig.Tables.Count) clientListRows=$($orig.ClientList.Count)"

# Emit golden fixture: for every (version, field) resolve the final value exactly as the
# original TCstDB.Update would (each table is a flat list with no duplicate fields, so a
# direct dictionary build is equivalent to the original's linear GetCst scan).
Write-Host "`nBuilding golden fixture JSON..."
$golden = New-Object System.Collections.Generic.List[Object]
foreach ($row in $orig.ClientList) {
    $fields = @{}
    foreach ($e in $orig.Tables[$row.Table]) {
        if ($e.Field -ne 'LISTEND') { $fields[$e.Field] = $e.Val }
    }
    $golden.Add(@{ Cli = $row.Cli; Fields = $fields })
}

$null = New-Item -ItemType Directory -Force -Path (Split-Path $OutJson)
($golden | ConvertTo-Json -Depth 5 -Compress) | Set-Content -LiteralPath $OutJson -Encoding UTF8
Write-Host "Wrote golden fixture: $OutJson ($($golden.Count) versions)"
