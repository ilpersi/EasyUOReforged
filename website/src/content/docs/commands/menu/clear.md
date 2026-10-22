---
title: "menu Clear"
description: "Removes every control from the menu window and resets the font settings."
kind: subcommand
category: menu
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
