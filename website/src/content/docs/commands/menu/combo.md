---
title: "menu Combo"
description: "Places a drop-down list in the menu window, and fills or selects its entries."
kind: subcommand
category: menu
syntax: "menu Combo Create {name} {x} {y} {width}\nmenu Combo Add {name} {text}\nmenu Combo Select {name} {number}\nmenu Combo Clear {name}"
related: ["menu List", "menu Get"]
aliases: ["combobox", "drop-down", "dropdown"]
source: wiki
---

`menu Combo` places a drop-down list, where the user picks one entry, and manages its entries.

| Form | What it does |
|---|---|
| `Create {name} {x} {y} {width}` | Places an empty drop-down list. It uses the current [font settings](/commands/menu/#fonts). |
| `Add {name} {text}` | Adds an entry at the end. |
| `Select {name} {number}` | Selects entry `number`, counting from 1. `0` selects nothing. |
| `Clear {name}` | Removes every entry. |

[`menu Get`](/commands/menu/get/) returns the number of the selected entry, counting from 1, or `0` when
nothing is selected.

## Example

```euo
menu Combo Create town 10 10 120
menu Combo Add town Britain
menu Combo Add town Trinsic
menu Combo Add town Vesper
menu Combo Select town 1
; later
menu Get town
display ok You chose town number #MenuRes
```
