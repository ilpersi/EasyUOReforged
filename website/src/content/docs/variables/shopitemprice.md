---
title: "#ShopItemPrice"
description: "Price of the shop entry shown at the top of the shop gump."
kind: variable
category: shop
access: ro
type: number
needsClient: true
related: ["GetShopInfo", "#ShopItemName"]
aliases: ["price"]
source: wiki
---

`#ShopItemPrice` is the price of one item of the shop entry, in gold. It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.

## Example

```euo
getshopinfo
display ok #ShopItemName costs #ShopItemPrice gold - #ShopItemMax available
halt
```
