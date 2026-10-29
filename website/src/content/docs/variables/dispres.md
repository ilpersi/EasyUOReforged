---
title: "#DispRes"
description: "Button the user pressed in the last display box: Ok, Yes, No or Cancel."
kind: variable
category: misc
access: ro
type: string
related: ["Display"]
aliases: ["message box result"]
source: wiki
---

`#DispRes` is the button pressed in the last [`display`](/commands/display/) message box: `Ok`, `Yes`, `No` or
`Cancel`. Comparisons ignore case.

## Example

```euo
display yesno Continue?
if #DispRes = no
  halt
display ok Going on.
halt
```
