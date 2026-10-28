---
title: "menu Window Transparent"
description: "Makes the whole menu window see-through, from 0 to 100 percent opaque."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Window Transparent {opacity}"
related: ["menu Window Color"]
source: wiki
---

`menu Window Transparent` makes the whole menu window see-through. `opacity` goes from `0`, almost invisible,
to `100`, fully opaque. Even at `0` the window stays faintly visible, so it can still be found.

:::note
This did not work under Linux and Wine (1.1.2) in the original EasyUO.
:::

## Example

```euo
menu Clear
menu Text t 10 10 Fading in...
menu Window Transparent 0
menu Show
for %i 0 100
{
  menu Window Transparent %i
  wait 1
}
halt
```
