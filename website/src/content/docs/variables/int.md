---
title: "#Int"
description: "Your character’s intelligence."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Str", "#Dex", "#MaxStats"]
aliases: ["intelligence"]
dll: Int
source: wiki
---

`#Int` is your character's intelligence.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
display ok My intelligence is #Int
halt
```
