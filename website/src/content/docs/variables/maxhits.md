---
title: "#MaxHits"
description: "Returns the maximum number of hitpoints of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #maxHits system variable determines the maximum number of hitpoints of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg I can have total of #MAXHITS hitpoints $
halt
```
