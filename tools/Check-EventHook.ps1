<#
.SYNOPSIS
  Read-only check of the event hook EasyUO/Reforged installs in a running UO client, plus a
  report of which threads are burning CPU and where.

.DESCRIPTION
  Reforged's Event/ExEvent commands work by rewriting one `call` in the client so it
  goes through a small code cave at $400600 (uo\uoevents.pas, "code caving"). The cave
  ends with `push <original function>; ret`.

  Reforged before commit 37d4bfe could, on re-attaching to an already-hooked client,
  mistake the cave for the original function and write `push $400600` into it. The cave
  then jumps to itself forever and the client freezes (only Task Manager can end it).

  Step 1 (hook): reads the client's memory -- it never writes to it -- and reports whether
  the hook is absent, healthy or POISONED (the freeze bug above).

  Step 2 (busy threads): a frozen client is often a thread stuck in a loop. The script
  measures each thread's CPU use over ~2 seconds and, for any thread using at least half a
  core, samples its instruction pointer several times (each sample suspends that thread for
  a fraction of a millisecond and resumes it straight away) and names the module it is
  executing in. If it is executing inside the event cave the freeze is Reforged's; if it is
  in some other module (client.exe, another injected DLL, ...) the hook is not the cause.
  Use -NoThreadCheck to skip this step and keep the script strictly read-only.

  Exit code: 0 = nothing wrong found, 1 = POISONED hook or a thread spinning inside the
             event cave, 2 = could not check.

.PARAMETER ProcessId
  PID of the client. If omitted, every running process named "client" is checked.

.PARAMETER Name
  Process name to look for when -ProcessId is not given (default: client).

.PARAMETER NoThreadCheck
  Skip the busy-thread report (no thread is ever suspended).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Check-EventHook.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Check-EventHook.ps1 -ProcessId 12345
#>
param(
  [int]$ProcessId = 0,
  [string]$Name = 'client',
  [switch]$NoThreadCheck
)

$ErrorActionPreference = 'Stop'

if (-not ('EuoHookProbe' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class EuoHookProbe {
  [StructLayout(LayoutKind.Sequential)]
  public struct ModInfo { public IntPtr Base; public int Size; public IntPtr Entry; }

  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern IntPtr OpenProcess(int access, bool inherit, int pid);
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out IntPtr read);
  [DllImport("kernel32.dll")]
  public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")]
  public static extern bool IsWow64Process(IntPtr h, out bool wow64);
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern IntPtr OpenThread(int access, bool inherit, int tid);
  [DllImport("kernel32.dll")]
  public static extern int SuspendThread(IntPtr h);
  [DllImport("kernel32.dll")]
  public static extern int ResumeThread(IntPtr h);
  [DllImport("kernel32.dll")]
  public static extern bool Wow64GetThreadContext(IntPtr h, byte[] ctx);
  [DllImport("psapi.dll", SetLastError = true)]
  public static extern bool EnumProcessModulesEx(IntPtr h, IntPtr[] mods, int cb, out int needed, int filter);
  [DllImport("psapi.dll", CharSet = CharSet.Unicode)]
  public static extern int GetModuleFileNameEx(IntPtr h, IntPtr mod, StringBuilder sb, int n);
  [DllImport("psapi.dll")]
  public static extern bool GetModuleInformation(IntPtr h, IntPtr mod, out ModInfo mi, int cb);
}
'@
}

# Same values as uo\uoevents.pas / uo\uoclidata.pas (E_REDIR scan entry, EVENT_CAVE_BASE).
$ImageBase = 0x400000
$ScanEnd   = 0x650000
$CaveBase  = 0x400600
$CaveLow   = 0x4005FC     # flag/result words sit just below the cave
$CaveHigh  = 0x400700     # event code + scratch buffers end well before this
$Signature = [byte[]](0x33, 0xDB, 0x53, 0x53, 0x50, 0xE8)   # xor ebx,ebx; push ebx; push ebx; push eax; call

# Busy-thread check tuning.
$CpuWindowMs  = 2000      # how long to measure per-thread CPU use
$BusyFraction = 0.5       # a thread is "busy" at >= this fraction of one core
$IpSamples    = 8         # instruction-pointer samples per busy thread

