---
title: "SetShopItem"
description: "Sets how many of an item to buy in the shop’s buy list."
kind: command
category: client
syntax: "setshopitem {id} {amount}"
needsClient: true
related: ["GetShopInfo", "#ShopItemID", "#ShopItemMax"]
aliases: ["buy amount"]
dll: SetShop
source: wiki
---

`setshopitem` sets how many of the item with that ID to buy, in the shop's buy list (the bill). Take the ID
from [`#ShopItemID`](/variables/shopitemid/) after [`getshopinfo`](/commands/getshopinfo/).

- The item has to be **in the buy list already**: double-click it once in the shop gump so it is added with
  an amount of 1, then change the amount with `setshopitem`.
- The buy list on screen does not show the new amount, but it is set, and it is what you buy.

## Example

```euo
getshopinfo
setshopitem #ShopItemID #ShopItemMax
halt
```
