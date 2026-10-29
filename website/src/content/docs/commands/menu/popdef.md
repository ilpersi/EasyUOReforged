---
title: "menu PopDef"
description: "Brings back defaults for new menu controls saved by menu PushDef."
kind: subcommand
category: menu
syntax: "menu PopDef"
menuLogic: ['1.6']
related: ["menu PushDef", "menu SetDef", "menu GetDef"]
aliases: ["restore defaults"]
credits: ['scriptuo']
---

`menu PopDef` replaces the current [defaults](/commands/menu/getdef/) with a copy saved by
[`menu PushDef`](/commands/menu/pushdef/): the font, the colour and the parent. With no copy saved, it does
nothing. See `menu PushDef` for an example.

## Notes

These are quirks of EasyUO 1.6, kept as they are:

- It takes the **oldest** saved copy, not the newest: after two `menu PushDef`, the first `menu PopDef`
  brings back what the first one saved.
- The alignment becomes left, since `menu PushDef` does not save it.
- [`menu Clear`](/commands/menu/clear/) and starting the script throw away every saved copy.
