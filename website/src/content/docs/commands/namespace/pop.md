---
title: "namespace pop"
description: "Goes back to the namespace last remembered with namespace push."
kind: subcommand
category: namespace
syntax: "namespace pop"
related: ["namespace push"]
source: wiki
---

`namespace pop` makes the namespace last remembered by [`namespace push`](/commands/namespace/push/) current
again, and removes it from the stack. When nothing is remembered, it does nothing.

## Example

```euo
namespace push
namespace local temp
set !x 1
namespace pop            ; back to where we were
```
