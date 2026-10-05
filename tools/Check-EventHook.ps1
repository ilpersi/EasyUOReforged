<#
.SYNOPSIS
  Read-only check of the event hook EasyUO/Reforged installs in a running UO client.

.DESCRIPTION
  Reforged's Event/ExEvent commands work by rewriting one `call` in the client so it
  goes through a small code cave at $400600 (uo\uoevents.pas, "code caving"). The cave
  ends with `push <original function>; ret`.

  Reforged before commit 37d4bfe could, on re-attaching to an already-hooked client,
  mistake the cave for the original function and write `push $400600` into it. The cave
  then jumps to itself forever and the client freezes (only Task Manager can end it).

  This script only READS the client's memory -- it never writes to it -- and reports
  which of these states the client is in. Run it against a frozen client to confirm or
  rule out that bug.

  Exit code: 0 = not hooked or hooked correctly, 1 = POISONED (the freeze bug),
             2 = could not check.

.PARAMETER ProcessId
  PID of the client. If omitted, every running process named "client" is checked.

.PARAMETER Name
  Process name to look for when -ProcessId is not given (default: client).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Check-EventHook.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Check-EventHook.ps1 -ProcessId 12345
#>
param(
  [int]$ProcessId = 0,
  [string]$Name = 'client'
)

$ErrorActionPreference = 'Stop'

if (-not ('EuoHookProbe' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class EuoHookProbe {
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern IntPtr OpenProcess(int access, bool inherit, int pid);
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out IntPtr read);
  [DllImport("kernel32.dll")]
  public static extern bool CloseHandle(IntPtr h);
}
'@
}

# Same values as uo\uoevents.pas / uo\uoclidata.pas (E_REDIR scan entry, EVENT_CAVE_BASE).
$ImageBase = 0x400000
$ScanEnd   = 0x650000
$CaveBase  = 0x400600
$Signature = [byte[]](0x33, 0xDB, 0x53, 0x53, 0x50, 0xE8)   # xor ebx,ebx; push ebx; push ebx; push eax; call

function Read-Remote($Handle, [int64]$Addr, [int]$Size) {
  $buf = New-Object byte[] $Size
  $read = [IntPtr]::Zero
  if (-not [EuoHookProbe]::ReadProcessMemory($Handle, [IntPtr]$Addr, $buf, $Size, [ref]$read)) { return $null }
  if ([int64]$read -lt $Size) { return $null }
  return $buf
}

function Test-Client([int]$TargetPid) {
  $h = [EuoHookProbe]::OpenProcess(0x0410, $false, $TargetPid)   # VM_READ | QUERY_INFORMATION
  if ($h -eq [IntPtr]::Zero) {
    Write-Host "  Cannot open process $TargetPid for reading (run from an elevated prompt if the client is elevated)."
    return 2
  }
  try {
    # Find the hook site. Blocks overlap by the signature length so a match can't straddle two reads.
    $chunk = 0x4000
    $site = $null
    for ($a = $ImageBase; $a -lt $ScanEnd -and $null -eq $site; $a += $chunk - $Signature.Length) {
      $buf = Read-Remote $h $a $chunk
      if ($null -eq $buf) { break }
      for ($i = 0; $i -le $chunk - $Signature.Length - 4; $i++) {
        $hit = $true
        for ($j = 0; $j -lt $Signature.Length; $j++) {
          if ($buf[$i + $j] -ne $Signature[$j]) { $hit = $false; break }
        }
        if ($hit) {
          $callAddr = $a + $i + 5
          $rel = [BitConverter]::ToInt32($buf, $i + 6)
          $site = @{ Call = $callAddr; Target = ($callAddr + 5 + $rel) -band 0xFFFFFFFF }
          break
        }
      }
    }
    if ($null -eq $site) {
      Write-Host '  Hook site signature not found -- is this a supported UO client (6.0.6.2 or newer)?'
      return 2
    }
    Write-Host ('  Hook site: call at 0x{0:X8}, currently targets 0x{1:X8}' -f $site.Call, $site.Target)

    if ($site.Target -ne $CaveBase) {
      Write-Host '  RESULT: not hooked (the call still goes to the client''s own function). Nothing to fix.'
      return 0
    }

    $cave = Read-Remote $h $CaveBase 5
    if ($null -eq $cave) {
      Write-Host '  RESULT: call goes to the code cave but the cave cannot be read.'
      return 2
    }
    Write-Host ('  Cave at 0x{0:X8}: {1}' -f $CaveBase, (($cave | ForEach-Object { $_.ToString('X2') }) -join ' '))

    if ($cave[0] -ne 0x68) {
      Write-Host '  RESULT: call goes to the cave, but the cave does not start with the expected "push imm32". Unknown state.'
      return 2
    }
    $pushed = [BitConverter]::ToUInt32($cave, 1)
    if ($pushed -eq $CaveBase -or $pushed -eq 0) {
      Write-Host ('  RESULT: POISONED. The cave pushes 0x{0:X8} and returns into itself -- an endless loop.' -f $pushed)
      Write-Host '          This is the re-attach freeze bug. Kill the client; it cannot recover.'
      return 1
    }
    Write-Host ('  RESULT: hooked correctly. The cave hands off to the original function at 0x{0:X8}.' -f $pushed)
    return 0
  } finally {
    [void][EuoHookProbe]::CloseHandle($h)
  }
}

if ($ProcessId -gt 0) {
  $pids = @($ProcessId)
} else {
  $pids = @(Get-Process -Name $Name -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
  if ($pids.Count -eq 0) {
    Write-Host "No running process named '$Name' found. Use -ProcessId or -Name."
    exit 2
  }
}

$worst = 0
foreach ($p in $pids) {
  Write-Host "Client PID ${p}:"
  $code = Test-Client $p
  if ($code -gt $worst -and $worst -ne 1) { $worst = $code }
  if ($code -eq 1) { $worst = 1 }
}
exit $worst
