---
title: "path Stop"
description: "Ends the walk that path step is moving on."
kind: subcommand
category: path
syntax: "path stop"
origin: reforged
sets: ["#PathState"]
related: ["path step", "path walk", "path go"]
---

`path stop` ends the walk [`path step`](/commands/path/step/) has been moving on.
[`#PathState`](/variables/pathstate/) is `stopped`, also when no walk was going on.

The character stops when the step under way ends. In client mode ([`path set mode client`](/commands/path/set/))
the client keeps walking to the point it was sent to last, up to 18 tiles away.

The goal is kept: [`path walk`](/commands/path/walk/) or [`path step`](/commands/path/step/) go on toward it.

## Example

```euo
repeat
  path step
  if #HITS < 20
  {
    path stop
    gosub flee
    break
  }
  wait 1
until #PathState <> walking
```

## Reforged notes

New in EasyUO Reforged. [`path go`](/commands/path/go/) and [`path walk`](/commands/path/walk/) wait until
their walk is over; the Stop button ends those.
