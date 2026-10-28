---
title: "menu PushDef"
description: "Saves a copy of the current defaults for new menu controls, for menu PopDef to bring back."
kind: subcommand
category: menu
syntax: "menu PushDef"
menuLogic: ['1.6']
related: ["menu PopDef", "menu SetDef", "menu GetDef"]
aliases: ["save defaults"]
credits: ['scriptuo']
---

`menu PushDef` saves a copy of the [defaults](/commands/menu/getdef/) new controls are created with: the
font, the colour and the parent. [`menu PopDef`](/commands/menu/popdef/) brings a saved copy back.

## Example

```euo
menu Reforge Mode 1.6
menu PushDef
menu Font Style b
menu Panel header 0 0 300 30
menu Text title 5 5 Settings
menu PopDef
menu Text body 5 40 Plain text, in the main window again
```

## Notes

These are quirks of EasyUO 1.6, kept as they are:

- The alignment is not saved: after `menu PopDef` it is left.
- Copies are added at the end of a list and `menu PopDef` takes the first one, so nested pairs come back in
  the wrong order. Use one `menu PushDef` / `menu PopDef` pair at a time.
