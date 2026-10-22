---
title: "#ContSize"
description: "Returns the size of the currently selected container/gump."
kind: variable
category: container
access: ro
type: string
needsClient: true
source: wiki
---

The [#contSize](/variables/contsize/) system variable determines the size of the currently selected container/gump. The format is as follows: "{Width}\_{Height}".

:::note
EasyUO currently only holds information in the #cont\* on the "top most" gump. This means that the last gump that was opened or moved in any way is what EUO is reporting.
:::

## Example

```euo
if #contSize = 101_101 ;if the front container/gump's size is 101 101
{
.....
}
```
