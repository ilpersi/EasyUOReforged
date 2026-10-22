---
title: "#LHandID"
description: "Returns the ID of the item to be armed in the left hand."
kind: variable
category: combat
access: rw
type: id
needsClient: true
source: wiki
---

The #lHandID system variable holds the ID of the item to be armed in the left hand.

:::note
This variable is used with [event Macro](/commands/event/macro/) in order to place an item in your characters left hand. It must be set to a valid items ID, and the item must be able to be held in the characters left hand in order to work.
:::

## Example

```euo
set #lHandID %shieldID
event macro 24 1
```
