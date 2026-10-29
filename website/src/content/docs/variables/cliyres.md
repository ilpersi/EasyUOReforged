---
title: "#CliYRes"
description: "Height of the game area in pixels; set it to resize the game area."
kind: variable
category: client
access: rw
type: number
needsClient: true
related: ["#CliXRes", "#CliLeft", "#CliTop"]
aliases: ["game window size", "resolution"]
dll: CliYRes
source: wiki
---

`#CliYRes` is the height of the game area (where the world is drawn), in pixels. Setting it resizes the game
area. The value lives in the client: setting it changes it for every script attached to that client.

## Example

```euo
set #CliXRes 800
set #CliYRes 600
halt
```
