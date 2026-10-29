---
title: "path Walk"
description: "Walks the route the last path find planned, waiting until the character gets there."
kind: subcommand
category: path
syntax: "path walk [timeout]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathCnt", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path find", "path go", "path step", "path stop"]
aliases: ["follow route"]
---

`path walk` walks the route [`path find`](/commands/path/find/) planned, to the goal it was planned for.
The script waits until the walk is over, as for [`path go`](/commands/path/go/), and
[`#PathState`](/variables/pathstate/) then says how it went: `arrived`, `blocked`, `failed`, `link`,
`timeout` or `stopped` (see [`path go`](/commands/path/go/)).

```euo
path find 1434 1699
if #PathState <> ok
  halt
display ok #PathCnt steps to the bank
path walk
halt
```

## Parameters

| Parameter | Meaning |
|---|---|
| `timeout` | Give up after this long: ticks of 50 ms, or seconds followed by `s`. Without it, there is no time limit. |

## Details

- The character doesn't need to stand at the start of the route: the walker finds it anywhere on the route.
  Off the route, for example after [`path from`](/commands/path/from/), it plans again from where the
  character stands, to the same goal.
- After a walk [`path step`](/commands/path/step/) started, `path walk` carries it on and waits for its end.
- After a walk that ended with `link`, `timeout` or `stopped`, `path walk` goes on toward the same goal, from
  where the character is now.
- Before any [`path find`](/commands/path/find/) or [`path go`](/commands/path/go/), there is nothing to
  walk: [`#PathState`](/variables/pathstate/) is `error: …`.

How the walk works, and what it sees, is described on [`path go`](/commands/path/go/#how-it-walks).

## Reforged notes

New in EasyUO Reforged.
