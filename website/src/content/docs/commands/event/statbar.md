---
title: "event StatBar"
description: "Opens the health bar of a character by its ID."
kind: subcommand
category: event
syntax: "event StatBar {id}"
needsClient: true
related: ["#ContHP", "#EnemyID", "FindItem"]
aliases: ["health bar", "status bar", "open health bar"]
dll: StatBar
---

`event StatBar` opens the status bar (health bar) of the character with the given ID, like dragging it off
the character with the mouse. The character has to be known to the client, which usually means on screen.

## Example

```euo
; open your pet's health bar and read its health
set %petid ABCDEFG           ; your pet's ID
event StatBar %petid
wait 10
display ok Pet health: #ContHP percent
halt
```

## Notes

The command needs the client function it calls to be known for your client version. On a client where it is
not, nothing happens.
