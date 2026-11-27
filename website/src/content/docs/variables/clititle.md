---
title: "#CliTitle"
description: "Title of the client window; set it to rename the window."
kind: variable
category: client
access: rw
type: string
needsClient: true
related: ["SetUOTitle", "GetUOTitle", "#CliNr"]
aliases: ["client title", "window title"]
dll: CliTitle
changed: true
---

`#CliTitle` is the title of the attached client's window. Setting it changes the title, which helps tell
several clients apart.

`set #CliTitle` and [`SetUOTitle`](/commands/setuotitle/) both rename the window; reading `#CliTitle` gives
the same text as [`GetUOTitle`](/commands/getuotitle/) without a separate command.

## Example

```euo
set #CliTitle #CharName
halt
```

The value is used as it is: an `_` stays an `_` in the title.

## Reforged notes

- The title is read and set through Windows' Unicode calls, in UTF-8, so every letter of it reads and writes as
  itself. EasyUO 1.5 used the Windows code page, where a letter outside it read as `?`. See
  [Letters with accents](/language/variables/#letters-with-accents).
