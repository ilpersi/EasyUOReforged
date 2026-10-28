---
title: "menu Clear"
description: "Removes every control from the menu window and resets the font settings."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Clear"
related: ["menu Delete", "menu Font Name"]
source: wiki
---

`menu Clear` removes every control from the menu window and puts the [font settings](/commands/menu/#fonts)
back to their defaults. The window itself, its size, title and colour stay as they are.

The menu window stays when a script stops, so start your menu code with `menu Clear`.

## Example

```euo
menu Clear
menu Window Size 200 100
```

## 1.5 and 1.6

- **1.5:** removes every control. The window keeps its size, title, colour and position, and
  [`#MenuButton`](/variables/menubutton/) keeps its value.
- **1.6:** removes every control and also every other window ([`menu Form`](/commands/menu/form/)) and
  panel. The main window keeps its size, title, colour, position and whether it is shown. The defaults go
  back to their starting values, the default parent becomes the main window again, the
  [`menu PushDef`](/commands/menu/pushdef/) copies are dropped, and `#MenuButton` is emptied. After
  [`menu Delete form0`](/commands/menu/delete/) the main window stays gone.
