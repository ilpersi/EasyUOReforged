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
---

`#CliTitle` is the title of the attached client's window. Setting it changes the title, which helps tell
several clients apart.

`set #CliTitle` and [`SetUOTitle`](/commands/setuotitle/) both rename the window; reading `#CliTitle` gives
the same text as [`GetUOTitle`](/commands/getuotitle/) without a separate command.

## Example

```euo
set #CliTitle #CharName
```

The value is used as it is: an `_` stays an `_` in the title.
