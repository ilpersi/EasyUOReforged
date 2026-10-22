---
title: "Else"
description: "Runs a line or a block when the if before it was false."
kind: command
category: flow
syntax: "else\nelse {lines}"
related: ["if"]
source: wiki
---

`else` runs the line or block after it only when the [`if`](/commands/if/) before it was false. When the
`if` was true, the script skips it.

## Parameters

| Parameter | Meaning |
|---|---|
| `lines` | Optional. Without a block, how many of the following lines belong to the `else`. Default: 1. |

## Where it goes

Put `else` right after the line or block of its `if`. Blank lines in between are fine; any other line in
between breaks the pairing.

A block is a `{` line, the lines to run, and a matching `}` line. The `{` has to be **the very next line**:
a blank line or a comment in between means only that line belongs to the command, and the block after it
runs every time. Braces go on lines of their own.

## Example

```euo
set %a #false
if %a
  display ok a is true
else
  display ok a is false     ; this one is shown
halt
```

See [`if`](/commands/if/) for blocks, the line-count form and nesting.
