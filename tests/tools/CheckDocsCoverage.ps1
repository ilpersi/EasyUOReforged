# Checks that the documentation site (website\src\content\docs) has a page for every #variable, every
# script command and every sub-command of the interpreter, and that every reference page belongs to a name
# the interpreter really has.
#
# Names come from the source through EuoNames.ps1, the same lists CheckSelfTestCoverage.ps1 uses, so a
# variable or command added to the interpreter without a page makes this script - and run_tests.ps1, which
# calls it - fail. A renamed or removed one fails it too, through its leftover page.
#
# Where a name is looked for:
#   #Name               variables\name.md
#   Command             commands\command.md (or a page whose `aliases:` lists it: Until -> repeat.md)
#   event / exevent X   commands\event\x.md, commands\exevent\x.md
#   menu X              commands\menu\x.md, or any page under commands\menu\x\ (menu font align)
#   namespace / sql X   commands\namespace\x.md, commands\sql\x.md
#   path X              commands\path\x.md
#   str X               mentioned on commands\str.md (one page documents every str operation)
#   uo.dll members      dll\name.md - checked only once the dll\ section exists
#
# It also reports, as warnings that do not fail the run, names the interpreter and the editor's highlighter /
# autocomplete lists (easyuo\eusyntax.pas, and the sub-commands in easyuo\eucomplete.pas) disagree on.
#
# Usage:  pwsh ./tests/tools/CheckDocsCoverage.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EuoNames.ps1')
$Docs = Join-Path $EuoRoot 'website\src\content\docs'

# name -> why it has no page
$NotDocumented = @{
  'menu TEST' = 'empty debug hook: TMenuObj.Test does nothing'
}
# page -> why it stays although the interpreter has no such name
$PageWithoutName = @{
  'commands/event/sleep' = 'documented EasyUO command the interpreter does not implement; the page says so'
  'commands/initevents'  = 'obsolete; unknown to the interpreter, so the line is ignored; the page says so'
  'commands/label'       = 'labels (name:) are syntax, not a registered command'
}

$names = Get-EuoNames

