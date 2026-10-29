---
title: "exevent RenamePet"
description: "Renames one of your pets."
kind: subcommand
category: exevent
syntax: "exevent RenamePet {id} {name}"
needsClient: true
related: ["FindItem"]
aliases: ["rename pet"]
dll: RenamePet
source: wiki
---

`exevent RenamePet` gives one of your pets a new name. The pet has to be known to the client, usually on
screen. Keep the name to 30 characters at most: the rename request has room for no more.

## Example

```euo
set %horse ABCDEFG           ; your horse's ID
finditem %horse G_2
if #FindCnt > 0
  exevent RenamePet #FindID Buttercup
halt
```
