# Builds tests\RunTests.lpi in its "Bench" mode (-O3 + symbols -> tests\RunBench.exe) and runs the
# opt-in interpreter benchmark (tests\PerfBenchTests.pas).
#
#   -OptimizePackages  also pass -O3 to the euoparser/uoengine/uocommon packages (--opt=-O3).
#                      Without it the packages build with their own options (no -O), which is
#                      what EasyUOReforged.exe's Release mode actually does to them today.
#   -Sample            run the in-process sampling profiler and resolve the samples to routine names.
#   -Suite             FPCUnit suite/test to run (default: the whole benchmark class).
#
# Results are appended to tests\perf_results.txt (deleted at the start of each run).
param(
  [switch]$OptimizePackages,
  [switch]$Sample,
  [string]$Suite = 'TPerfBenchTests',
  [int]$Top = 25
)

$ErrorActionPreference = 'Stop'
$TestsDir = Split-Path $PSScriptRoot -Parent
$RepoRoot = Split-Path $TestsDir -Parent
Set-Location -Path $TestsDir

function Find-LazarusDir {
  if ($env:LAZARUS_DIR -and (Test-Path (Join-Path $env:LAZARUS_DIR 'lazbuild.exe'))) { return $env:LAZARUS_DIR }
  $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
  if ($cmd) { return (Split-Path $cmd.Source) }
  foreach ($c in 'C:\Lazarus', "$env:ProgramFiles\Lazarus", 'C:\fpcupdeluxe\lazarus', 'D:\Program Files\Lazarus') {
    if (Test-Path (Join-Path $c 'lazbuild.exe')) { return $c }
  }
  throw 'Could not find lazbuild. Set $env:LAZARUS_DIR to your Lazarus install path.'
}

$LazDir   = Find-LazarusDir
$Lazbuild = Join-Path $LazDir 'lazbuild.exe'
$Common   = @('--cpu=x86_64', '--os=win64')

& (Join-Path $RepoRoot 'tools\gen-version.ps1')
& $Lazbuild @Common `
  "--add-package-link=$RepoRoot\common\uocommon.lpk" `
  "--add-package-link=$RepoRoot\uo\uoengine.lpk" `
  "--add-package-link=$RepoRoot\parser\euoparser.lpk" | Out-Null

$Extra = @()
if ($OptimizePackages) { $Extra += '--opt=-O3' }
& $Lazbuild @Common '--build-mode=Bench' @Extra 'RunTests.lpi'
if ($LASTEXITCODE -ne 0) { throw "lazbuild failed with exit code $LASTEXITCODE" }

Remove-Item perf_results.txt, perf_samples_*.txt -ErrorAction SilentlyContinue
$env:EUO_PERF = '1'
if ($Sample) { $env:EUO_PERF_SAMPLE = '1' } else { Remove-Item Env:\EUO_PERF_SAMPLE -ErrorAction SilentlyContinue }

& .\RunBench.exe "--suite=$Suite" --format=plain
if ($LASTEXITCODE -ne 0) { throw "RunBench.exe failed with exit code $LASTEXITCODE" }

if ($Sample) {
  & (Join-Path $PSScriptRoot 'ResolveSamples.ps1') -Exe (Join-Path $TestsDir 'RunBench.exe') -Top $Top
}
