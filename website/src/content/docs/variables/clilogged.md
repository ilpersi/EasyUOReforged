---
title: "#CliLogged"
description: "Returns if a character is logged into the game."
kind: variable
category: client
access: ro
type: boolean
source: wiki
---

Returns if a character is logged into the game.

| Value | Description   |
|-------|---------------|
| 0     | Not logged in |
| 1     | Logged in     |

#cliLogged Values

## Example

```euo
if #cliLogged = 1
   gosub login
```
