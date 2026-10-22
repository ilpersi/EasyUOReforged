---
title: "Key"
description: "Sends a key-stroke to the client."
kind: command
category: client
syntax: "key {key-specifier} [[ alt ] | [ ctrl ] | [ shift ]]"
needsClient: true
source: wiki
---

The key command sends a keystroke of your choice to the client.

The key-specifier can either be A-Z, 0-9, F1-F12 and ESC, BACK, TAB, ENTER, PAUSE, CAPSLOCK, SPACE, PGDN, PGUP, END, HOME, LEFT, RIGHT, UP, DOWN, PRNSCR, INSERT, DELETE, NUMLOCK or SCROLLLOCK.

:::note
If you are running more than one client, the modifier key (alt, control, shift) can sometimes not work as its supposed to.
:::

## Example

```euo
; This will hold the ALT key down and press the F4 key.
key F4 ALT
```
