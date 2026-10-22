---
title: "Stop"
description: "Stops the script; exactly the same as halt."
kind: command
category: flow
syntax: "stop"
related: ["halt", "pause"]
source: wiki
---

`stop` stops the script. It does exactly the same as [`halt`](/commands/halt/): it cannot be resumed, and
pressing Play starts the script again from the first line.

## Example

```euo
gosub work
stop
```
