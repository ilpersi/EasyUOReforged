---
title: "SetShopItem"
description: "Sets the number of items to purchase given by ID."
kind: command
category: client
syntax: "setShopItem {ID} {amount}"
needsClient: true
related: ["getshopinfo"]
source: wiki
---

The setShopItem command sets the amount to purchase given by an items ID. The ID is usually gotten from the system variable #shopItemID.

:::note
- Despite the fact that using setShopItem will not update the graphics in the buy gump, the ammount to sell is set in the client's memory.
- Before calling setShopItem you have to add at least **one** item to the buy list. This means you first have to double click the item so it gets added to the buy list with amount equal to 1, then you may call setShopItem to change that amount.
:::

## Example

```euo
; This will set the amount to buy of the top item to the total number that
; is available to be bought.
getShopInfo
setShopItem #shopItemID #shopItemMax
```
