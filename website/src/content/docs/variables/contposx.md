---
title: "#ContPosX"
description: "Returns the x-coordinate of the currently selected container/gump."
kind: variable
category: container
access: rw
type: number
needsClient: true
source: wiki
---

The #contPosX system variable determines the x-coordinate of the currently selected container/gump.

:::note
EasyUO currently only holds information in the #cont\* on the "top most" gump. This means that the last gump that was opened or moved in any way is what EUO is reporting.
:::

## Example

```euo
set #contPosX 10
set #contPosY 10
contpos
;Will move the current container/Gump to position 10 10
```
