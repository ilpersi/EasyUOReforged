---
title: "#Gold"
description: "Returns the amount of gold on the character."
kind: variable
category: status
access: ro
type: number
needsClient: true
source: wiki
---

The #gold system variable determines the amount of gold on the character.

:::note
This variable will not work unless the character status bar is open. You can use [Event Macro 8 2](/commands/event/macro/) to open it from your script.
:::

## Example

```euo
...
if #gold < 1000
gosub gotoBank
...
```
