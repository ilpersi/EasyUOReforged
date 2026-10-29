---
title: "#ER"
description: "Your character’s energy resistance."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#AR", "#FR", "#CR", "#PR"]
aliases: ["energy resist"]
dll: ER
source: wiki
---

`#ER` is your character's energy resistance.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
display ok My energy resist is #ER
halt
```
