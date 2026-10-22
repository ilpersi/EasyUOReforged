---
title: "#Dex"
description: "Your character’s dexterity."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Str", "#Int", "#MaxStats"]
aliases: ["dexterity"]
source: wiki
---

`#Dex` is your character's dexterity.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
event SysMessage My dexterity is #Dex
```
