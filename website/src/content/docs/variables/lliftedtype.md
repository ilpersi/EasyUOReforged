---
title: "#LLiftedType"
description: "Returns the type of the object last dragged/lifted."
kind: variable
category: lastaction
access: ro
type: id
needsClient: true
source: wiki
---

The #lLiftedType system variable determines the type of the object last dragged/lifted.

## Example

```euo
finditem JTL
event Drag #findID
wait 20
msg The type of the item you lifted is #lLiftedType $
halt
```
