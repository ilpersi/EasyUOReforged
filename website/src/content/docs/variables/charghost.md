---
title: "#CharGhost"
description: "yes when your character is dead (a ghost), no otherwise."
kind: variable
category: character
access: ro
type: string
needsClient: true
related: ["#CharType", "#Hits"]
aliases: ["dead", "ghost"]
source: wiki
---

`#CharGhost` is `yes` when your character is a ghost and `no` when it is alive. It looks at the character's
body, so it recognises the human and elf ghost bodies. Comparisons ignore case: `#CharGhost = YES` works.

## Example

```euo
if #CharGhost = yes
{
  gosub logout
  halt
}
```
