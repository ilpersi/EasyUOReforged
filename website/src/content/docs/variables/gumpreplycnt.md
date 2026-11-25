---
title: "#GumpReplyCnt"
description: "How many gump answers were recorded: clicks by hand and exevent GumpReply. Goes up by one with each."
kind: variable
category: gumps
access: ro
type: number
origin: reforged
needsClient: false
related: ["#GumpReply", "exevent GumpReply", "#GumpReplyRes"]
aliases: ["gump reply count", "gump click"]
dll: GumpReplyCnt
---

`#GumpReplyCnt` goes up by one every time the client answers a gump the server sent: when you click one of
its buttons, and when [`exevent GumpReply`](/commands/exevent/gumpreply/) answers one. Compare it with the value
you read before to know that an answer went out; [`#GumpReply`](/variables/gumpreply/) then holds that answer.

EasyUO Reforged puts a small hook into the client that records the answers: the editor as soon as it finds the
client, while no script is running, and a script the first time it reads `#GumpReplyCnt` or
[`#GumpReply`](/variables/gumpreply/), or runs `exevent GumpReply`. Clicks made before that are not counted. It
stays until the client closes, and every later run, or another EasyUO Reforged, uses the same one, so the
number keeps counting from where it was. Use the difference, not the number itself.

Without a client, or where the hook can't be put in, it counts the answers `exevent GumpReply` sent in this run.

## Example

Wait until you click a button in a gump, then show what the click sent:

```euo
set %n #GumpReplyCnt
event sysmessage Click a button in the gump.
set %t #SCnt + 60
repeat
  wait 5
until #GumpReplyCnt <> %n || #SCnt > %t
if #GumpReplyCnt <> %n
  display ok You sent: #GumpReply
halt
```
