---
title: "GetShopInfo"
description: "Reads the entry shown at the top of the shop gump into the #Shop… variables."
kind: command
category: client
syntax: "getshopinfo"
needsClient: true
sets: ["#ShopItemID", "#ShopItemType", "#ShopItemName", "#ShopItemPrice", "#ShopItemMax", "#ShopCurPos", "#ShopCnt"]
related: ["SetShopItem"]
aliases: ["vendor", "buy", "shop"]
dll: GetShop
source: wiki
---

`getshopinfo` reads the entry currently shown at the top of an open shop gump (a vendor's list of items for sale)
and fills the `#Shop…` variables with it: [`#ShopItemID`](/variables/shopitemid/),
[`#ShopItemType`](/variables/shopitemtype/), [`#ShopItemName`](/variables/shopitemname/),
[`#ShopItemPrice`](/variables/shopitemprice/), [`#ShopItemMax`](/variables/shopitemmax/),
[`#ShopCurPos`](/variables/shopcurpos/) and [`#ShopCnt`](/variables/shopcnt/).

The shop gump has to be open, but it does not have to be on top. The variables do not follow the gump:
after scrolling to another entry, run `getshopinfo` again.

## Example

```euo
; buy as many of the top item as the vendor has
getshopinfo
setshopitem #ShopItemID #ShopItemMax
```
