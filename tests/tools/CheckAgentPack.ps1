# Checks the agent pack (docs\agent-support.md, phase 1): what AI coding agents read to write EasyUO scripts.
#
# It builds the pack into a temporary folder with tools\docs\gen-agent-pack.mjs, which fails by itself on a
# documentation page it cannot read, and then checks, against the names and facts read from the source
# (EuoNames.ps1):
#
#   The lists   every script command and sub-command of the interpreter is in euo-script\commands.md, as the
#               start of a syntax (`finditem ...`, `event macro ...`, `str len ...`), and every #variable is in
#               euo-script\variables.md.
#   The rules   euo-script\language.md is built from three pages of the site (RULES in the generator). Its
#               "Which commands do what" table must say what the command handlers do: which calculate (call
#               Eval), which take a block (call ScanForBlock), which take a time (call ParseTicksOrSeconds).
#   The flags   a command's page says needsClient exactly when the interpreter registers it as
#               client-dependent, since that is the [client] flag of the lists.
#   The gate    everything new or changed in Reforged (origin: reforged / changed: true on its page) is
#               mentioned in the rules, or is on $NoRuleNeeded with the reason. So nobody adds a command
#               without deciding whether an agent has to be told how to use it.
#
# The examples of the rules are checked in the FPCUnit suite, with the real code: tests\DocsLintTests.pas runs
# the script checker (parser\EuoLint.pas) over every example of the site and of agent\, and
# tests\DocsExampleTests.pas runs the ones that say what they give (their "; => %x = 5" comments).
#
# The generator needs Node.js (as the documentation site does). Without it the check is skipped with a
# warning, except in CI, where it fails.
#
# Usage:  pwsh ./tests/tools/CheckAgentPack.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'EuoNames.ps1')

# name -> why it is not in the pack
$NotInPack = @{
  'menu TEST' = 'empty debug hook: TMenuObj.Test does nothing (not documented either)'
}
# New or changed in Reforged, and the rules need not mention it: name (as a script writes it; a command name
# covers its sub-commands and the variables it sets) -> why. Everything else new or changed must be mentioned
# in a rules page (website\src\content\docs: language\common-mistakes.md, guides\patterns.md,
# guides\finding-ids.md).
$NoRuleNeeded = @{
  'tile'         = 'reads the map; a script that needs it reads its page, there is no pattern to teach'
  'scanbuffs'    = 'reads the buff bar; its page is enough'
  '#BuffBarOpen' = 'a plain value to read; nothing to get wrong'
  '#MountID'     = 'a plain value to read; nothing to get wrong'
  '#MountType'   = 'a plain value to read; nothing to get wrong'
  '#ReforgedVer' = 'the version of the program; scripts rarely need it'
}
# command -> why its page's needsClient differs from how the interpreter registers it
$ClientDiffers = @{
  'path' = 'registered as client-independent because it checks for a client itself: some sub-commands (path block, path from, ...) work without one. Its overview page says needsClient for the family; each sub-command page says its own'
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  if ($env:CI) { Write-Host 'Agent pack: Node.js is not installed, so the pack cannot be built.' -ForegroundColor Red; exit 1 }
  Write-Host 'Warning: agent pack not checked (Node.js is not installed).' -ForegroundColor Yellow
  exit 0
}

$out = Join-Path ([IO.Path]::GetTempPath()) "euo-agent-pack-$PID"
try {
  $log = & $node.Source (Join-Path $EuoRoot 'tools\docs\gen-agent-pack.mjs') --out $out 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Agent pack: the generator failed:' -ForegroundColor Red
    $log | ForEach-Object { Write-Host "  $_" }
    exit 1
  }
  $skill = Join-Path $out 'euo-script'
  $cmdText  = Get-Content (Join-Path $skill 'commands.md') -Raw
  $varText  = Get-Content (Join-Path $skill 'variables.md') -Raw
  $ruleText = Get-Content (Join-Path $skill 'language.md') -Raw
  $ref = Get-Content (Join-Path $skill 'reference.json') -Raw | ConvertFrom-Json
  $files = (Get-ChildItem $out -Recurse -File).Count
}
finally {
  if (Test-Path $out) { Remove-Item $out -Recurse -Force }
}

$names = Get-EuoNames
$problems = New-Object System.Collections.Generic.List[string]
$checked = 0

# ---- the lists: every name is on one ---------------------------------------------------------------------
# The syntaxes of commands.md: the `code` spans that open a list line or follow a ' / ' on it.
$syntaxes = @([regex]::Matches($cmdText, '(?m)^\s*- (`[^`]+`(?: / `[^`]+`)*)') | ForEach-Object {
  [regex]::Matches($_.Groups[1].Value, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.ToLower() }
})
function Test-Syntax([string]$start) {
  $s = $start.ToLower()
  @($syntaxes | Where-Object { $_ -eq $s -or $_.StartsWith("$s ") }).Count -gt 0
}
function Need([string]$label, [bool]$found) {
  $script:checked++
  if ($NotInPack.ContainsKey($label)) { return }
  if (-not $found) { $problems.Add("lists: $label is not in the pack's lists (it needs its documentation page, or an entry in `$NotInPack)") }
}
foreach ($c in $names.Commands | Sort-Object -Unique) { Need $c (Test-Syntax $c) }
$families = [ordered]@{
  event = $names.Events; exevent = $names.ExEvents; menu = $names.Menu; namespace = $names.NameSpace
  str = $names.Str; sql = $names.Sql; path = $names.Path
}
foreach ($f in $families.Keys) {
  foreach ($e in $families[$f]) { Need "$f $e" (Test-Syntax "$f $e") }
}
$listed = @{}
foreach ($m in [regex]::Matches($varText, '(?m)^- `#(\w+)`')) { $listed[$m.Groups[1].Value.ToLower()] = $true }
foreach ($v in $names.Variables | Sort-Object -Unique) { Need "#$v" $listed.ContainsKey($v.ToLower()) }

