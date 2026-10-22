---
title: "#Str"
description: "Your character’s strength."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Dex", "#Int", "#MaxStats"]
aliases: ["strength"]
source: wiki
---

`#Str` is your character's strength.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
event SysMessage My strength is #Str
```
