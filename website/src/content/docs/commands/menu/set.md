---
title: "menu Set"
description: "Changes the text or state of a control."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Set {name} {value}"
related: ["menu Get", "menu Combo", "menu List"]
source: wiki
---

`menu Set` changes a control:

| Control | What changes |
|---|---|
| [Edit](/commands/menu/edit/) | Its text. |
| [Memo](/commands/menu/memo/) | Its text; `$` starts a new line. |
| [Text](/commands/menu/text/) | Its text; `$` does **not** start a new line here. |
| [Button](/commands/menu/button/) | Its caption. |
| [Check](/commands/menu/check/) | Checked with any number other than 0 (`#true`), unchecked with `0` (`#false`). |

Drop-down lists and list boxes are changed with [`menu Combo`](/commands/menu/combo/) and
[`menu List`](/commands/menu/list/) instead. If several controls share the name, all of them change.

## Example

```euo
menu Set status Looting...
menu Set loot #false
```

## 1.5 and 1.6

- **1.5:** changes every control with that name.
- **1.6:** changes the one control the name belongs to, and also sets [radio buttons](/commands/menu/radio/):
  `1` checks one. `$` stays as written in both.
