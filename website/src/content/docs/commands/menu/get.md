---
title: "menu Get"
description: "Reads the value of a control into #MenuRes."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Get {name}"
sets: ["#MenuRes"]
related: ["menu GetNum", "menu Set", "#MenuRes", "#MenuButton"]
source: wiki
---

`menu Get` puts the value of a control in [`#MenuRes`](/variables/menures/):

| Control | `#MenuRes` |
|---|---|
| [Edit](/commands/menu/edit/) | The text. |
| [Memo](/commands/menu/memo/) | The text, with each line break turned into `$`. |
| [Check](/commands/menu/check/) | `-1` (`#true`) when checked, `0` (`#false`) when not. |
| [Combo](/commands/menu/combo/), [List](/commands/menu/list/) | The number of the selected entry, counting from 1; `0` when none. |
| [Text](/commands/menu/text/), [Button](/commands/menu/button/), anything else | `N/A`. |

A name that does not exist also gives `N/A`. If several controls share a name, the first one is read.

Clicks need no `menu Get`: they go to [`#MenuButton`](/variables/menubutton/) by themselves.

## Example

```euo
menu Clear
menu Window Size 180 110
menu Edit pet 10 10 150 Fluffy
menu Check feed 10 40 150 20 #true Feed it
menu Button ok 10 75 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu Get pet
set %petname #MenuRes
menu Get feed
display ok Pet %petname feed #MenuRes
halt
```

## 1.5 and 1.6

- **1.6:** also reads [radio buttons](/commands/menu/radio/): `-1` when checked, `0` when not. It reads the
  control the name belongs to; in 1.5, the first control with that name. Labels, buttons and images give
  `N/A` in both.
