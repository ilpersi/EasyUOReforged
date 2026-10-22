---
title: "#Stamina"
description: "Returns the current stamina level or the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #stamina system variable determines the current stamina level of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My stamina is #stamina
halt
```
