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

## The spam limit

The client itself limits how fast it sends speech, whatever the shard does. It sends a line at once only while
its spam meter is below the *SpamLimit* option (30 by default). Every line it sends adds its length in
characters to the meter, and the meter goes down again with time. Once the meter is over the limit, the client
keeps the line back, sends it later, and shows **[Spam detected, speech queued for N seconds]**.

The meter goes down more slowly than *SpamLimit* suggests: the client works it out in its game loop and drops
fractions each time. Measured from the clients' code, it goes down by 20 to 26 characters a second on
`client.exe` 7.0.117.33, and by about 13 on `client_beta.exe` 7.0.117.31.

A script that says many lines one after another, or types many staff commands such as `[set` on a shard where
it has them, runs into it. The lines still arrive, but late, so a [`findjournal`](/commands/findjournal/)
waiting for the answer can time out, or take the answer to an earlier line for the answer to this one.

Give the client about a second for every 12 characters before the next line. Lines sent with
[`event Macro`](/commands/event/macro/) `1` to `4` count the same way.

```euo
msg Selling arrows for 10 gold each$
wait 3s                               ; 31 characters: about 3 seconds before the next line
msg Ask me for a price$
halt
```
