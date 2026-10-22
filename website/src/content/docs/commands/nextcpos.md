---
title: "NextCPos"
description: "Denotes where the next opened container/gump will open."
kind: command
category: client
syntax: "nextCPos {X-coordinate} {Y-coordinate}"
needsClient: true
source: wiki
---

The nextCPos sets the position where the next container/gump will open at.

:::note
The "Offset interface windows rather than perfectly stacking them" option, in Interface options (Mouse Icon) must be turned on for this to work.
:::

## Example

```euo
;Closes the paperdoll and reopens it at 0,0
event Macro 9 1
wait 20
nextCPos 0 0
event Macro 8 1
halt
```
