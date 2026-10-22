---
title: "#FindY"
description: "Y position of the object FindItem selected: world position on the ground, screen position in a container."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["#FindX", "#FindZ", "#FindKind", "#FindMod"]
aliases: ["item position"]
source: wiki
---

`#FindY` is the Y position of the object. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/).

- For an object **on the ground** ([`#FindKind`](/variables/findkind/) `1`), it is a world position, like
  [`#CharPosY`](/variables/charposy/).
- For an object **in a container** (`#FindKind` `0`), it is its position on screen inside the container, where
  you would click it. [`#FindMod`](/variables/findmod/) is added to it.

## Example

```euo
finditem %target G_10
if #FindCnt > 0
  event PathFind #FindX #FindY #FindZ
```
