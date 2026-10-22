---
title: "exevent Popup"
description: "Opens the context menu of an item/npc."
kind: subcommand
category: exevent
syntax: "Exevent Popup {id} [x] [y]"
needsClient: true
related: ["exevent"]
source: wiki
---

The *Exevent Popup* command opens the context menu of an item/npc given by its id. Default values for x and y are 0/0.

:::note
This command is only available from EUO 1.5 TV 56. The syntax for this command has been changed in EasyUO 1.5.1 build 252. It used to be Exevent: Popup {id} \[entry\] **SCRIPT USING OLD SYNTAX MUST BE UPDATED**.
:::

## Example

```euo
finditem %vendor G_10
if #FINDCNT > 0
    exevent Popup #findid 10 10
halt
```
