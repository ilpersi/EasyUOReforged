---
title: "#NSName"
description: "Returns the name of the currently active namespace."
kind: variable
category: namespace
access: ro
type: string
source: wiki
---

Holds the name of the currently active [local](/commands/namespace/local/) or [global](/commands/namespace/global/) namespace.

:::note
Global namespaces are only available in EasyUO 1.5.
:::

## Example

```euo
if #nsName <> test && #nsType = local
{
  namespace push
  namespace local test
}
```
