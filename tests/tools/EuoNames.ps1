# The interpreter's vocabulary, read straight from the source, for the coverage checks
# (CheckSelfTestCoverage.ps1, CheckDocsCoverage.ps1). Dot-source it:
#
#   . (Join-Path $PSScriptRoot 'EuoNames.ps1')
#   $names = Get-EuoNames
#
# Get-EuoNames returns:
#   Variables   #variable names, from VarNamesR / VarNamesRW in parser\EuoInterpreter.pas
#   ReadWrite   the subset a script can set (VarNamesRW)
#   Commands    script commands, from the CmdRegistry.Register(...) calls
#   Events      'event <type>' types, from the ParList[1].StrU='...' tests in EventProc
#   ExEvents    'exevent <type>' types, the same in ExEventProc
#   Menu        'menu <element>' first words, the same in MenuProcSync ('menu font align' -> FONT)
#   NameSpace   'namespace <action>' actions, the same in NameSpaceProc
#   Str         'str <operation>' operations, the same in StrProc
#   Sql         'sql <command>' sub-commands, from the Sub='...' tests in SqlProc
#   Path        'path <command>' sub-commands, the same in PathProc
#   DllMembers  uo.dll names (properties, methods), from UOTbl in uo\uowrap.pas
#   DllCalls    uo.dll generic calls (Call, Get, Set, ...), from Commands in uo\uowrap.pas
#   Highlighted the #variables and commands easyuo\eusyntax.pas colours and offers for autocomplete
#   Completion  the sub-command lists autocomplete offers, from SubCommands in easyuo\eucomplete.pas:
#               key (the words before, 'MENU FONT') -> the words it offers there

$EuoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Get-EuoPascalArray([string]$text, [string]$arrayName, [string]$file) {
  $m = [regex]::Match($text, "$arrayName\s*:\s*Array\[[^\]]*\]\s*of\s*String\s*=\s*\((.*?)\);", 'Singleline,IgnoreCase')
  if (-not $m.Success) { throw "Could not find $arrayName in $file" }
  [regex]::Matches($m.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
}

function Get-EuoProcBody([string]$text, [string]$procName, [string]$file) {
  $m = [regex]::Match($text, "procedure TEuoInterpreter\.$procName;(.*?)\r?\nend;", 'Singleline')
  if (-not $m.Success) { throw "Could not find TEuoInterpreter.$procName in $file" }
  $m.Groups[1].Value
}

function Get-EuoNames {
  $interpFile = Join-Path $EuoRoot 'parser\EuoInterpreter.pas'
  $wrapFile   = Join-Path $EuoRoot 'uo\uowrap.pas'
  $synFile    = Join-Path $EuoRoot 'easyuo\eusyntax.pas'
  $complFile  = Join-Path $EuoRoot 'easyuo\eucomplete.pas'
  $interp = Get-Content $interpFile -Raw
  $wrap   = Get-Content $wrapFile -Raw
  $syn    = Get-Content $synFile -Raw
  $compl  = (Get-Content $complFile -Raw) -replace "'\s*\+\s*'", ''   # join 'a ' + 'b' literals

  $completion = [ordered]@{}
  foreach ($entry in Get-EuoPascalArray $compl 'SubCommands' $complFile) {
    $key, $words = $entry.Split('=', 2)
    $completion[$key] = @($words.Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
  }

  $subTypes = {
    param($body, $pattern = "ParList\[1\]\.StrU='([A-Z]+)'")
    [regex]::Matches($body, $pattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  }
  $uoTbl = [regex]::Match($wrap, 'UOTbl\s*:\s*array\[[^\]]*\]\s*of\s*TItem\s*=\s*\((.*?)\);', 'Singleline')
  $calls = [regex]::Match($wrap, 'Commands\s*:\s*array\[[^\]]*\]\s*of\s*TItem\s*=\s*\((.*?)\);', 'Singleline')
  if (-not $uoTbl.Success -or -not $calls.Success) { throw "Could not find UOTbl / Commands in $wrapFile" }
  $itemNames = { param($m) [regex]::Matches($m.Groups[1].Value, "N:\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique }

  $rw = @(Get-EuoPascalArray $interp 'VarNamesRW' $interpFile)
  [pscustomobject]@{
    Variables   = @(Get-EuoPascalArray $interp 'VarNamesR' $interpFile) + $rw
    ReadWrite   = $rw
    Commands    = @([regex]::Matches($interp, "CmdRegistry\.Register\('([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    Events      = @(& $subTypes (Get-EuoProcBody $interp 'EventProc' $interpFile))
    ExEvents    = @(& $subTypes (Get-EuoProcBody $interp 'ExEventProc' $interpFile))
    Menu        = @(& $subTypes (Get-EuoProcBody $interp 'MenuProcSync' $interpFile))
    NameSpace   = @(& $subTypes (Get-EuoProcBody $interp 'NameSpaceProc' $interpFile))
    Str         = @(& $subTypes (Get-EuoProcBody $interp 'StrProc' $interpFile))
    Sql         = @(& $subTypes (Get-EuoProcBody $interp 'SqlProc' $interpFile) "Sub\s*(?:=|<>)\s*'([A-Z]+)'")
    Path        = @(& $subTypes (Get-EuoProcBody $interp 'PathProc' $interpFile) "Sub\s*(?:=|<>)\s*'([A-Z]+)'")
    DllMembers  = @(& $itemNames $uoTbl)
    DllCalls    = @(& $itemNames $calls)
    Highlighted = [pscustomobject]@{
      Variables = @(Get-EuoPascalArray $syn 'SystemKeywords' $synFile | ForEach-Object { $_.TrimStart('#') })
      Commands  = @(Get-EuoPascalArray $syn 'CommandKeywords' $synFile)
    }
    Completion  = $completion
  }
}
