---
title: "#FindKind"
description: "Where the object FindItem selected is: 0 in a container, 1 on the ground, -1 not found."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["#FindCnt", "#FindX", "#FindBagID"]
aliases: ["ground or container"]
source: wiki
---

`#FindKind` tells where the object is. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/).

| Value | Meaning |
|---|---|
| `-1` | Nothing was found. |
| `0` | In a container. |
| `1` | On the ground. |

To test whether something was found, [`#FindCnt`](/variables/findcnt/) is clearer to read.

## Example

```euo
finditem POF
if #FindKind = 1
  event SysMessage There is gold on the ground.
```
