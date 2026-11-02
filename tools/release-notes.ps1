# Writes the GitHub release notes for a tag: what changed, then the fixed text
# every release carries (zip contents, antivirus note).
#
#   pwsh tools/release-notes.ps1 -Tag v26.11.05                  # print them
#   pwsh tools/release-notes.ps1 -Tag v26.11.05 -OutFile NOTES.md
#
# "What changed" is the tag's section of CHANGELOG.md: the lines from
# "## v26.11.05" to the next "## " heading, without "###" headings that have no
# entries. With no such section, or an empty one, it is the list of commit
# subjects since the previous tag, and a ::warning:: line goes to the console
# (an annotation when this runs in GitHub Actions).
#
# release.yml calls this for every release; tools/release.ps1 prints it as a
# preview. A tag that does not exist yet stands for HEAD.

param(
  [Parameter(Mandatory)] [string] $Tag,
  [string] $OutFile
)

$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$Changelog = Join-Path $RepoRoot 'CHANGELOG.md'
$RepoUrl   = 'https://github.com/ilpersi/EasyUOReforged'

# The tag's section of CHANGELOG.md, empty "###" headings dropped.
function Get-ChangelogSection([string] $tag) {
  if (-not (Test-Path $Changelog)) { return @() }
  $lines = (Get-Content -Raw $Changelog) -split "`r?`n"
  $head  = '^##\s+' + [regex]::Escape($tag) + '(\s|$)'

  $section = @()
  $inside  = $false
  foreach ($l in $lines) {
    if ($l -match '^##\s') {
      if ($inside) { break }
      $inside = $l -match $head
      continue
    }
    if ($inside) { $section += $l }
  }

  # Keep a "###" heading only if an entry follows it before the next heading.
  $kept = @()
  for ($i = 0; $i -lt $section.Count; $i++) {
    if ($section[$i] -match '^###\s') {
      $j = $i + 1
      while ($j -lt $section.Count -and $section[$j].Trim() -eq '') { $j++ }
      if ($j -ge $section.Count -or $section[$j] -match '^###\s') { continue }
    }
    $kept += $section[$i]
  }

  # Collapse blank runs left by dropped headings, trim both ends.
  $out = @()
  foreach ($l in $kept) {
    if ($l.Trim() -eq '' -and ($out.Count -eq 0 -or $out[-1].Trim() -eq '')) { continue }
    $out += $l
  }
  while ($out.Count -gt 0 -and $out[-1].Trim() -eq '') { $out = $out[0..($out.Count - 2)] }
  return $out
}

function Invoke-Git {
  $r = & git -C $RepoRoot @args 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  return $r
}

# The commit the tag points at (HEAD if it doesn't exist yet), and the tag before it.
$target = if (Invoke-Git rev-parse -q --verify "refs/tags/$Tag") { $Tag } else { 'HEAD' }
$prev   = Invoke-Git describe --tags --abbrev=0 "$target^"

$changes = @(Get-ChangelogSection $Tag)
if (-not ($changes | Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^###\s' })) {
  Write-Host "::warning::No CHANGELOG.md section for $Tag; listing the commits instead"
  $range   = if ($prev) { "$prev..$target" } else { $target }
  $changes = @('### Commits', '') + @(Invoke-Git log --no-merges --format='- %s' $range)
}

$name = "EasyUOReforged-$Tag-win64"
$notes = @(
  $changes
  ""
  if ($prev) { "**Full list of commits:** $RepoUrl/compare/$prev...$Tag"; "" }
  "---"
  ""
  "Automated Windows x64 build of ``$Tag``, produced by ``.github/workflows/release.yml``"
  "from the tagged commit -- nothing is uploaded by hand."
  ""
  "**Zip contents:** ``EasyUOReforged.exe``, ``uo.dll``, ``EUOUpdtr.exe``, ``EUOMenuDesigner.exe`` + ``LICENSE`` / ``NOTICE`` / ``README.md`` / ``CHANGELOG.md``."
  ""
  "**Antivirus / SmartScreen:** this program reads and writes another process's memory"
  "and patches small code hooks into it (the same techniques a debugger uses), so"
  "Windows may flag it heuristically. This is expected for this class of tool. Verify"
  "your download against ``$name.zip.sha256`` (and ``SHA256SUMS.txt`` for the extracted"
  "files), scan it yourself, or build from source. See"
  "https://ilpersi.github.io/EasyUOReforged/guide/install/#smartscreen-and-antivirus"
  ""
  "Drives both 32-bit and 64-bit Ultima Online clients."
) -join "`n"

if ($OutFile) {
  $OutFile = [IO.Path]::GetFullPath($OutFile, $PWD.Path)
  [IO.File]::WriteAllText($OutFile,$notes + "`n", [Text.UTF8Encoding]::new($false))
} else {
  $notes
}
