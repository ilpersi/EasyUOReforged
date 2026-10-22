---
title: "event ExMsg"
description: "Shows a message over the object given by the ID."
kind: subcommand
category: event
syntax: "event ExMsg {object ID} {font} {color} {message}"
needsClient: true
source: wiki
---

The *event ExMsg* command shows the string provided in the message parameter over the object given by the object ID. The font and color arguments change the appearance of the message that is displayed.

| Index | Description |
|----|----|
| 0 | Big font with dark edges. |
| 1 | Small font with white drop shadow |
| 2 | Big font with white drop shadow. |
| 3 | Small font with dark edges. |
| 4 | Big fancy font. |
| 5 | Medium font. |
| 6 | Tiny font. |
| 7 | Small font with recessed look. |
| 8 | Runic font replacing the following: Capital A-Z, \[, \\ \], ^, \_. Moon Phases replacing the following: € (128), � (129), ‚ (130), „ (132), … (133), † (134), ‡ (135). |
| 9 | Tiny font. |

ExMsg fonts

## Example

```euo
event ExMsg #charID 3 0 Welcome to my world!
halt
```
