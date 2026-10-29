---
title: "exevent Equip"
description: "Asks the server to equip one or more items by ID, in one request."
kind: subcommand
category: exevent
syntax: "exevent Equip {id} [id...]"
needsClient: true
related: ["exevent DropPD", "exevent Drag", "event Drag"]
aliases: ["equip item", "wear item", "arm"]
dll: Equip
---

`exevent Equip` asks the server to equip the listed items, all in one request, without dragging them onto
the paperdoll. Give one or more item IDs; anything that is not a valid ID is skipped.

It sends the client's "equip items" packet (`0xEC`), the one newer clients use for their equip macros, so
it only works on servers that support that packet.

## Example

```euo
; put the weapon and shield back on
set %weaponid ABCDEFG        ; your weapon's ID
set %shieldid HIJKLMN        ; your shield's ID
exevent Equip %weaponid %shieldid
halt
```
