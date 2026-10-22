---
title: "menu Activate"
description: "Gives a control the keyboard focus."
kind: subcommand
category: menu
syntax: "menu Activate {name}"
related: ["menu Edit"]
aliases: ["focus"]
source: wiki
---

`menu Activate` gives the keyboard focus to a control: an edit field, memo, button, check box, drop-down list
or list box. What the user types then goes into it.

## Example

```euo
menu Edit search 10 10 150
menu Show
menu Activate search
```
