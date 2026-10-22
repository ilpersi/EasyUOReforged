---
title: "#SysMsgCol"
description: "Colour that event SysMessage writes in."
kind: variable
category: extended
access: rw
type: number
related: ["event SysMessage"]
aliases: ["message colour"]
source: wiki
---

`#SysMsgCol` is the colour (hue) [`event SysMessage`](/commands/event/sysmessage/) writes in. It is a script
setting, not a client value: change it before `event SysMessage` to colour the message. `0` is the default.

## Example

```euo
set #SysMsgCol 33
event SysMessage Low on reagents!
set #SysMsgCol 0
```
