---
title: "#CliTop"
description: "Y position of the game area inside the client window; set it to move the game area."
kind: variable
category: client
access: rw
type: number
needsClient: true
related: ["#CliLeft", "#CliXRes", "#CliYRes"]
aliases: ["game window position"]
dll: CliTop
source: wiki
---

`#CliTop` is the Y position of the game area (where the world is drawn) inside the client window,
in pixels. Setting it moves the game area. The value lives in the client: setting it changes it for every script attached to that client.

## Example

```euo
set #CliLeft 0
set #CliTop 0                ; game area in the top-left corner
```
