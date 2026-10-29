---
title: "HideItem"
description: "Hides an item from your screen; nothing changes on the server."
kind: command
category: client
syntax: "hideitem {id}"
needsClient: true
related: ["FindItem", "IgnoreItem"]
aliases: ["hide item"]
dll: HideItem
source: wiki
---

`hideitem` makes an item disappear from your screen, to unclutter it. It only changes the client's copy of
the item: nothing is sent to the server, and the item is back as soon as the server sends it again, for
example when you walk away and come back.

Only items lying on the ground can be hidden; static map art cannot.

## Example

```euo
finditem * G_12
hideitem #FindID
halt
```
