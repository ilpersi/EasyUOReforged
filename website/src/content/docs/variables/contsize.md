---
title: "#ContSize"
description: "Width and height of the gump on top, as width_height."
kind: variable
category: container
access: ro
type: string
needsClient: true
related: ["#ContSizeX", "#ContSizeY", "#ContName"]
aliases: ["gump size"]
source: wiki
---

`#ContSize` is the size of the gump on top, in pixels, written `width_height`, for example `230_204`. The
size often tells gumps apart that share a name. [`#ContSizeX`](/variables/contsizex/) and
[`#ContSizeY`](/variables/contsizey/) give the two numbers separately. Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

## Example

```euo
if #ContSize = 230_204
  display ok The gump on top is 230 by 204 pixels.
halt
```
