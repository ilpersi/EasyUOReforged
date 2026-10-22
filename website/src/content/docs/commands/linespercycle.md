---
title: "LinesPerCycle"
description: "Sets the execution speed."
kind: command
category: misc
syntax: "linesPerCycle {linespercycle}"
source: wiki
---

The [LinesPerCycle](/commands/linespercycle/) command sets the number of lines that the EasyUO parser runs through for every cycle. The default value is 10 and is reset when you stop the script.

Cheffe's description of lines per cycle, and cycles per second:

"EUO has 20 cycles per second and in each cycle it executes 10 lines (default). Some commands have built in waits so that the script speed slows down considerably.

You can't say that one command is faster than the other. EUO gives away most of the available processing time so that the UO client can have it.

EUO doesn't know the difference between a processing intensive task such as "finditem \*" at WBB or a simple "set %x 3". While 10 lines per cycle is already too fast if you have 10 finditems in a row you could execute hundreds of set instructions in the same time without stressing the CPU."

Read here: http://www.easyuo.com/forum/viewtopic.php?p=21269

## Example

```euo
linespercycle 10
```
