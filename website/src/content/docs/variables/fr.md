---
title: "#FR"
description: "Your character’s fire resistance."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#AR", "#CR", "#PR", "#ER"]
aliases: ["fire resist"]
source: wiki
---

`#FR` is your character's fire resistance.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
event SysMessage My fire resist is #FR
```
