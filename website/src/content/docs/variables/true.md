---
title: "#True"
description: "The value true: -1."
kind: variable
category: constant
access: ro
type: boolean
related: ["#False", "If"]
aliases: ["yes", "boolean"]
source: wiki
---

`#True` is `-1`, the value comparisons give when they are true, and the only value [`if`](/commands/if/) and
[`while`](/commands/while/) treat as true. Use it for on/off flags. See [`#True` and `#False`](/guides/true-and-false/).

## Example

```euo
set %usemagery #True
if %usemagery
  gosub castheal
```
