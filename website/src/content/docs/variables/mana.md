---
title: "#Mana"
description: "Returns the current mana pool for the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #mana system variable determines the current mana pool for the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg I have #MANA mana in my pool $
halt
```
