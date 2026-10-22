---
title: "#MaxStam"
description: "Returns the maximum stamina level or the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #maxStam system variable determines the maximum stamina level of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
...
if #stamina < #maxStam
  gosub drinkRefresh
...
```
