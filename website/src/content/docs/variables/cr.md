---
title: "#CR"
description: "Returns the Cold Resist of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #CR system variable determines the Cold Resist of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My Cold Resist is #CR $
halt
```
