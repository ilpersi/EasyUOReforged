---
title: "#Opts"
description: "Determines which EasyUO configuration options are active."
kind: variable
category: result
access: ro
type: string
source: wiki
---

The #opts system variable displays which EasyUO configuration options are active.

| Value | Option            |
|-------|-------------------|
| SOT   | Stay On Top       |
| SYS   | event SysMessage  |
| DMC   | Don't Move Cursor |
| EXEC  | Allow Execute     |
| SEND  | Allow Send        |

Table of #opt values

## Example

```euo
if DMC notin #opts
{
    display ok This script requires "Don't move cursor" enabled!$
+Enable this option in the EasyUO Tools menu and restart the script.$
    halt
}
```
