---
title: "menu List"
description: "Creates a listbox at position x/y with specified size on the EasyUO menu window or adds entires to the listbox."
kind: subcommand
category: menu
syntax: "menu List Create {name} {x} {y} {width} {height}\nmenu List Add {name} {string}\nmenu List Select {list name} {item number}"
source: wiki
---

The [menu List](/commands/menu/list/) creates a listbox at position x/y with specified size on the EasyUO menu window, adds entires to the listbox or selects an entry in the list.

## Example

```euo
menu Clear
menu Font BGColor white                           ; sets list's background color to white
menu List Create lstTest 10 10 180 120            ; create listbox
menu List Add lstTest This is a simple example    ; add a string
menu List Add lstTest showing how to use          ; another one
menu List Add lstTest a listbox!                  ; and another...

menu List Add lstTest                             ; adds a blank line
menu List Add lstTest This line will be selected. ; yet another line
menu List Select lstTest 5                        ; select line with index 5

menu Window Title Listbox Example
menu Window Size 200 140
menu Show
halt
```
