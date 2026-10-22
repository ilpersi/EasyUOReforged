---
title: "#CharName"
description: "Returns the name of the character."
kind: variable
category: status
access: ro
type: string
needsClient: true
source: wiki
---

The #charName system variable contains the name of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My name is #CHARNAME $
halt
```
