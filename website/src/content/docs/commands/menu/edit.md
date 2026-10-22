---
title: "menu Edit"
description: "Places a one-line text field in the menu window."
kind: subcommand
category: menu
syntax: "menu Edit {name} {x} {y} {width} {text}"
related: ["menu Get", "menu GetNum", "menu Memo", "menu Set"]
aliases: ["text field", "input"]
source: wiki
---

`menu Edit` places a one-line text field the user can type in. Its height follows the font size. For more
than one line, use [`menu Memo`](/commands/menu/memo/).

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control's name, used later by [`menu Get`](/commands/menu/get/), [`menu Set`](/commands/menu/set/) and [`menu Delete`](/commands/menu/delete/). Case does not matter. |
| `x`, `y` | Position of the top-left corner. |
| `width` | Width in pixels. |
| `text` | The starting text. |

It uses the current [font settings](/commands/menu/#fonts). Read what the user typed with [`menu Get`](/commands/menu/get/) or, for a number,
[`menu GetNum`](/commands/menu/getnum/).

## Example

```euo
menu Edit pet 10 10 150 Fluffy
; later
menu Get pet
set %petname #MenuRes
```
