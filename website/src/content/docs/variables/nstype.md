---
title: "#NSType"
description: "Whether the current namespace is local or global."
kind: variable
category: namespace
access: ro
type: string
related: ["#NSName", "namespace local", "namespace global"]
aliases: ["namespace type"]
source: wiki
---

`#NSType` is `local` when the current [namespace](/commands/namespace/) is private to this script, and `global`
when it is shared with every running script.

## Example

```euo
if #NSType = global
  event SysMessage Writing to a shared namespace.
```
