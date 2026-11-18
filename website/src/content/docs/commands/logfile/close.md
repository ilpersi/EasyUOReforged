---
title: "logfile Close"
description: "Closes one file target, or every file target of the script."
kind: subcommand
category: logging
syntax: "logfile close [name]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile open"]
---

`logfile close` closes the file target with that name, or every file target when no name is given. Its
lines are already in the file: nothing is held back. The `output` target can't be closed; silence it with
`logfile set output level off`.

You rarely need it: the files are also closed when the script stops (halt, Stop or an error), when you press
Play again and when the tab is closed. Close a file when the script is going to read it with
[`call`](/commands/call/), or when another program should have it to itself.

## Example

```euo
logfile open cfg settings.txt new
logfile write cfg set % , runs 1
logfile close cfg
call settings.txt
halt
```
