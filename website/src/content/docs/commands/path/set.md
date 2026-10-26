---
title: "path Set"
description: "Changes an option of the pathfinder: accuracy, search limits, turn cost and more."
kind: subcommand
category: path
syntax: "path set {option} {value}"
origin: reforged
sets: ["#PathState"]
related: ["path find"]
---

`path set` changes one option of [`path find`](/commands/path/find/). The options last until the script is
started again, which puts them back to the defaults below.

| Option | Default | Meaning |
|---|---|---|
| `accuracy` | `0` | The route may end this many tiles from the goal, in any direction. |
| `accuracyz` | `5` | When `path find` is given a height, the route may end this much above or below it. |
| `maxnodes` | `1000000` | How many places the search may look at before it gives up (`#PathState` `budget`). |
| `timeout` | `5s` | How long the search may take before it gives up (`timeout`). A time is a number of **ticks** of 50 ms, or a whole number of **seconds** followed by `s`. |
| `margin` | `100` | The search only looks this many tiles beyond the rectangle around start and goal (and around the links it can use). A route that needs a longer detour needs a bigger margin. |
| `turncost` | `30` | What a change of direction costs, in hundredths of a step. The client turns before it steps in a new direction, which takes time. |
| `heuristic` | `100` | How strongly the search heads for the goal, in percent. Above 100 the search is faster, but the route may be a little longer, with more turns. |
| `difs` | `off` | `on` also reads the client's map patch files (`mapdif*`, `stadif*`). The client only uses them when the shard tells it to. |

[`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for an unknown option or a bad value.

## Example

```euo
path set accuracy 1        ; next to the goal is close enough
path set timeout 10s       ; long trips across the facet
path find 2505 552
```
