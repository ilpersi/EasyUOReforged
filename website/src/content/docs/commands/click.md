---
title: "Click"
description: "Clicks at a specific position in the UO client."
kind: command
category: client
syntax: "click {X-coordinate} {Y-coordinate} [Modifiers]"
needsClient: true
source: wiki
---

The click command mimics a click of the mouse in a specific position on the screen.

| Option    | Description                                  |
|-----------|----------------------------------------------|
| d         | Double Click                                 |
| dmc       | Don't Move Cursor (New from 1.42 (build 7c)) |
| f         | Fast Click                                   |
| g         | Drag                                         |
| mc        | Move Cursor (New from 1.42 (build 7c))       |
| n         | Nothing (Just moves the cursor)              |
| p         | Drop                                         |
| r         | Right Click                                  |
| x {count} | Multiple Fast Clicks                         |

:::note
- Multiple specifier's are allowed.
- Using the "Don't Move Cursor" option can make the double clicking fail randomly.
- With the introduction of [event Drag](/commands/event/drag/), using click to drag and drop objects is obsolete.
:::

Be sure to also read [Cheffe explains the CLICK command](http://www.easyuo.com/forum/viewtopic.php?t=10951)

## Example

```euo
; close open crafting gump
click 150 150 r
```
