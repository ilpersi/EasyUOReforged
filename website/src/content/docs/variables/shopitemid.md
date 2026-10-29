---
title: "#ShopItemID"
description: "ID of the shop entry’s item, for setshopitem."
kind: variable
category: shop
access: ro
type: id
needsClient: true
related: ["GetShopInfo", "SetShopItem", "#ShopItemType"]
aliases: ["shop item id"]
source: wiki
---

`#ShopItemID` is the ID of the item in the shop entry: what [`setshopitem`](/commands/setshopitem/) needs. It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.

## Example

```euo
getshopinfo
setshopitem #ShopItemID 10
halt
```
