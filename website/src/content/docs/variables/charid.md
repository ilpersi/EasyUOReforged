---
title: "#CharID"
description: "ID of your character."
kind: variable
category: character
access: ro
type: id
needsClient: true
related: ["#BackpackID", "#CharName", "FindItem"]
aliases: ["character id", "my id"]
dll: CharID
source: wiki
---

`#CharID` is the ID of your character. It is unique, so a script can tell which character it is running on.

It also works as a container for [`finditem`](/commands/finditem/): `finditem * C_ , #CharID` finds what your
character is wearing.

## Example

```euo
finditem * C_ , #CharID
for #FindIndex 1 #FindCnt
  event ExMsg #FindID 3 0 worn
halt
```
