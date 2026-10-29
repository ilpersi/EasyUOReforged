---
title: "Msg"
description: "Types text into the client as if on the keyboard; $ presses Enter."
kind: command
category: client
syntax: "msg {text}"
needsClient: true
related: ["event Macro", "Key", "event SysMessage"]
aliases: ["say", "type text", "speak"]
dll: Msg
source: wiki
---

`msg` types text into the client, character by character, as if you typed it. `$` presses Enter, so a line
ending in `$` is sent as speech, and `msg` also works for answering prompts and filling in text gumps.

Several spaces in a row are typed as one.

:::tip
To say, emote, whisper or yell, [`event Macro`](/commands/event/macro/) is more reliable: it does not
depend on what has the keyboard focus inside the client.
:::

## Example

```euo
msg I wish to lock this down$
target 5s
event Macro 22 0
halt
```
