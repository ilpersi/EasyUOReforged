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
changed: true
source: wiki
---

`getuotitle` puts the title of the client window in [`#StrRes`](/variables/strres/).
[`#CliTitle`](/variables/clititle/) holds the same text and can be read directly, without a command.

## Example

```euo
getuotitle
display ok The window is called #StrRes
halt
```

## Reforged notes

- The title is read through Windows' Unicode call, in UTF-8, so every letter of it reads as itself. EasyUO 1.5 used
  the Windows code page, where a letter outside it read as `?`. See
  [Letters with accents](/language/variables/#letters-with-accents).