# ---- the pages -------------------------------------------------------------------------------------------
$pages = @{}
foreach ($f in Get-ChildItem $Docs -Recurse -Include '*.md', '*.mdx') {
  $rel = [IO.Path]::GetRelativePath($Docs, $f.FullName).Replace('\', '/')
  $slug = ($rel -replace '\.mdx?$', '' -replace '(^|/)index$', '').ToLower()
  $text = Get-Content $f.FullName -Raw
  $fm = [regex]::Match($text, '^---\r?\n(.*?)\r?\n---', 'Singleline').Groups[1].Value
  $kind = [regex]::Match($fm, '(?m)^kind:\s*(\S+)').Groups[1].Value
  $aliasLine = [regex]::Match($fm, '(?m)^aliases:\s*\[(.*)\]').Groups[1].Value
  $aliases = @([regex]::Matches($aliasLine, '["'']([^"'']+)["'']') | ForEach-Object { $_.Groups[1].Value.ToLower() })
  $pages[$slug] = [pscustomobject]@{ Slug = $slug; Kind = $kind; Aliases = $aliases; Text = $text }
}
function Test-Page([string]$slug) { $pages.ContainsKey($slug) }
function Test-PageTree([string]$slug) { (Test-Page $slug) -or @($pages.Keys | Where-Object { $_.StartsWith("$slug/") }).Count -gt 0 }

# ---- every name needs a page -----------------------------------------------------------------------------
$missing = New-Object System.Collections.Generic.List[string]
$checked = 0
function Need([string]$label, [bool]$found) {
  $script:checked++
  if ($NotDocumented.ContainsKey($label)) { return }
  if (-not $found) { $missing.Add($label) }
}

foreach ($v in $names.Variables | Sort-Object -Unique) { Need "#$v" (Test-Page "variables/$($v.ToLower())") }
foreach ($c in $names.Commands | Sort-Object -Unique) {
  $l = $c.ToLower()
  $byAlias = @($pages.Values | Where-Object { $_.Kind -eq 'command' -and $_.Aliases -contains $l }).Count -gt 0
  Need $c ((Test-Page "commands/$l") -or $byAlias)
}
foreach ($e in $names.Events)    { Need "event $e"     (Test-Page "commands/event/$($e.ToLower())") }
foreach ($e in $names.ExEvents)  { Need "exevent $e"   (Test-Page "commands/exevent/$($e.ToLower())") }
foreach ($e in $names.Menu)      { Need "menu $e"      (Test-PageTree "commands/menu/$($e.ToLower())") }
foreach ($e in $names.NameSpace) { Need "namespace $e" (Test-Page "commands/namespace/$($e.ToLower())") }
foreach ($e in $names.Sql)       { Need "sql $e"       (Test-Page "commands/sql/$($e.ToLower())") }
foreach ($e in $names.Path)      { Need "path $e"      (Test-Page "commands/path/$($e.ToLower())") }
$strText = if (Test-Page 'commands/str') { $pages['commands/str'].Text } else { '' }
foreach ($e in $names.Str)       { Need "str $e"       ($strText -match "(?i)\bstr\s+$e\b") }
$dllOn = Test-Path (Join-Path $Docs 'dll')
if ($dllOn) {
  foreach ($d in @($names.DllMembers) + @($names.DllCalls) | Sort-Object -Unique) { Need "uo.dll $d" (Test-Page "dll/$($d.ToLower())") }
}

# ---- every reference page needs a name -------------------------------------------------------------------
$lower = { param($list) @($list | ForEach-Object { $_.ToLower() }) }
$families = @{
  event = & $lower $names.Events; exevent = & $lower $names.ExEvents; menu = & $lower $names.Menu
  namespace = & $lower $names.NameSpace; sql = & $lower $names.Sql; path = & $lower $names.Path
}
$vars = & $lower $names.Variables
$cmds = & $lower $names.Commands
$dll = & $lower (@($names.DllMembers) + @($names.DllCalls))
$orphans = New-Object System.Collections.Generic.List[string]
foreach ($p in $pages.Values | Where-Object { $_.Kind } | Sort-Object Slug) {
  if ($PageWithoutName.ContainsKey($p.Slug)) { continue }
  $parts = $p.Slug.Split('/')
  $ok = switch -Regex ($p.Kind) {
    '^variable$'   { $parts[0] -eq 'variables' -and $vars -contains $parts[1] }
    '^command$'    { $parts.Count -eq 2 -and ($cmds -contains $parts[1] -or @($p.Aliases | Where-Object { $cmds -contains $_ }).Count -gt 0) }
    '^subcommand$' { $parts.Count -ge 3 -and $families.ContainsKey($parts[1]) -and $families[$parts[1]] -contains $parts[2] }
    '^dll-'        { $parts[0] -eq 'dll' -and $dll -contains $parts[1] }
    default        { $false }
  }
  if (-not $ok) { $orphans.Add("$($p.Slug) (kind: $($p.Kind))") }
}

# ---- highlighter / autocomplete drift (warnings) ---------------------------------------------------------
$hlVars = & $lower $names.Highlighted.Variables
$hlCmds = & $lower $names.Highlighted.Commands
$notHl  = @($names.Variables | Where-Object { $hlVars -notcontains $_.ToLower() } | ForEach-Object { "#$_" }) +
          @($names.Commands | Where-Object { $hlCmds -notcontains $_.ToLower() -and -not $NotDocumented.ContainsKey($_) })
$hlOnly = @($names.Highlighted.Variables | Where-Object { $vars -notcontains $_.ToLower() } | ForEach-Object { "#$_" })
if ($notHl.Count -gt 0)  { Write-Host "Warning: not highlighted / not offered by autocomplete (easyuo\eusyntax.pas): $($notHl -join ', ')" -ForegroundColor Yellow }
if ($hlOnly.Count -gt 0) { Write-Host "Warning: highlighted, but the interpreter has no such variable: $($hlOnly -join ', ')" -ForegroundColor Yellow }

# The sub-commands autocomplete offers right after a command (SubCommands in easyuo\eucomplete.pas), against
# the interpreter's own. Deeper levels (menu font align, ...) are not read off the source, so not checked.
$complFamilies = [ordered]@{
  EVENT = $names.Events; EXEVENT = $names.ExEvents; MENU = $names.Menu
  NAMESPACE = $names.NameSpace; STR = $names.Str; SQL = $names.Sql; PATH = $names.Path
}
$notOffered = @(); $offeredOnly = @()
foreach ($cmd in $complFamilies.Keys) {
  $real = @($complFamilies[$cmd] | ForEach-Object { $_.ToUpper() })
  $offered = if ($names.Completion.Contains($cmd)) { @($names.Completion[$cmd]) } else { @() }
  $notOffered += @($real | Where-Object { $offered -notcontains $_ } | ForEach-Object { "$($cmd.ToLower()) $_" } |
                   Where-Object { -not $NotDocumented.ContainsKey($_) })
  $offeredOnly += @($offered | Where-Object { $real -notcontains $_ } | ForEach-Object { "$($cmd.ToLower()) $_" })
}
if ($notOffered.Count -gt 0)  { Write-Host "Warning: not offered by autocomplete (easyuo\eucomplete.pas SubCommands): $($notOffered -join ', ')" -ForegroundColor Yellow }
if ($offeredOnly.Count -gt 0) { Write-Host "Warning: offered by autocomplete, but the interpreter has no such sub-command: $($offeredOnly -join ', ')" -ForegroundColor Yellow }

# ---- result ----------------------------------------------------------------------------------------------
$failed = $false
if ($missing.Count -gt 0) {
  Write-Host "Docs coverage: $($missing.Count) of $checked names have no page in website\src\content\docs:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  $_" }
  Write-Host "Add the page (copy one of the same kind; see website\README.md), or list the name in `$NotDocumented with a reason."
  $failed = $true
}
if ($orphans.Count -gt 0) {
  Write-Host "Docs coverage: $($orphans.Count) reference pages match no name in the interpreter:" -ForegroundColor Red
  $orphans | ForEach-Object { Write-Host "  $_" }
  Write-Host "Rename or remove the page, or list it in `$PageWithoutName with a reason."
  $failed = $true
}
if ($failed) { exit 1 }
$dllNote = if ($dllOn) { '' } else { ' (uo.dll section not started: not checked)' }
Write-Host "Docs coverage OK: all $checked variables, commands and sub-commands have a page$dllNote."
