---
title: "#PR"
description: "Returns the Poison Resist of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #PR system variable determines the Poison Resist of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My Poison Resist is #PR $
halt
```
