---
title: "#Dex"
description: "Returns the dexterity of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #dex system variable determines the dexterity of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My dexterity is #DEX $
halt
```
