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
#   Menu        'menu <element>' first words of either MENU logic ('menu font align' -> FONT):
#   Menu15        the 1.5 logic's, the same tests in MenuProcSync
#   Menu16        the 1.6 logic's, from the Sub='...' tests in TMenu16.Run (parser\EuoMenu16.pas)
#   MenuShared    the ones MenuProc handles for both logics before either runs (REFORGE)
#   Menu16Kinds the 1.6 logic's control types, the MT_* constants in EuoMenu16.pas's interface
#               ('FORM', 'PANEL', ...; MT_DEFAULT included)
#   Menu16Props the property names of its table (Props in EuoMenu16.pas)
#   Designer    what the MENU designer covers, from tools\EUOMenuDesigner\mdtypes.pas:
#               Types (rows of MdTypeRows: Name, Kind), Props (MdProps), Subs (MdSubsWritten,
#               MdSubsRead, MdSubsRuntime) and Excluded (MdExcluded)
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

# A Pascal array's quoted strings, with // comments taken out first (so a comment may hold a quote).
function Get-EuoCommentedArray([string]$text, [string]$arrayName, [string]$file) {
  $m = [regex]::Match($text, "$arrayName\s*:\s*Array\[[^\]]*\]\s*of\s*String\s*=\s*\((.*?)\);\s*(?:\r?\n|//)", 'Singleline,IgnoreCase')
  if (-not $m.Success) { throw "Could not find $arrayName in $file" }
  $body = $m.Groups[1].Value -replace '//[^\r\n]*', ''
  [regex]::Matches($body, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
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
  $menu16File = Join-Path $EuoRoot 'parser\EuoMenu16.pas'
  $mdFile     = Join-Path $EuoRoot 'tools\EUOMenuDesigner\mdtypes.pas'
  $interp = Get-Content $interpFile -Raw
  $menu16 = Get-Content $menu16File -Raw
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

  $run16 = [regex]::Match($menu16, "procedure TMenu16\.Run\(Pars : TParList\);(.*?)\r?\nend;", 'Singleline')
  if (-not $run16.Success) { throw "Could not find TMenu16.Run in $menu16File" }
  $menu15Names = @(& $subTypes (Get-EuoProcBody $interp 'MenuProcSync' $interpFile))
  $menu16Names = @(& $subTypes $run16.Groups[1].Value "Sub='([A-Z]+)'")
  $menuShared  = @(& $subTypes (Get-EuoProcBody $interp 'MenuProc' $interpFile) | Where-Object { $menu15Names -notcontains $_ })

  $menu16Intf  = ($menu16 -split '(?m)^implementation\b', 2)[0]
  $menu16Kinds = @([regex]::Matches($menu16Intf, '(?m)^\s*MT_([A-Z0-9_]+)\s*=\s*\$[0-9A-Fa-f]+\s*;') | ForEach-Object { $_.Groups[1].Value })
  $props = [regex]::Match($menu16, 'Props\s*:\s*array\[[^\]]*\]\s*of\s*TPropRow\s*=\s*\((.*?)\);', 'Singleline')
  if ($menu16Kinds.Count -eq 0 -or -not $props.Success) { throw "Could not find the MT_* types / Props in $menu16File" }
  $menu16Props = @([regex]::Matches($props.Groups[1].Value, "Name:\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

  $md = Get-Content $mdFile -Raw
  $mdRows = [regex]::Match($md, 'MdTypeRows\s*:\s*array\[[^\]]*\]\s*of\s*TMdTypeRow\s*=\s*\((.*?)\);\s*\r?\n', 'Singleline')
  $mdProps = [regex]::Match($md, 'MdProps\s*:\s*array\[[^\]]*\]\s*of\s*TMdPropRow\s*=\s*\((.*?)\);\s*\r?\n', 'Singleline')
  if (-not $mdRows.Success -or -not $mdProps.Success) { throw "Could not find MdTypeRows / MdProps in $mdFile" }
  $designer = [pscustomobject]@{
    Types    = @([regex]::Matches($mdRows.Groups[1].Value, "Name:\s*'([^']+)';\s*Kind:\s*MT_([A-Z0-9_]+)") |
                 ForEach-Object { [pscustomobject]@{ Name = $_.Groups[1].Value; Kind = $_.Groups[2].Value } })
    Props    = @([regex]::Matches($mdProps.Groups[1].Value, "Name:\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    Subs     = @(@(Get-EuoCommentedArray $md 'MdSubsWritten' $mdFile) + @(Get-EuoCommentedArray $md 'MdSubsRead' $mdFile) +
                 @(Get-EuoCommentedArray $md 'MdSubsRuntime' $mdFile))
    Excluded = @(Get-EuoCommentedArray $md 'MdExcluded' $mdFile)
  }

  $rw = @(Get-EuoPascalArray $interp 'VarNamesRW' $interpFile)
  [pscustomobject]@{
    Variables   = @(Get-EuoPascalArray $interp 'VarNamesR' $interpFile) + $rw
    ReadWrite   = $rw
    Commands    = @([regex]::Matches($interp, "CmdRegistry\.Register\('([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    Events      = @(& $subTypes (Get-EuoProcBody $interp 'EventProc' $interpFile))
    ExEvents    = @(& $subTypes (Get-EuoProcBody $interp 'ExEventProc' $interpFile))
    Menu        = @(@($menu15Names) + @($menu16Names) + @($menuShared) | Sort-Object -Unique)
    Menu15      = $menu15Names
    Menu16      = $menu16Names
    MenuShared  = $menuShared
    Menu16Kinds = $menu16Kinds
    Menu16Props = $menu16Props
    Designer    = $designer
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
