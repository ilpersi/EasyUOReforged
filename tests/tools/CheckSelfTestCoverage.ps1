# Checks that every #variable and every script command of the interpreter is mentioned by at least one
# self-test script (tools\EUOSelfTest\EUOSelfTest.euo or tests\euo\all-commands-test.euo).
#
# Names come straight from parser\EuoInterpreter.pas (the VarNamesR / VarNamesRW arrays, the
# CmdRegistry.Register(...) calls and the event / exevent types; see EuoNames.ps1), so a variable or command
# added to the interpreter without a test case makes this script - and run_tests.ps1, which calls it - fail.
#
# A name counts as covered when it appears as a word in one of the self-test scripts (case-insensitive).
# Names that cannot be exercised at all are listed in $NotTestable with the reason.
#
# Usage:  pwsh ./tests/tools/CheckSelfTestCoverage.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EuoNames.ps1')
$Root = $EuoRoot
$Scripts = @(
  (Join-Path $Root 'tools\EUOSelfTest\EUOSelfTest.euo'),
  (Join-Path $Root 'tests\euo\all-commands-test.euo')
)

# name -> why a script cannot cover it
$NotTestable = @{
  'StopCD'   = 'recognised, deliberately a no-op (see the interpreter header)'
  'PlayCD'   = 'recognised, deliberately a no-op (see the interpreter header)'
}

$names = Get-EuoNames
$vars = $names.Variables
$cmds = $names.Commands

# subcommands of the multi-purpose commands that scripts use constantly
$events = $names.Events
$exevents = $names.ExEvents

$words = @{}
foreach ($s in $Scripts) {
  if (-not (Test-Path $s)) { throw "Missing self-test script: $s" }
  foreach ($w in [regex]::Matches((Get-Content $s -Raw).ToLower(), '[a-z0-9_]+')) { $words[$w.Value] = $true }
}

$missing = New-Object System.Collections.Generic.List[string]
function Check([string]$kind, [string]$name) {
  if ($NotTestable.ContainsKey($name)) { return }
  if (-not $words.ContainsKey($name.ToLower())) { $missing.Add("$kind $name") }
}
$vars   | Sort-Object -Unique | ForEach-Object { Check 'variable' $_ }
$cmds   | Sort-Object -Unique | ForEach-Object { Check 'command'  $_ }
$events   | ForEach-Object { Check 'event'   $_ }
$exevents | ForEach-Object { Check 'exevent' $_ }

$total = ($vars | Sort-Object -Unique).Count + ($cmds | Sort-Object -Unique).Count + $events.Count + $exevents.Count
if ($missing.Count -gt 0) {
  Write-Host "Self-test coverage: $($missing.Count) of $total names are not mentioned by any self-test script:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  $_" }
  Write-Host "Add a case to tools\EUOSelfTest\EUOSelfTest.euo (or list the name in `$NotTestable with a reason)."
  exit 1
}
Write-Host "Self-test coverage OK: all $total variables, commands, events and exevents are mentioned."
