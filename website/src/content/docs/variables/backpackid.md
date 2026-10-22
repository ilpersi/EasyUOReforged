---
title: "#BackpackID"
description: "Displays the ID of your player's backPack (Inventory)."
kind: variable
category: character
access: ro
type: id
needsClient: true
source: wiki
---

The #backpackId variable contains the id of the current characters main backpack.

## Example

```euo
findItem * C_ , #backpackId
display ok there are #findCnt items in your backpack.
halt
```
