---
title: "Pause"
description: "Pauses the script until Play is pressed."
kind: command
category: flow
syntax: "pause"
related: ["halt", "stop"]
source: wiki
---

`pause` pauses the script. Pressing Play goes on with the line after it, with every variable as it was.
Use [`halt`](/commands/halt/) to stop the script instead.

While a script is paused, the variable inspector shows the current values, which makes `pause` a simple
breakpoint. EasyUO Reforged also has real breakpoints: see [Editing and debugging](/guide/debugging/).

## Example

```euo
sub somesub
  if %debug = #true
    pause                ; check the variables here
  set %something %1
return %something
```
