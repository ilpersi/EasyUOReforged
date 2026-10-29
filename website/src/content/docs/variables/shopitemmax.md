---
title: "#ShopItemMax"
description: "How many of the shop entry’s item the vendor has."
kind: variable
category: shop
access: ro
type: number
needsClient: true
related: ["GetShopInfo", "SetShopItem"]
aliases: ["available", "stock"]
source: wiki
---

`#ShopItemMax` is how many of the item the vendor has, the most you can buy. It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.

## Example

```euo
getshopinfo
setshopitem #ShopItemID #ShopItemMax       ; buy them all
halt
```
