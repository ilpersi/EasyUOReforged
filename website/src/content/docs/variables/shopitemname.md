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
changed: true
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

## Reforged notes

- Its text is UTF-8, as all of a script's text in Reforged: a letter with an accent matches the same letter written
  in the script, and [`str`](/commands/str/) counts it as one letter, as in EasyUO 1.5. See
  [Letters with accents](/language/variables/#letters-with-accents).
