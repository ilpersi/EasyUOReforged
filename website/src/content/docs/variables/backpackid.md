---
title: "#BackpackID"
description: "ID of your character’s backpack."
kind: variable
category: character
access: ro
type: id
needsClient: true
related: ["#CharID", "FindItem", "exevent DropC"]
aliases: ["backpack", "inventory"]
dll: BackpackID
source: wiki
---

`#BackpackID` is the ID of your character's main backpack. Use it to search the backpack with
[`finditem`](/commands/finditem/) or to drop things into it with [`exevent DropC`](/commands/exevent/dropc/).

It reads `N/A` while the client does not know the backpack yet, for example right after logging in.

## Example

```euo
finditem * C_ , #BackpackID
display ok There are #FindCnt items in your backpack.
```
