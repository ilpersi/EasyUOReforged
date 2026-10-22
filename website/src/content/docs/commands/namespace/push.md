---
title: "namespace push"
description: "Remembers the current namespace, to come back to it with namespace pop."
kind: subcommand
category: namespace
syntax: "namespace push"
related: ["namespace pop", "namespace local"]
source: wiki
---

`namespace push` remembers the current namespace (its name and whether it is local or global) on a stack.
[`namespace pop`](/commands/namespace/pop/) goes back to it. Pushes can be nested: each `pop` returns to the
namespace of the matching `push`.

Use the pair around code that switches namespaces, so it leaves the caller where it was.

## Example

```euo
sub work
  namespace push
  namespace local work
  ; ... uses its own !variables
  namespace pop
return
```
