---
title: "Msg"
description: "Sends a string to the client as keystrokes."
kind: command
category: client
syntax: "msg"
needsClient: true
source: wiki
---

The msg command sends a series of key-strokes to the client. The '$' sign denotes carriage return.

:::note
Instead of using [msg](/commands/msg/) to speak, whisper, yell, etc. it is more stable and easier to work with [event_Macro](/commands/event/macro/).
:::

## Example

```euo
; Locks Last Target Down
msg I wish to lock this down$
target 5s
event Macro 22
halt
```
