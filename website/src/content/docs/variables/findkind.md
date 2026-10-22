---
title: "#FindKind"
description: "Returns the kind of the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findKind system variable contains the kind of the object returned by [findItem](/commands/finditem/).

| Value | Description               |
|-------|---------------------------|
| -1    | No objects found.         |
| 0     | Object is in a container. |
| 1     | Object is on the ground.  |

:::note
1.  Findkind is not the preferred method to check whether an item was found or not because it is harder for humans to debug. Please use [#FINDCNT](/variables/findcnt/) instead, whenever possible.
:::

## Example

```euo
if #findkind = -1
{
event sysmessage item not found.
}
```
