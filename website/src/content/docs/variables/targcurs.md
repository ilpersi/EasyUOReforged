---
title: "#TargCurs"
description: "Returns if cursor is a target cursor."
kind: variable
category: extended
access: rw
type: boolean
source: wiki
---

The #targCurs system variable determines if cursor is a target cursor. It can also be written to, to get a target cursor.

| Value | Description                |
|-------|----------------------------|
| 0     | Cursor is a normal cursor. |
| 1     | Cursor is a target cursor. |

#targCurs Values

## Example

```euo
event SysMessage Target something!

set #targCurs 1
targLoop:
if #targCurs = 1
  goto targLoop

event SysMessage The ID of the target is #lTargetID
halt
```
