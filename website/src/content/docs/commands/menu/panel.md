---
title: "menu Panel"
description: "Creates a borderless area that holds other controls; the controls created after it go into it."
kind: subcommand
category: menu
syntax: "menu Panel {name} {x} {y} {width} {height}"
menuLogic: ['1.6']
related: ["menu Form", "menu Radio", "menu SetProp", "menu SetDef"]
aliases: ["group", "container", "frame"]
credits: ['scriptuo']
---

`menu Panel` creates a rectangle without a border, in the [default colour](/commands/menu/getdef/), that holds
other controls. Positions inside it are counted from its own top-left corner.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The panel's name. |
| `x`, `y` | Position inside the current [default parent](/commands/menu/setdef/). |
| `width`, `height` | Size in pixels. |

## Description

- **Controls created after it go into it**, as with [`menu Form`](/commands/menu/form/), until another form or
  panel, [`menu SetDef parent`](/commands/menu/setdef/), [`menu PopDef`](/commands/menu/popdef/) or
  [`menu Clear`](/commands/menu/clear/).
- What happens to the panel happens to its contents: hiding it with
  [`menu SetProp`](/commands/menu/setprop/) `{name} visible #false` hides them, moving it moves them, and
  [`menu Delete`](/commands/menu/delete/) removes them.
- [Radio buttons](/commands/menu/radio/) in one panel form their own group.
- Give it a colour with `menu SetProp {name} color {number}`.

## Example

```euo
menu Reforge Mode 1.6
menu Window Size 220 130
menu Panel size 10 10 200 30
menu Radio small 5 5 60 20 #true Small
menu Radio large 80 5 60 20 #false Large
menu SetDef parent form0
menu Panel speed 10 50 200 30
menu Radio slow 5 5 60 20 #true Slow
menu Radio fast 80 5 60 20 #false Fast
menu SetDef parent form0
menu Button ok 70 95 80 25 OK
menu Show
```

The two pairs of radio buttons are independent, because each pair has its own panel.
