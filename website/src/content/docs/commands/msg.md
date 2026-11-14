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

### A sub that keeps to the limit

Copy `say_paced` to the end of your script, after its `halt`, and say every line through it. It keeps its own
copy of the client's meter and waits only as long as the line needs, so a few short lines still go out at
once. Write the spaces of the text as `_`.

```euo
gosub say_paced Selling_arrows_for_10_gold_each
gosub say_paced Ask_me_for_a_price
gosub say_paced Open_until_sunset
halt

; say_paced: says %1 (spaces written as _) as soon as the client's spam meter has room for it.
; %say_meter is the script's copy of the meter. It goes down by %say_rate characters a second:
; 12 is safe on the clients measured. It counts time with #SCnt2: don't set #SCnt2 in the script.
sub say_paced
  if %say_rate = N/A
    set %say_rate 12
  if %say_last = N/A
  {
    set %say_meter 0
    set %say_last #SCnt2
  }
  str replace %1 _ #spc
  set %say_text #StrRes
  str len %say_text
  set %say_len #StrRes
  repeat
    ; how far the meter has gone down since the last look (#SCnt2 counts tenths of a second)
    set %say_now #SCnt2
    set %say_down %say_now - %say_last
    set %say_down %say_down * %say_rate
    set %say_down %say_down / 10
    if %say_down > 0
    {
      set %say_meter %say_meter - %say_down
      set %say_last %say_now
    }
    if %say_meter < 0
      set %say_meter 0
    ; wait while the meter is high: 10 leaves room for what you type yourself
    if %say_meter > 10
      wait 2
  until %say_meter <= 10
  set %say_meter %say_meter + %say_len
  msg %say_text , $
return
```

- The client's own limit is 30, and the sub waits until its copy is down to 10. A line typed by you, or by
  another script on the same client, counts too, and the sub can't see it.
- To pace staff commands too, say them through the sub: `gosub say_paced [set_Str_100`.
- [`str replace`](/commands/str/#replace-reforged) is new in EasyUO Reforged. For EasyUO 1.5, drop the
  `str replace` line and its `set`, and set `%say_text` before the `gosub`: `set %say_text Hello , #spc , there`.
