# Prepares a release: turns the "## Unreleased" section of CHANGELOG.md into
# the new version's, commits that, and tags the commit. It does not push.
#
#   pwsh tools/release.ps1 v26.11.05
#
# Then, after checking the preview it prints:
#
#   git push origin main v26.11.05
#
# The tag push starts .github/workflows/release.yml, which builds, tests and
# publishes the release with tools/release-notes.ps1's notes.
#
# Stops without changing anything unless: the tag looks like vYY.MM.DD (an
# optional ".N" suffix for a second release on one day), it doesn't exist yet,
# the current branch is main, no tracked file has uncommitted changes, and
# "## Unreleased" has at least one entry.

param(
  [Parameter(Mandatory, Position = 0)] [string] $Tag
)

$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$Changelog = Join-Path $RepoRoot 'CHANGELOG.md'

function Stop-Release([string] $why) {
  Write-Host "release.ps1: $why" -ForegroundColor Red
  exit 1
}

function Invoke-Git {
  $r = & git -C $RepoRoot @args
  if ($LASTEXITCODE -ne 0) { Stop-Release "git $($args -join ' ') failed" }
  return $r
}

if ($Tag -notmatch '^v\d{2}\.\d{2}\.\d{2}(\.\d+)?$') {
  Stop-Release "'$Tag' is not a vYY.MM.DD tag"
}
& git -C $RepoRoot rev-parse -q --verify "refs/tags/$Tag" *> $null
if ($LASTEXITCODE -eq 0) { Stop-Release "tag $Tag already exists" }

$branch = Invoke-Git rev-parse --abbrev-ref HEAD
if ($branch -ne 'main') { Stop-Release "on branch '$branch', not main" }

if (Invoke-Git status --porcelain --untracked-files=no) {
  Stop-Release "tracked files have uncommitted changes; commit or stash them first"
}

if (-not (Test-Path $Changelog)) { Stop-Release "CHANGELOG.md not found" }
$raw = [IO.File]::ReadAllText($Changelog)
$eol = if ($raw -match "`r`n") { "`r`n" } else { "`n" }

$m = [regex]::Match($raw, '(?ms)^## Unreleased[ \t]*\r?$(.*?)(?=^## |\z)')
if (-not $m.Success) { Stop-Release "CHANGELOG.md has no '## Unreleased' section" }
if ($m.Groups[1].Value -notmatch '(?m)^\s*[-*]\s+\S') {
  Stop-Release "'## Unreleased' in CHANGELOG.md has no entries; write the release notes first"
}

# A fresh, empty Unreleased section above the new version's.
$date  = (Get-Date).ToString('yyyy-MM-dd')
$fresh = @('## Unreleased', '', '### Added', '', '### Changed', '', '### Fixed', '',
           "## $Tag - $date") -join $eol
$raw   = $raw.Substring(0, $m.Index) + $fresh +
         $raw.Substring($m.Index + '## Unreleased'.Length).TrimStart(" `t".ToCharArray())
[IO.File]::WriteAllText($Changelog, $raw, [Text.UTF8Encoding]::new($false))

Invoke-Git add -- CHANGELOG.md | Out-Null
Invoke-Git commit -q -m "Release $Tag" | Out-Null
Invoke-Git tag $Tag | Out-Null

Write-Host "Committed 'Release $Tag' and tagged it $Tag. The release page will read:" -ForegroundColor Green
Write-Host ''
& (Join-Path $PSScriptRoot 'release-notes.ps1') -Tag $Tag
Write-Host ''
Write-Host 'Nothing is pushed yet. To publish the release:' -ForegroundColor Green
Write-Host "  git push origin main $Tag"
Write-Host "To undo instead:  git tag -d $Tag; git reset --keep HEAD~1"
