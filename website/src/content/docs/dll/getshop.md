---
title: "GetShop"
description: "Reads the entry shown at the top of the shop gump, like `getshopinfo`."
kind: dll-method
category: method
syntax: "Call GetShop"
needsClient: true
related: ["GetShopInfo", "dll:SetShop"]
aliases: ["UO.GetShop"]
---

Reads the entry shown at the top of the shop gump, like `getshopinfo`.

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `found` | boolean | False, with nothing after it, when no shop gump is open. |
| `position` | number | Position of the entry, counting from 1. |
| `count` | number | Number of entries. |
| `id` | number | Item ID, for `SetShop`. |
| `type` | number | Item type. |
| `available` | number | How many the vendor has. |
| `price` | number | Price of one. |
| `name` | string | Item name. |
