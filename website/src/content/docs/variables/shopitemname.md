---
title: "#ShopItemName"
description: "Name of the shop entry shown at the top of the shop gump."
kind: variable
category: shop
access: ro
type: string
needsClient: true
related: ["GetShopInfo", "#ShopItemPrice", "#ShopItemID"]
aliases: ["shop item name"]
source: wiki
---

`#ShopItemName` is the name of the item in the shop entry. Spaces read as `_`. It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.

## Example

```euo
getshopinfo
display ok #ShopItemName costs #ShopItemPrice gold - #ShopItemMax available
halt
```
