---
title: "menu Reforge Mode"
description: "Chooses which MENU system the script runs under: EasyUO 1.5's or 1.6's."
kind: subcommand
category: menu
syntax: "menu Reforge Mode {1.5|1.6}"
origin: reforged
menuLogic: ['1.5', '1.6']
related: ["menu Reforge IncludeCall", "menu Form", "menu Text"]
aliases: ["menu mode", "menu version", "1.6 menu"]
---

`menu Reforge Mode` chooses the [MENU system](/commands/menu/versions/) a script runs under: `1.5`, the
one whose source was published, or `1.6`, the later one with windows, panels and properties. Without it,
Reforged picks one by looking for the sub-commands only 1.6 has.

## Parameters

| Parameter | Meaning |
|---|---|
| `1.5` or `1.6` | The MENU system for this run. |

## Description

- **Read before the script runs.** Reforged reads it from the script's text when the script starts, so it
  can go anywhere; the top is the clearest place. When the line runs, it does nothing.
- **Written out.** The value must be `1.5` or `1.6` as such: a variable (`menu Reforge Mode %m`) cannot be read
  before the run and is ignored, as is any other value. The first line with a valid value counts.
- **Main script only.** In a file pulled in with [`call`](/commands/call/) it has no effect; called files
  always run under the main script's choice.
- **Portable.** EasyUO 1.5 and 1.6 ignore the line, so a script that has it still runs there.

The editor's status bar shows `MENU 1.6 (forced)` or `MENU 1.5 (forced)` while a script chosen this way
runs.

## Example

```euo
menu Reforge Mode 1.6
gosub BuildMenu      ; uses menu Form and menu SetProp, maybe through variables
```

## Reforged notes

`menu Reforge Mode` is new in EasyUO Reforged, which runs both MENU systems.
