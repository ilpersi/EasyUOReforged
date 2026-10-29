---
title: "OnHotKey"
description: "Runs a line or block only if a key is held down at that moment."
kind: command
category: client
syntax: "onhotkey {key} [ctrl] [alt] [shift]"
related: ["Key", "If"]
aliases: ["hotkey", "key pressed"]
source: wiki
---

`onhotkey` runs the next line or block only if the key is held down at the moment the line runs;
otherwise it skips it, like an [`if`](/commands/if/).

## Parameters

| Parameter | Meaning |
|---|---|
| `key` | The key: `A`–`Z`, `0`–`9`, `F1`–`F12`, `ESC`, `BACK`, `TAB`, `ENTER`, `PAUSE`, `CAPSLOCK`, `SPACE`, `PGUP`, `PGDN`,
`END`, `HOME`, `LEFT`, `RIGHT`, `UP`, `DOWN`, `PRNSCR`, `INSERT`, `DELETE`, `NUMLOCK` and `SCROLLLOCK`. |
| `ctrl`, `alt`, `shift` | Optional. These must be held as well. The match is exact: a modifier you did not list must **not** be held. |

As with `if`, a block's `{` has to be the very next line, and a number at the end of the line controls that
many lines instead.

## Details

- The key is only checked when the line runs. To react to a key at any time, check it in a loop.
- The check is for the whole computer, not for one client or window: typing in another program, or in
  another client, triggers it too.

## Example

```euo
set #LPC 1000
loop:
  onhotkey F1
    display ok You pressed F1.
  onhotkey F2 ctrl
  {
    display ok Script stopped with Ctrl+F2.
    halt
  }
  sleep 10
goto loop
```
