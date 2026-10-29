---
title: "#Weight"
description: "Weight your character carries, in stones."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#MaxWeight", "#Gold"]
aliases: ["stones", "load"]
dll: Weight
source: wiki
---

`#Weight` is the weight your character carries, in stones, as shown in the status window.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Weight > #MaxWeight - 20
  display ok Nearly full: time to unload.
halt
```
