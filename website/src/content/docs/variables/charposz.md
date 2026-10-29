---
title: "#CharPosZ"
description: "Your character’s height (Z coordinate)."
kind: variable
category: character
access: ro
type: number
needsClient: true
related: ["#CharPosX", "#CharPosY"]
aliases: ["height", "altitude"]
dll: CharPosZ
source: wiki
---

`#CharPosZ` is your character's height in the world, the Z coordinate. Ground level is usually around 0;
upper floors and hills are higher.

## Example

```euo
if #CharPosZ > 20
  display ok You are upstairs.
halt
```
