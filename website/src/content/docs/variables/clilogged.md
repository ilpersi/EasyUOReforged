---
title: "#CliLogged"
description: "1 when a character is logged in, 0 at the login screens."
kind: variable
category: client
access: ro
type: boolean
needsClient: true
related: ["#CliVer", "#CharName"]
aliases: ["logged in"]
source: wiki
---

`#CliLogged` is `1` when a character is logged into the game and `0` while the client is at the login screens.

## Example

```euo
if #CliLogged = 0
  gosub login
```
