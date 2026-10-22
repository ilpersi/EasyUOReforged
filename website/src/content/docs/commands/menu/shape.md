---
title: "menu Shape"
description: "Draws a rectangle, circle or other shape in the menu window."
kind: subcommand
category: menu
syntax: "menu Shape {name} {x} {y} {width} {height} {shape} {line style} {line width} {line colour} {fill style} {fill colour}"
related: ["menu Image Create"]
aliases: ["rectangle", "circle", "frame"]
source: wiki
---

`menu Shape` draws a shape, useful for frames, separators and coloured backgrounds behind other controls.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control's name, used later by [`menu Get`](/commands/menu/get/), [`menu Set`](/commands/menu/set/) and [`menu Delete`](/commands/menu/delete/). Case does not matter. |
| `x`, `y`, `width`, `height` | Position and size of the box the shape fills. |
| `shape` | Which shape, see below. |
| `line style`, `line width`, `line colour` | How the outline is drawn. |
| `fill style`, `fill colour` | How the inside is filled. |

Colours are names such as `white` or `$BBGGRR` numbers, see [Colours](/commands/menu/#colours).

| Shape | | Line style | | Fill style | |
|---|---|---|---|---|---|
| `1` | Circle | `1` | None | `1` | Diagonal lines `/` |
| `2` | Ellipse | `2` | Dashes | `2` | None |
| `3` | Rectangle | `3` | Dash dot | `3` | Cross-hatch |
| `4` | Rounded rectangle | `4` | Dash dot dot | `4` | Diagonal cross-hatch |
| `5` | Rounded square | `5` | Dots | `5` | Diagonal lines `\` |
| `6` | Square | `6` | Solid, inside the box | `6` | Horizontal lines |
| | | `7` | Solid | `7` | Solid |
| | | | | `8` | Vertical lines |

Any other number gives a rectangle, a solid line and a solid fill.

## Example

```euo
; a white frame with a dark inside
menu Shape frame 5 5 190 90 3 7 2 white 7 $303030
```
