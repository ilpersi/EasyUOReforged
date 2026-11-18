---
title: "logfile Level"
description: "Sets the script's minimum level: messages below it go nowhere."
kind: subcommand
category: logging
syntax: "logfile level {debug|info|warning|error|off}"
origin: reforged
sets: ["#LogRes"]
related: ["logfile set", "logfile debug"]
---

`logfile level` sets the lowest level a message needs to be written at all. It starts at `debug`, so
everything is written; `off` writes no message. Each target has a level of its own too
([`logfile set`](/commands/logfile/set/)): a message is written to a target when it passes both.

[`logfile write`](/commands/logfile/write/) and [`log`](/commands/log/) are not messages at a level: they
are always written.

## Example

```euo
set %verbose #false
if %verbose = #false
  logfile level info               ; leave the debug lines out
logfile debug Not written unless verbose
logfile info Written
halt
```
