---
title: Troubleshooting
description: What to do when the client is not found or freezes, and how to report a bug so it can be fixed.
sidebar:
  order: 4
---

## "No supported UO client found!"

The client isn't running, your character isn't logged in, or the client version isn't supported yet. Start
the client and log in first, then start EasyUO Reforged. If the version is the problem, see
[Adding client support](https://github.com/ilpersi/EasyUOReforged/blob/main/docs/adding-client-support.md).

## The client freezes

If a UO client freezes (only Task Manager can end it) after EasyUO Reforged was closed and reopened, run
[`tools/Check-EventHook.ps1`](https://github.com/ilpersi/EasyUOReforged/blob/main/tools/Check-EventHook.ps1)
against it while it is frozen:

```powershell
powershell -ExecutionPolicy Bypass -File tools\Check-EventHook.ps1
```

It reads the client's memory and reports whether the event hook is absent, healthy, or in the "poisoned"
state older builds could leave behind. It also reports any thread burning CPU and which module it is
running in, which tells a hook freeze apart from one caused by something else in the client, such as
another injected DLL. To do that it briefly suspends and resumes the busy thread a few times; add
`-NoThreadCheck` to skip that and stay strictly read-only. Include its output in your bug report.

## Reporting a bug

Open an issue on [GitHub](https://github.com/ilpersi/EasyUOReforged/issues) with the **Bug report**
template. Two things make a report actionable:

- **It has to be reproducible.** Include a script that shows the problem on a fresh run. A bug that cannot
  be made to happen cannot be fixed.
- **Keep the script minimal**: the fewest lines that still show the problem, ideally under 20.

Also run
[`report-diagnostics.euo`](https://github.com/ilpersi/EasyUOReforged/blob/main/docs/report-diagnostics.euo)
with your client attached and paste its output into the report: it collects the client version, the shard
and the other details needed.

Found a mistake in this documentation? Every page has an **Edit page** link at the bottom.
