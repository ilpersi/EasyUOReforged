---
title: "#FR"
description: "Returns the Fire Resist of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #FR system variable determines the Fire Resist of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My Fire Resist is #FR $
halt
```
