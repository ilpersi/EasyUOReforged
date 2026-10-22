---
title: "#MaxMana"
description: "Returns the maximum mana pool for the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #maxMana system variable determines the maximum mana pool for the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
...
if #mana < #maxMana
  gosub meditate
...
```
