---
title: "Exit"
description: "Ends a called script, or starts the main script over from the top."
kind: command
category: flow
syntax: "exit"
related: ["call", "halt", "return"]
source: wiki
---

`exit` ends the script it is in:

- **In a script started with [`call`](/commands/call/)**, the calling script goes on with the line after
  its `call`.
- **In the main script**, the script **starts over from the first line**. It does not stop: use
  [`halt`](/commands/halt/) for that. Variables keep their values.

Reaching the last line of a script does the same as `exit`. That is why a main script that should run once
ends with `halt`, and why a script without one runs again and again.

## Example

```euo
set %round %round + 1
display ok Round %round
if %round < 3
  exit                       ; back to the top of the script
display ok Done after %round rounds.
halt
```

## Returning a value from a called script

`exit` cannot return a value the way [`return`](/commands/return/) does from a sub. Set a variable
instead; called scripts share their variables with the script that called them.

```euo
; main script
set %a 0
call a.euo
display ok a = %a
halt
```

```euo title="a.euo"
set %a set_by_a.euo
exit
```
