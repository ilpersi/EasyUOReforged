---
title: "DeleteVar"
description: "Obsolete: empties a % variable; set %x with no value does the same."
kind: command
category: obsolete
syntax: "deletevar {name}"
obsolete: true
related: ["Set", "namespace clear"]
source: wiki
---

`deletevar` deletes the `%` variable with the given name, written **without** the `%`. Only `%` variables can
be deleted this way.

It is kept for older scripts: `set %name` with no value empties a variable just as well.

## Example

```euo
set %test TEST
deletevar test           ; no % in front
display ok %test         ; N/A: the variable is gone
set %test TEST
set %test                ; the same, the usual way
display ok %test         ; N/A again
halt
```
