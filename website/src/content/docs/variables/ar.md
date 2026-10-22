---
title: "#AR"
description: "Returns the Armor Rating of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #AR system variable determines the Armor Rating (Physical Resistance with AoS system) of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My Physical Resist is #AR $
halt
```
