---
title: "#CharName"
description: "Your character’s name."
kind: variable
category: status
access: ro
type: string
needsClient: true
related: ["#CharID", "#Shard"]
aliases: ["name", "character name"]
dll: CharName
source: wiki
---

`#CharName` is your character's name. Unlike most string variables, its spaces stay spaces.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
display ok My name is #CharName
halt
```
