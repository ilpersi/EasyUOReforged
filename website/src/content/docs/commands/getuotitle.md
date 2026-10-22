---
title: "GetUOTitle"
description: "Puts the title of the client window in #StrRes."
kind: command
category: client
syntax: "getuotitle"
needsClient: true
sets: ["#StrRes"]
related: ["SetUOTitle", "#CliTitle"]
aliases: ["window title"]
source: wiki
---

`getuotitle` puts the title of the client window in [`#StrRes`](/variables/strres/).
[`#CliTitle`](/variables/clititle/) holds the same text and can be read directly, without a command.

## Example

```euo
getuotitle
display ok The window is called #StrRes
```
