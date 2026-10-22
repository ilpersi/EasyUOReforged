---
title: "menu Window Transparent"
description: "Sets the transparency of the window."
kind: subcommand
category: menu
syntax: "menu Window Transparent {opacity}"
source: wiki
---

`menu Window Transparent` sets the transparency of the menu window: `0` is almost invisible and
`100` is fully opaque.

:::note
This command didn't work under Linux + Wine (1.1.2).
:::

## Example

```euo
menu window $000000 ;Window will be dark black
menu show 200 200 ;Shows window

for %i 0 100 ;Loops from 0 to 100
{
    menu window transparent %i ;Sets the transparency of the window
    wait 5 ;Waits 1/4 second
}

halt ;Terminates the script
```
