---
title: "menu Font Transparent"
description: "Draws the labels created after it without a background."
kind: subcommand
category: menu
menuLogic: ['1.5']
credits: ['scriptuo']
syntax: "menu Font Transparent {#true|#false}"
related: ["menu Text", "menu Font BGColor"]
source: wiki
---

`menu Font Transparent` with `#true` makes the [text labels](/commands/menu/text/) created after it draw
without a background, so what is behind them (a shape, an image, the window colour) shows through. `#false`
goes back to normal.

## Example

```euo
menu Shape bg 0 0 200 40 3 1 1 0 7 navy
menu Font Transparent #true
menu Font Color white
menu Text title 10 10 On a blue band
```

## 1.5 and 1.6

EasyUO 1.6 dropped `menu Font Transparent`: under the 1.6 logic the line does nothing and labels always have
a background, in the colour set by [`menu Font BgColor`](/commands/menu/font/bgcolor/).
