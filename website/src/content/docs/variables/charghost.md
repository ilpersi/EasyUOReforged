---
title: "#CharGhost"
description: "Returns if your character is dead."
kind: variable
category: character
access: ro
type: string
needsClient: true
source: wiki
---

The #charGhost system variable determines if your character is dead. If the character is dead it holds "YES", if it is alive it holds "NO".

| Value | Description         |
|-------|---------------------|
| YES   | Character is dead.  |
| NO    | Character is alive. |

Table of #charGhost values

## Example

```euo
...
if #charGhost = YES
{
    gosub logOut
    halt
}
...
```
