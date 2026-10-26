---
title: "path Step"
description: "Moves a walk on and returns at once, so the script can do other things while the character walks."
kind: subcommand
category: path
syntax: "path step"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathCnt", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path walk", "path go", "path stop", "path find"]
aliases: ["walk in background"]
---

`path step` moves a walk on and returns at once. Call it in a loop: between two calls the script can heal,
read the journal or fight, while the character keeps walking.
[`#PathState`](/variables/pathstate/) stays `walking` until the walk ends; then it says how it ended, as
for [`path go`](/commands/path/go/).

```euo
path find 1434 1699
if #PathState <> ok
  halt
repeat
  path step
  if #HITS < 40
    gosub heal
  wait 1
until #PathState <> walking
event SysMessage Walk over: #PathState
```

## Details

- The first `path step` starts walking the route of the last [`path find`](/commands/path/find/) (or
  [`path go`](/commands/path/go/)), as [`path walk`](/commands/path/walk/) would. Each one after it looks
  where the character is and sends what comes next: one step, the Open Door macro, or in client mode a
  point for the client's pathfinder. It never waits.
- Call it often: every tick (`wait 1`) or so. The walk only goes on while `path step` is called.
- Stop the walk with [`path stop`](/commands/path/stop/). A new [`path find`](/commands/path/find/) also
  ends it.
- After the walk has ended, the next `path step` starts walking toward the same goal again.

## Reforged notes

New in EasyUO Reforged.
