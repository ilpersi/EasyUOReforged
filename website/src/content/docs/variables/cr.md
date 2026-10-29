---
title: "#CR"
description: "Your character’s cold resistance."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#AR", "#FR", "#PR", "#ER"]
aliases: ["cold resist"]
dll: CR
source: wiki
---

`#CR` is your character's cold resistance.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
display ok My cold resist is #CR
halt
```
