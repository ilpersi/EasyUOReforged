---
title: "event Drag"
description: "Drags an object."
kind: subcommand
category: event
syntax: "event Drag {object id}"
needsClient: true
source: wiki
---

The event Drag command drags an object given by its id.

## Example

```euo
event Drag %ore
wait 20
click 100 100 p
halt
```
