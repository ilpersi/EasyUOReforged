---
title: "SetShop"
description: "Sets how many of an item to buy, like `setshopitem`."
kind: dll-method
category: method
syntax: "Call SetShop id amount"
needsClient: true
related: ["SetShopItem", "dll:GetShop"]
aliases: ["UO.SetShop"]
---

Sets how many of an item to buy, like `setshopitem`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `id` | number | Object ID, as a number. |
| `amount` | number | How many to take from a stack. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `done` | boolean | False when the item is not in the buy list. |
