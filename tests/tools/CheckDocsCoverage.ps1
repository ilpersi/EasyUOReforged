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
#   menu X              commands\menu\x.md, or any page under commands\menu\x\ (menu font align); X is a
#                       sub-command of either MENU logic, 1.5's or 1.6's, and every MENU page's menuLogic
#                       must say which logics have it (see "MENU: which logic has it" below)
#   namespace / sql X   commands\namespace\x.md, commands\sql\x.md
#   path X              commands\path\x.md
#   str X               mentioned on commands\str.md (one page documents every str operation)
#   uo.dll members      dll\name.md - checked only once the dll\ section exists
#
# Every ```euo example on the site must be a whole script that runs as pasted: see "The examples" below.
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
# 'page#n' (the n-th euo block on the page) -> why that example stays a fragment
$ExampleFragments = @{
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

# ---- MENU: which logic has it ----------------------------------------------------------------------------
# Every MENU page says which MENU logic has it (menuLogic: ['1.5', '1.6'], docs/menu-1.6-analysis.md). For a
# first-level page (menu text) that must be what the two dispatchers say; a deeper page (menu font transparent)
# may have fewer, as long as its element has them. A page marked menuDiffers needs a "## 1.5 and 1.6" section.
$menuProblems = New-Object System.Collections.Generic.List[string]
foreach ($p in $pages.Values | Where-Object { $_.Kind -and $_.Slug -like 'commands/menu*' } | Sort-Object Slug) {
  $fm = [regex]::Match($p.Text, '^---\r?\n(.*?)\r?\n---', 'Singleline').Groups[1].Value
  $logicLine = [regex]::Match($fm, '(?m)^menuLogic:\s*\[(.*)\]')
  if (-not $logicLine.Success) { $menuProblems.Add("$($p.Slug): no menuLogic"); continue }
  $have = @([regex]::Matches($logicLine.Groups[1].Value, '["'']([^"'']+)["'']') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
  $parts = $p.Slug.Split('/')
  if ($parts.Count -lt 3) { $want = @('1.5', '1.6') }
  else {
    $e = $parts[2].ToUpper()
    $want = @()
    if ($names.Menu15 -contains $e -or $names.MenuShared -contains $e) { $want += '1.5' }
    if ($names.Menu16 -contains $e -or $names.MenuShared -contains $e) { $want += '1.6' }
  }
  if ($parts.Count -le 3) {
    if (($have -join ',') -ne ($want -join ',')) {
      $menuProblems.Add("$($p.Slug): menuLogic [$($have -join ', ')], the interpreter has it in [$($want -join ', ')]")
    }
  }
  elseif ($have.Count -eq 0 -or @($have | Where-Object { $want -notcontains $_ }).Count -gt 0) {
    $menuProblems.Add("$($p.Slug): menuLogic [$($have -join ', ')] is not within its element's [$($want -join ', ')]")
  }
}
foreach ($p in $pages.Values | Sort-Object Slug) {
  if ($p.Text -match '(?m)^menuDiffers:\s*true' -and $p.Text -notmatch '(?m)^## 1\.5 and 1\.6\s*$') {
    $menuProblems.Add("$($p.Slug): menuDiffers is set but there is no '## 1.5 and 1.6' section")
  }
}

# ---- the examples ----------------------------------------------------------------------------------------
# Every example is a whole script a reader can paste and run. It ends with halt or stop, because reaching the
# end of a script would restart it; or with a plain goto back into an endless main loop, which never reaches
# the end. Subs may follow that line. A file meant to be called (a block with a title="...") may end with
# exit instead. A last line that an if (or a loop) controls does not count: when it is skipped, the script
# runs off its end. Exceptions are in $ExampleFragments.
$conditional = @('if', 'else', 'while', 'for', 'onhotkey', 'cmppix')
function Test-Ending([string[]]$words, [int]$i, [string[]]$want) {
  if ($i -lt 0) { return $false }
  ($want -contains $words[$i] -or $words[$i] -eq 'goto') -and ($i -eq 0 -or $conditional -notcontains $words[$i - 1])
}
$exampleProblems = New-Object System.Collections.Generic.List[string]
foreach ($p in $pages.Values | Sort-Object Slug) {
  $page = if ($p.Slug) { $p.Slug } else { 'index' }
  $n = 0
  foreach ($m in [regex]::Matches($p.Text, '```euo([^\r\n]*)\r?\n(.*?)```', 'Singleline')) {
    $n++
    if ($ExampleFragments.ContainsKey("${page}#${n}")) { continue }
    $words = @($m.Groups[2].Value -split '\r?\n' | ForEach-Object { ($_ -split ';')[0].Trim() } | Where-Object { $_ } |
               ForEach-Object { ($_ -split '\s+')[0].ToLower() })
    $want = if ($m.Groups[1].Value -match 'title=') { @('halt', 'stop', 'exit') } else { @('halt', 'stop') }
    $ok = Test-Ending $words ($words.Count - 1) $want
    for ($i = 1; -not $ok -and $i -lt $words.Count; $i++) {
      if ($words[$i] -eq 'sub') { $ok = Test-Ending $words ($i - 1) $want }
    }
    if (-not $ok) {
      $exampleProblems.Add("${page}#${n}: does not end with $($want -join ' or ') (or an endless goto loop)")
    }
  }
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
if ($menuProblems.Count -gt 0) {
  Write-Host "Docs coverage: $($menuProblems.Count) problems on the MENU pages:" -ForegroundColor Red
  $menuProblems | ForEach-Object { Write-Host "  $_" }
  Write-Host "Set menuLogic to the logics that have the sub-command, and give a menuDiffers page its '## 1.5 and 1.6' section."
  $failed = $true
}
if ($exampleProblems.Count -gt 0) {
  Write-Host "Docs coverage: $($exampleProblems.Count) examples are not whole scripts:" -ForegroundColor Red
  $exampleProblems | ForEach-Object { Write-Host "  $_" }
  Write-Host "End the example with halt so it runs as pasted (see website\README.md), or list it in `$ExampleFragments with a reason."
  $failed = $true
}
if ($failed) { exit 1 }
$dllNote = if ($dllOn) { '' } else { ' (uo.dll section not started: not checked)' }
Write-Host "Docs coverage OK: all $checked variables, commands and sub-commands have a page$dllNote."
