---
title: "#MenuButton"
description: "Name of the last menu button clicked, in capitals; CLOSED when the menu window was closed."
kind: variable
category: result
access: rw
type: string
related: ["menu Button", "menu Hide", "#MenuRes"]
aliases: ["button clicked"]
source: wiki
---

`#MenuButton` is the name of the last [`menu`](/commands/menu/) button clicked, in capital letters. When the menu
window is closed, with its × or with [`menu Hide`](/commands/menu/hide/), it becomes `CLOSED`.

It keeps the last value until the next click, so set it to something else before waiting for a click.
Comparisons ignore case.

## Example

```euo
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
if #MenuButton = closed
  halt
```
