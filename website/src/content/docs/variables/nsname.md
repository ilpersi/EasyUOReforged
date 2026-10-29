---
title: "#NSName"
description: "Name of the current namespace; std when the script starts."
kind: variable
category: namespace
access: ro
type: string
related: ["#NSType", "Namespace"]
aliases: ["namespace name"]
source: wiki
---

`#NSName` is the name of the current [namespace](/commands/namespace/), the one `!` variables belong to. A
script starts in `std`. [`#NSType`](/variables/nstype/) says whether it is local or global.

## Example

```euo
if #NSName <> test
{
  namespace push
  namespace local test
}
display ok Now in #NSName
namespace pop
halt
```
