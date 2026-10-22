---
title: "#ShopItemType"
description: "Type of the shop entry’s item."
kind: variable
category: shop
access: ro
type: id
needsClient: true
related: ["GetShopInfo", "#ShopItemID", "#FindType"]
aliases: ["shop item type"]
source: wiki
---

`#ShopItemType` is the item type of the shop entry, in the same form as [`#FindType`](/variables/findtype/), so
you can recognise an item whatever its name. It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.

## Example

```euo
getshopinfo
if #ShopItemType = %bandagetype
  setshopitem #ShopItemID 50
```
