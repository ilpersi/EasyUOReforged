---
title: "#Str"
description: "Returns the strength of the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #str system variable determines the strength of the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
msg My strength is #STR $
halt
```
