---
title: "#StrRes"
description: "Result of the last str command; also set by getuotitle."
kind: variable
category: result
access: rw
type: string
related: ["Str", "GetUOTitle"]
aliases: ["string result"]
source: wiki
---

`#StrRes` is the result of the last [`str`](/commands/str/) command, or `N/A` when that command was missing
parameters. [`getuotitle`](/commands/getuotitle/) also puts the client window's title here.

## Example

```euo
str len #CharName
event SysMessage My name has #StrRes letters
```
