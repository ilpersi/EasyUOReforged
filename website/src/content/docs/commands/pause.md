---
title: "Pause"
description: "Temporarily stops the execution of the current script."
kind: command
category: flow
syntax: "pause"
source: wiki
---

The *pause* command will stop execution of the current script, but it can be resumed by pressing the "Play" button.

## Example 1

```euo
onhotkey F12
{
    display ok The script is currently paused. press the EasyUO play button to restart.
    pause
}
```

## Example 2

```euo
sub somesub
   ; If we are debugging, pause script execution here to check current variables...
   if %debug
      pause
   set %something %1
return %something
```
