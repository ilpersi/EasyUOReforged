---
title: "#Gold"
description: "Gold your character carries, as the status window shows it."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Weight", "FindItem"]
aliases: ["money"]
dll: Gold
source: wiki
---

`#Gold` is the amount of gold your character carries, as shown in the status window.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Gold < 1000
  display ok Only #Gold gold left.
halt
```
