---
title: "#SPC"
description: "A space; glue it between words with commas."
kind: variable
category: constant
access: ro
type: string
related: ["#SMC", "#DOT", "Set"]
aliases: ["space"]
source: wiki
---

`#SPC` is a single space. Values are one word each, so glue words together with commas and `#SPC`:

## Example

```euo
set %name Sir , #SPC , Robin
display ok Hello , #SPC , %name
```
