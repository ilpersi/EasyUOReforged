---
title: "Label"
description: "This is a marked spot for a goto command."
kind: command
category: flow
syntax: "label"
related: ["goto"]
source: wiki
---

This is a marked spot for a [goto](/commands/goto/) command. The label is created by using a word (not a command) and suffixing it with a colon.

## Example 1

```euo
mylabel:
```

## Example 2

```euo
mainloop:
   gosub dostuff
goto mainloop
```
