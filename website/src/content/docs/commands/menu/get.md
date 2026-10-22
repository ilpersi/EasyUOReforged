---
title: "menu Get"
description: "Reads the value of a control into #MenuRes."
kind: subcommand
category: menu
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
menu Get pet
set %petname #MenuRes
```
