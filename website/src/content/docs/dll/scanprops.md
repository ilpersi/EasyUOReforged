---
title: "ScanProps"
description: "Reads the property tooltip of every item of the filtered list (what `ScanItems` and `FilterItems` left), like `scanprops` after `finditem`, from the client's tooltip cache in one go."
kind: dll-method
category: method
syntax: "Call ScanProps"
needsClient: true
related: ["ScanProps", "#FindProp", "dll:GetItem", "dll:Property"]
aliases: ["UO.ScanProps"]
---

Reads the property tooltip of every item of the filtered list (what `ScanItems` and `FilterItems` left), like `scanprops` after `finditem`, from the client's tooltip cache in one go. Items the cache has no tooltip for yet are asked for and waited for. `GetItem` then returns each stored item's text as its 12th value.

## Returns

Nothing.

:::note
The text has `#Property`'s format, one byte per letter like `Property`'s strings. See [`scanprops`](/commands/scanprops/) for what it reads and how it can differ from `Property`.
:::
