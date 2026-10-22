---
title: "#ShopCurPos"
description: "Position of the shop entry shown at the top, counting from 1."
kind: variable
category: shop
access: ro
type: number
needsClient: true
related: ["#ShopCnt", "GetShopInfo"]
aliases: ["shop position"]
source: wiki
---

`#ShopCurPos` is the position of the entry shown at the top of the shop gump, from `1` to
[`#ShopCnt`](/variables/shopcnt/). It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.
