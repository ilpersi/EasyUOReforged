---
title: "Key"
description: "Presses a key in the client, optionally with Ctrl, Alt or Shift."
kind: command
category: client
syntax: "key {key} [ctrl] [alt] [shift]"
needsClient: true
related: ["Msg", "OnHotKey", "event Macro"]
aliases: ["keystroke", "press key", "keyboard"]
dll: Key
source: wiki
---

`key` presses and releases a key in the client.

## Parameters

| Parameter | Meaning |
|---|---|
| `key` | The key: `A`–`Z`, `0`–`9`, `F1`–`F12`, `ESC`, `BACK`, `TAB`, `ENTER`, `PAUSE`, `CAPSLOCK`, `SPACE`, `PGUP`, `PGDN`,
`END`, `HOME`, `LEFT`, `RIGHT`, `UP`, `DOWN`, `PRNSCR`, `INSERT`, `DELETE`, `NUMLOCK` and `SCROLLLOCK`. |
| `ctrl`, `alt`, `shift` | Optional. Hold these down while the key is pressed. |

## Details

- **Without `ctrl`, `alt` or `shift`** the key goes straight to the client window, which does not need to
  be in front.
- **With any of them**, the client is brought to the front and the keys are pressed on the real keyboard,
  so the client has to keep the focus while it happens. With several clients open, modifier keys can end up
  in the wrong one.
- The script waits 250 ms after each `key`.

## Example

```euo
key F4 alt        ; Alt+F4
key ENTER
```