# ---- the rules: the table of what commands do ------------------------------------------------------------
$facts = $names.CommandFacts
$rows = [ordered]@{
  'Calculate'          = @($facts.Keys | Where-Object { $facts[$_].Calculates })
  'Take a .*block'     = @($facts.Keys | Where-Object { $facts[$_].TakesBlock })
  'Take a time'        = @($facts.Keys | Where-Object { $facts[$_].TakesTime })
}
foreach ($label in $rows.Keys) {
  $row = [regex]::Match($ruleText, "(?m)^\|\s*$label[^|]*\|(.*)\|\s*$")
  if (-not $row.Success) { $problems.Add("rules: language\common-mistakes.md has no table row starting with '$label' (section 'Which commands do what')"); continue }
  $said = @([regex]::Matches($row.Groups[1].Value, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.ToLower() } | Sort-Object)
  $real = @($rows[$label] | ForEach-Object { $_.ToLower() } | Sort-Object)
  if (($said -join ' ') -ne ($real -join ' ')) {
    $problems.Add("rules: the row '$($row.Value.Trim())' of language\common-mistakes.md lists [$($said -join ' ')], but in parser\EuoInterpreter.pas it is [$($real -join ' ')]. Correct the row, and rule 3 or 9 above it if they name the commands")
  }
}

# ---- the flags: needsClient is what the registry says ----------------------------------------------------
$byName = @{}
foreach ($c in $ref.commands) { $byName[$c.name] = $c }
foreach ($c in $facts.Keys) {
  $page = $byName[$c.ToLower()]
  if (-not $page -or $ClientDiffers.ContainsKey($c.ToLower())) { continue }
  if ([bool]$page.needsClient -ne [bool]$facts[$c].NeedsClient) {
    $problems.Add("flags: the page of '$($c.ToLower())' says needsClient: $("$($page.needsClient)".ToLower()), but the interpreter registers it with RequiresClient = $($facts[$c].NeedsClient). Correct the page, or list the command in `$ClientDiffers with the reason")
  }
}

# ---- the gate: new and changed things are in the rules, or need none -------------------------------------
# What the rules mention: the words of their code spans and examples.
$ruleCode = (@([regex]::Matches($ruleText, '(?s)```.*?```|`[^`\r\n]+`') | ForEach-Object { $_.Value }) -join "`n").ToLower()
function Test-Mentioned([string]$name) {
  $n = [regex]::Escape($name.ToLower())
  if ($name.StartsWith('#')) { return $ruleCode -match "$n(?!\w)" }
  $ruleCode -match "(?<![\w#%!*.])$n(?!\w)"
}
$noRule = @{}
foreach ($k in $NoRuleNeeded.Keys) { $noRule[$k.ToLower()] = $true }
function Test-CommandCovered($c) {
  $family = ($c.name -split ' ')[0]
  (Test-Mentioned $family) -or $noRule.ContainsKey($c.name) -or $noRule.ContainsKey($family)
}
$gated = 0
foreach ($c in $ref.commands | Where-Object { $_.origin -eq 'reforged' -or $_.changed }) {
  $gated++
  if (-not (Test-CommandCovered $c)) {
    $problems.Add("gate: '$($c.name)' is new or changed in Reforged, but the rules never mention '$(($c.name -split ' ')[0])'")
  }
}
foreach ($v in $ref.variables | Where-Object { $_.origin -eq 'reforged' -or $_.changed }) {
  $gated++
  $title = $v.title.ToLower()
  $setters = @($ref.commands | Where-Object { @($_.sets | ForEach-Object { $_.ToLower() }) -contains $title })
  $covered = (Test-Mentioned $title) -or $noRule.ContainsKey($title) -or @($setters | Where-Object { Test-CommandCovered $_ }).Count -gt 0
  if (-not $covered) { $problems.Add("gate: $($v.title) is new or changed in Reforged, but the rules mention neither it nor a command that sets it") }
}
foreach ($k in $NoRuleNeeded.Keys) {
  $known = @($ref.commands | Where-Object { $_.name -eq $k.ToLower() }).Count + @($ref.variables | Where-Object { $_.title -eq $k }).Count
  if ($known -eq 0) { $problems.Add("gate: `$NoRuleNeeded lists '$k', which is not a command or variable of the pack") }
}

if ($problems.Count -gt 0) {
  Write-Host "Agent pack: $($problems.Count) problems:" -ForegroundColor Red
  $problems | ForEach-Object { Write-Host "  $_" }
  Write-Host 'The rules are three pages of the site: language\common-mistakes.md, guides\patterns.md and guides\finding-ids.md'
  Write-Host '(website\src\content\docs). Something new that an agent has to be told about goes there; something that needs'
  Write-Host 'no rule goes in $NoRuleNeeded of this script, with the reason.'
  exit 1
}
Write-Host "Agent pack OK: $files files; all $checked commands, sub-commands and variables are on its lists."
Write-Host "Agent rules OK: the table of what commands do matches the interpreter; all $gated new or changed commands and variables are in the rules or need none."
