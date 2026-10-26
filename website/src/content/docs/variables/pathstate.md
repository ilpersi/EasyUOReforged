---
title: "#PathState"
description: "How the last path command went: ok, a reason no route was found, or the error."
kind: variable
category: path
access: ro
type: string
origin: reforged
related: ["Path", "path find", "#PathCnt"]
aliases: ["path result", "path error"]
---

`#PathState` says how the last [`path`](/commands/path/) command went:

| Value | Meaning |
|---|---|
| `ok` | It worked. After [`path find`](/commands/path/find/): a route was found. |
| `nopath` | There is no way to the goal. |
| `budget` | The search looked at `maxnodes` places without finding a way (see [`path set`](/commands/path/set/)). |
| `timeout` | The search took longer than `timeout`. |
| `stopped` | You pressed Stop during the search. |
| `blocked` | [`path can`](/commands/path/can/): nothing to stand on there. |
| `noclient` | No client is attached, and no [`path from`](/commands/path/from/) is set. |
| `nomap` | The client's folder lacks the map files of this facet. |
| `error: …` | The arguments are wrong; the rest says what. |

It reads `N/A` until the script runs its first `path` command. A `path` line never stops the script, so
check `#PathState` after the commands that matter.

## Example

```euo
path find 1434 1699
if #PathState <> ok
  event SysMessage No route: #PathState
```
