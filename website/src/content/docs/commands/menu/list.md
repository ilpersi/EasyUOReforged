---
title: "menu List"
description: "Places a list box in the menu window, and fills or selects its entries."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu List Create {name} {x} {y} {width} {height}\nmenu List Add {name} {text}\nmenu List Select {name} {number}\nmenu List Clear {name}"
related: ["menu Combo", "menu Get"]
aliases: ["listbox"]
source: wiki
---

`menu List` places a list box, which shows several entries at once, and manages its entries.

| Form | What it does |
|---|---|
| `Create {name} {x} {y} {width} {height}` | Places an empty list box. It uses the current [font settings](/commands/menu/#fonts). |
| `Add {name} {text}` | Adds an entry at the end. Without text, adds an empty line. |
| `Select {name} {number}` | Selects entry `number`, counting from 1. `0` selects nothing. |
| `Clear {name}` | Removes every entry. |

[`menu Get`](/commands/menu/get/) returns the number of the selected entry, counting from 1, or `0` when
nothing is selected.

## Example

```euo
menu Clear
menu Font BGColor white
menu List Create lst 10 10 180 120
menu List Add lst This is a simple example
menu List Add lst showing how to use
menu List Add lst a list box.
menu List Select lst 2
menu Window Title List example
menu Window Size 200 140
menu Show
```

## 1.5 and 1.6

- **1.5:** `Add`, `Select` and `Clear` act on every list with that name.
- **1.6:** they act on the one list the name belongs to; a second one created with the same name is out of
  reach. The list goes into the current [default parent](/commands/menu/setdef/).
