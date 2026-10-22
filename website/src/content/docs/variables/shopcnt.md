---
title: "#ShopCnt"
description: "Number of entries in the shop gump."
kind: variable
category: shop
access: ro
type: number
needsClient: true
related: ["#ShopCurPos", "GetShopInfo"]
aliases: ["shop entries"]
source: wiki
---

`#ShopCnt` is the number of entries in the shop gump. It is filled by [`getshopinfo`](/commands/getshopinfo/) from the entry shown at the top of the shop gump, and
does not follow the gump: after scrolling, run `getshopinfo` again.
