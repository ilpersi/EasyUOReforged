---
title: "menu Memo"
description: "Creates a multi-line, scrollable text field in the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Memo {name} {x} {y} {width} {height} {text}"
origin: reforged
related: ["menu Edit", "menu Get", "#MenuRes"]
aliases: ["multiline edit", "text area"]
---

`menu Memo` creates a multi-line text field: the counterpart of [`menu Edit`](/commands/menu/edit/) for
more than one line. It scrolls when the text does not fit and does not wrap long lines.

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
```

## Reforged notes

`menu Memo` is new in EasyUO Reforged.
