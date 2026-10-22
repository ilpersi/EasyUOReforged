---
title: "#RHandID"
description: "Returns the ID of the item to be armed in the right hand."
kind: variable
category: combat
access: rw
type: id
needsClient: true
source: wiki
---

The #rHandID system variable holds the ID of the item to be armed in the right hand.

:::note
This variable is used with [event Macro](/commands/event/macro/) in order to place an item in your characters right hand. It must be set to a valid items ID, and the item must be able to be held in the characters right hand in order to work.
:::

## Example

```euo
set #rHandID %weaponID
event macro 24 2
```