function Read-Remote($Handle, [int64]$Addr, [int]$Size) {
  $buf = New-Object byte[] $Size
  $read = [IntPtr]::Zero
  if (-not [EuoHookProbe]::ReadProcessMemory($Handle, [IntPtr]$Addr, $buf, $Size, [ref]$read)) { return $null }
  if ([int64]$read -lt $Size) { return $null }
  return $buf
}

function Merge-Code([int]$A, [int]$B) {
  if ($A -eq 1 -or $B -eq 1) { return 1 }
  if ($A -eq 2 -or $B -eq 2) { return 2 }
  return 0
}

function Test-Hook($Handle) {
  # Find the hook site. Blocks overlap by the signature length so a match can't straddle two reads.
  $chunk = 0x4000
  $site = $null
  for ($a = $ImageBase; $a -lt $ScanEnd -and $null -eq $site; $a += $chunk - $Signature.Length) {
    $buf = Read-Remote $Handle $a $chunk
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

  $cave = Read-Remote $Handle $CaveBase 5
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
}

function Get-ModuleMap($Handle) {
  $mods = New-Object IntPtr[] 1024
  $needed = 0
  if (-not [EuoHookProbe]::EnumProcessModulesEx($Handle, $mods, $mods.Length * [IntPtr]::Size, [ref]$needed, 3)) { return @() }
  $map = @()
  for ($i = 0; $i -lt [Math]::Min($needed / [IntPtr]::Size, $mods.Length); $i++) {
    $sb = New-Object System.Text.StringBuilder 520
    [void][EuoHookProbe]::GetModuleFileNameEx($Handle, $mods[$i], $sb, 520)
    $mi = New-Object EuoHookProbe+ModInfo
    if (-not [EuoHookProbe]::GetModuleInformation($Handle, $mods[$i], [ref]$mi, [Runtime.InteropServices.Marshal]::SizeOf($mi))) { continue }
    $base = $mi.Base.ToInt64()
    $map += [pscustomobject]@{ Base = $base; End = $base + $mi.Size; Name = (Split-Path $sb.ToString() -Leaf); Path = $sb.ToString() }
  }
  return $map
}

function Resolve-Address($Map, [int64]$Addr) {
  foreach ($m in $Map) {
    if ($Addr -ge $m.Base -and $Addr -lt $m.End) { return ('{0}+0x{1:X}' -f $m.Name, ($Addr - $m.Base)) }
  }
  return ('0x{0:X8} (no module)' -f $Addr)
}

function Get-ThreadCpu([int]$TargetPid) {
  $cpu = @{}
  $p = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
  if ($p) {
    foreach ($t in $p.Threads) {
      try { $cpu[$t.Id] = $t.TotalProcessorTime.TotalMilliseconds } catch { }   # thread may have exited
    }
  }
  return $cpu
}

# Returns 1 if a busy thread is executing inside the event cave, 2 if it could not check, else 0.
function Test-BusyThreads($Handle, [int]$TargetPid) {
  $wow = $false
  if (-not [EuoHookProbe]::IsWow64Process($Handle, [ref]$wow) -or -not $wow) {
    Write-Host '  Thread check skipped: the client is not a 32-bit process under WOW64.'
    return 0
  }

  Write-Host ("  Measuring thread CPU use over {0:N1}s ..." -f ($CpuWindowMs / 1000))
  $before = Get-ThreadCpu $TargetPid
  Start-Sleep -Milliseconds $CpuWindowMs
  $after = Get-ThreadCpu $TargetPid

  $busy = @()
  foreach ($tid in $after.Keys) {
    if (-not $before.ContainsKey($tid)) { continue }
    $frac = [Math]::Min(1.0, ($after[$tid] - $before[$tid]) / $CpuWindowMs)
    if ($frac -ge $BusyFraction) { $busy += [pscustomobject]@{ Tid = $tid; Frac = $frac } }
  }
  if ($busy.Count -eq 0) {
    Write-Host ('  No busy threads (none used >= {0:P0} of a core). If the client is frozen it is waiting, not spinning.' -f $BusyFraction)
    return 0
  }

  $map = Get-ModuleMap $Handle
  $result = 0
  foreach ($b in ($busy | Sort-Object Frac -Descending)) {
    Write-Host ('  Busy thread {0}: {1:P0} of a core' -f $b.Tid, $b.Frac)
    $th = [EuoHookProbe]::OpenThread(0x004A, $false, $b.Tid)   # SUSPEND_RESUME | GET_CONTEXT | QUERY_INFORMATION
    if ($th -eq [IntPtr]::Zero) {
      Write-Host '    Cannot open the thread to sample it (run from an elevated prompt if the client is elevated).'
      $result = Merge-Code $result 2
      continue
    }
    $samples = @()
    try {
      $ctx = New-Object byte[] 716                          # WOW64_CONTEXT
      for ($s = 0; $s -lt $IpSamples; $s++) {
        [BitConverter]::GetBytes([uint32]0x10003).CopyTo($ctx, 0)   # CONTEXT_i386 | CONTROL | INTEGER
        if ([EuoHookProbe]::SuspendThread($th) -eq -1) { continue }
        try {
          $ok = [EuoHookProbe]::Wow64GetThreadContext($th, $ctx)
          if ($ok) {
            $eip = [int64][BitConverter]::ToUInt32($ctx, 184)
            $esp = [int64][BitConverter]::ToUInt32($ctx, 196)
            $stack = Read-Remote $Handle $esp 0x200
            $samples += [pscustomobject]@{ Eip = $eip; Stack = $stack }
          }
        } finally {
          [void][EuoHookProbe]::ResumeThread($th)
        }
        Start-Sleep -Milliseconds 100
      }
    } finally {
      [void][EuoHookProbe]::CloseHandle($th)
    }
    if ($samples.Count -eq 0) {
      Write-Host '    Could not read this thread''s context.'
      $result = Merge-Code $result 2
      continue
    }

    $groups = $samples | Group-Object { Resolve-Address $map $_.Eip } | Sort-Object Count -Descending
    Write-Host ('    Executing in ({0} samples): {1}' -f $samples.Count, (($groups | ForEach-Object { '{0}x {1}' -f $_.Count, $_.Name }) -join ', '))

    # Possible callers: stack words that point into a module (a stack scan, so stale values can appear).
    $top = $samples | Where-Object { $_.Stack } | Select-Object -First 1
    if ($top) {
      $callers = @()
      for ($o = 0; $o -lt $top.Stack.Length -and $callers.Count -lt 6; $o += 4) {
        $v = [int64][BitConverter]::ToUInt32($top.Stack, $o)
        $r = Resolve-Address $map $v
        if ($r -notlike '*(no module)') { $callers += $r }
      }
      if ($callers.Count -gt 0) { Write-Host ('    Nearby stack addresses: {0}' -f ($callers -join ', ')) }
    }

    $inCave = @($samples | Where-Object { $_.Eip -ge $CaveLow -and $_.Eip -lt $CaveHigh }).Count
    if ($inCave -gt 0) {
      Write-Host ('    VERDICT: executing inside the event cave in {0} of {1} samples -- this freeze is the hook.' -f $inCave, $samples.Count)
      $result = Merge-Code $result 1
    } else {
      Write-Host ('    VERDICT: never inside the event cave (0x{0:X}-0x{1:X}); the hook is not what this thread is stuck on.' -f $CaveLow, $CaveHigh)
    }
  }
  return $result
}

function Test-Client([int]$TargetPid) {
  $h = [EuoHookProbe]::OpenProcess(0x0410, $false, $TargetPid)   # VM_READ | QUERY_INFORMATION
  if ($h -eq [IntPtr]::Zero) {
    Write-Host "  Cannot open process $TargetPid for reading (run from an elevated prompt if the client is elevated)."
    return 2
  }
  try {
    $code = Test-Hook $h
    if (-not $NoThreadCheck) {
      $code = Merge-Code $code (Test-BusyThreads $h $TargetPid)
    }
    return $code
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
  $worst = Merge-Code $worst $code
}
exit $worst
