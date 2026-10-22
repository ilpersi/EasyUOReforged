---
title: "namespace copy"
description: "Copies variables matching a pattern between the current namespace and another."
kind: subcommand
category: namespace
syntax: "namespace copy {pattern} {from|to} {local|global} {name}"
related: ["namespace local", "namespace global"]
source: wiki
---

`namespace copy` copies variables between the current namespace and another one.

## Parameters

| Parameter | Meaning |
|---|---|
| `pattern` | Which variables, by name, without the `!`. `*` matches any number of characters and can appear once; `?` matches one character and can appear several times. `*` alone copies everything. |
| `from` / `to` | `from` copies from the other namespace into the current one; `to` copies from the current one into the other. |
| `local` / `global` | Whether the other namespace is local or global. |
| `name` | The other namespace. It does not need to exist yet. |

A pattern without `*` matches the names that **end** with it: `ret` matches `!ret` and `!secret`. Write
`ret*` for names starting with `ret`.

## Example

Return a value from a sub that works in its own namespace:

```euo
gosub test
display ok !result
halt

sub test
  namespace push
  namespace local test
  set !result done
  namespace pop
  namespace copy result from local test
return
```
