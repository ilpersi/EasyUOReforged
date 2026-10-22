---
title: "#ContType"
description: "Type of the item a container gump on top belongs to."
kind: variable
category: container
access: ro
type: id
needsClient: true
related: ["#ContID", "#FindType"]
aliases: ["container type"]
source: wiki
---

`#ContType` is the item type of the container the gump on top belongs to, in the same form as
[`#FindType`](/variables/findtype/). It reads `YC` for a gump that belongs to no item. Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

## Example

```euo
if #ContType <> %trashbarrel
  gosub opentrash
```
