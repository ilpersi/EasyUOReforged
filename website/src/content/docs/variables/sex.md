---
title: "#Sex"
description: "Your character’s sex: 0 male, 1 female."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#CharStatus", "#CharType"]
aliases: ["gender"]
dll: Sex
source: wiki
---

`#Sex` is `0` when your character is male and `1` when female.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Sex = 1
  event SysMessage Lady #CharName
```
