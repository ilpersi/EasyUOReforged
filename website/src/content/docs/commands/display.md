---
title: "Display"
description: "Shows a message box and waits for the user; the answer goes to #DispRes."
kind: command
category: misc
syntax: "display [ok|okcancel|yesno|yesnocancel] {message}"
sets: ["#DispRes"]
related: ["#DispRes", "event SysMessage"]
aliases: ["message box", "popup", "alert"]
source: wiki
---

`display` shows a Windows message box with the message and waits until the user closes it. The button that
was pressed goes into [`#DispRes`](/variables/dispres/).

## Parameters

| Parameter | Meaning |
|---|---|
| buttons | Optional. `ok` (the default), `okcancel`, `yesno` or `yesnocancel`. |
| `message` | The text. `$` starts a new line. |

`#DispRes` is `Ok`, `Yes`, `No` or `Cancel`. Comparisons ignore case, so `#DispRes = yes` works.

The script waits while the box is open, but the rest of EasyUO Reforged keeps working.

## Example

```euo
display yesno You have run out of ingots.$Stop the script?
if #DispRes = yes
  halt
display ok Going on without ingots.
halt
```
