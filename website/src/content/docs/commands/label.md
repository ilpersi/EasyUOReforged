---
title: "Label"
description: "Marks a line that goto can jump to."
kind: command
category: flow
syntax: "{name}:"
related: ["goto"]
aliases: ["labels", "jump target"]
source: wiki
---

A label is a word followed by a colon, on a line of its own. [`goto`](/commands/goto/) jumps to the line
after it.

```euo
mainloop:
  gosub dostuff
goto mainloop
```

- **Names:** case does not matter, and `goto` can leave out the colon: `goto mainloop`.
- **Nothing else on the line** except a comment (`mainloop: ; main loop`). The label line itself runs
  nothing, so a command written after the label on the same line is ignored.
- **Duplicate names** are allowed, but `goto` takes the nearest one. See [`goto`](/commands/goto/).
