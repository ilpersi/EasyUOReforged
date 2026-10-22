---
title: "#LLiftedID"
description: "Returns the id of the object last dragged/lifted."
kind: variable
category: lastaction
access: ro
type: id
needsClient: true
source: wiki
---

The #lLiftedID system variable determines the id of the object last dragged/lifted.

## Example

```euo
finditem JTL
event Drag #findID
wait 20
msg The ID of the item you lifted is #lLiftedID $
halt
```
