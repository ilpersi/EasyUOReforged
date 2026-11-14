---
title: "menu Memo"
description: "Creates a multi-line, scrollable text field in the EasyUO menu window, which can wrap its long lines."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Memo {name} {x} {y} {width} {height} {text}"
origin: reforged
related: ["menu Edit", "menu Get", "menu SetProp", "#MenuRes"]
aliases: ["multiline edit", "text area", "word wrap", "scroll bar"]
---

`menu Memo` creates a multi-line text field: the counterpart of [`menu Edit`](/commands/menu/edit/) for
more than one line. It scrolls when the text does not fit. A line longer than the field runs past its right
edge, and the horizontal scroll bar reaches it, unless the memo wraps its lines (see
[Wrapping and scroll bars](#wrapping-and-scroll-bars)).

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Name you use later in [`menu Get`](/commands/menu/get/) and [`menu Delete`](/commands/menu/delete/). |
| `x`, `y` | Position in the menu window. |
| `width`, `height` | Size in pixels. |
| `text` | Starting text. `$` starts a new line, as in [`menu Text`](/commands/menu/text/). |

The field uses the current [`menu Font`](/commands/menu/font/name/) settings.

[`menu Get`](/commands/menu/get/) returns the contents with the line breaks turned back into `$`, so the
text can go straight into a `display` or another memo.

## Example

```euo
menu Clear
menu Window Size 300 200
menu Memo notes 10 10 280 150 First line$Second line
menu Button ok 10 165 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton <> ok
  wait 1
menu Get notes
display ok #MenuRes
halt
```

## Wrapping and scroll bars

With the [1.6 `menu`](/commands/menu/versions/), a memo has two properties of its own, set with
[`menu SetProp`](/commands/menu/setprop/) and read with [`menu GetProp`](/commands/menu/getprop/):

| Property | Values | When created |
|---|---|---|
| `wordwrap` | `#true`: long lines break at the right edge, and the memo has no horizontal bar. `#false`: they run past it. | `#false` |
| `scrollbars` | 0 none, 1 horizontal, 2 vertical, 3 both. A bar stays, greyed out, when there is nothing to scroll. Other numbers are ignored. | 3 |

Wrapping only changes how the text is shown: [`menu Get`](/commands/menu/get/) and `menu GetProp ... text`
still return the lines as they were written, with a `$` only where the text had a line break.

```euo
menu Window Size 300 200
menu Memo notes 10 10 280 150 A line wider than the memo breaks at its right edge instead of running on$A second line
menu SetProp notes wordwrap #true
menu SetProp notes scrollbars 2
menu Button ok 10 165 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton <> ok
  wait 1
menu Get notes
display ok #MenuRes
halt
```

`menu SetProp` is one of the sub-commands only the 1.6 `menu` has, so a script that uses it runs under that
one by itself.

## Reforged notes

`menu Memo` is new in EasyUO Reforged, and so are its `wordwrap` and `scrollbars` properties.

## 1.5 and 1.6

`menu Memo` is a Reforged addition and works in both, with the same syntax. In the 1.6 logic it follows the
1.6 rules: it goes into the current [default parent](/commands/menu/setdef/), its name must be free, and
[`menu GetProp`](/commands/menu/getprop/) / [`menu SetProp`](/commands/menu/setprop/) work on it like on
an edit field, `text` turning `$` into line breaks and back. Only the 1.6 logic has `wordwrap` and
`scrollbars`: under the 1.5 logic a memo never wraps and always has both scroll bars.
