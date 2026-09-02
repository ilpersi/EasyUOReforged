# Builds and runs the full FPCUnit test suite for the EasyUO Reforged port.
# Run from anywhere; cd's to this script's own directory first.
#
# The test project (RunTests.lpi) pulls the interpreter, engine and common code
# in as Lazarus packages (euoparser -> uoengine -> uocommon), so lazbuild
# resolves every unit path -- including LCL and the FCL test-runner units --
# on its own. There is no hand-maintained -Fu list here any more.

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

# --- Locate lazbuild --------------------------------------------------------
# Override with $env:LAZARUS_DIR if auto-detection can't find your install.
function Find-Lazbuild {
  if ($env:LAZARUS_DIR) {
    $p = Join-Path $env:LAZARUS_DIR 'lazbuild.exe'
    if (Test-Path $p) { return $p }
  }
  $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    'C:\Lazarus',
    "$env:ProgramFiles\Lazarus",
    "${env:ProgramFiles(x86)}\Lazarus",
    'C:\fpcupdeluxe\lazarus',
    'D:\Program Files\Lazarus'
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path (Join-Path $c 'lazbuild.exe'))) {
      return (Join-Path $c 'lazbuild.exe')
    }
  }
  throw 'Could not find lazbuild. Set $env:LAZARUS_DIR to your Lazarus install path.'
}

$Lazbuild = Find-Lazbuild
Write-Host "Using lazbuild: $Lazbuild"

$RepoRoot = Split-Path $PSScriptRoot -Parent
$Common = @('--cpu=x86_64', '--os=win64')

# Refresh the generated version unit (also wired into the build via uocommon.lpk,
# but do it explicitly so a bare checkout is guaranteed to have it).
& (Join-Path $RepoRoot 'tools\gen-version.ps1')

# Register the project's package links so a fresh checkout / CI runner that has
# never opened these packages in the IDE can still resolve them by name.
& $Lazbuild @Common `
  "--add-package-link=$RepoRoot\common\uocommon.lpk" `
  "--add-package-link=$RepoRoot\uo\uoengine.lpk" `
  "--add-package-link=$RepoRoot\parser\euoparser.lpk" | Out-Null

& $Lazbuild @Common 'RunTests.lpi'
if ($LASTEXITCODE -ne 0) {
  throw "lazbuild failed with exit code $LASTEXITCODE"
}

& .\RunTests.exe --format=plain -a
exit $LASTEXITCODE
