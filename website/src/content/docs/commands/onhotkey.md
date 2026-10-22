---
title: "OnHotKey"
description: "Performs a line of code if a specific key is pressed."
kind: command
category: client
syntax: "onHotKey {key-specifier} {[alt] | [ctrl] | [shift]}"
needsClient: true
source: wiki
---

The onHotKey command performs the following line of code (brackets do NOT work) when a certain key is pressed. The key-specifier can either be A-Z, 0-9, F1-F12 and ESC, BACK, TAB, ENTER, PAUSE, CAPSLOCK, SPACE, PGDN, PGUP, END, HOME, LEFT, RIGHT, UP, DOWN, PRNSCR, INSERT, DELETE, NUMLOCK or SCROLLLOCK.

:::note
The code is only executed when the parser passes it, if you want a key-press to perform a certain action you have to make a loop. See the example.
:::

:::note
This function is **NOT** client or focus specific. Be careful what you type when running a script with onhotkey, chatting on one client, or in a different application may cause your character to do things in game you do not intend.
:::

## Example

```euo
set #lpc 1000
repeat
  onhotkey a
    gosub hotkey a
  onhotkey b
    gosub hotkey b
  onhotkey c
    gosub hotkey c
  onhotkey d
    gosub hotkey d
  onhotkey e
    gosub hotkey e
  sleep 1
until #false

sub hotkey
{
  event sysmessage %1
  Loop:
  sleep 1
  onhotkey %1
    goto Loop
  return
}
```

## Example

```euo
set #lpc 1000
desactive:
  onhotkey t alt
    goto active
  onhotkey y alt
    halt
goto desactive

active:
    onhotkey r alt
      goto desactive
    goto active
```
