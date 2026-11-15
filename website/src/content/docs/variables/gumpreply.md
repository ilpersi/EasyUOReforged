---
title: "#GumpReply"
description: "The last answer exevent GumpReply sent, type ID first, ready to send again."
kind: variable
category: gumps
access: ro
type: string
origin: reforged
needsClient: false
related: ["exevent GumpReply", "#GumpReplyRes", "#GumpReplyCnt", "#GumpTypeID"]
aliases: ["gump reply", "last gump answer"]
---

`#GumpReply` holds the last answer sent to a gump the server opened, in the words that follow
`exevent GumpReply`: the gump's type ID first, then the button, the switches (`-` for none) and the text fields.
For example `JHEIIPI 1 -`, or `YISCGQI 2 3/7 5:Iron_Golem`. It is the answer
[`exevent GumpReply`](/commands/exevent/gumpreply/) sent, or the one you sent with a click: once a script has
read [`#GumpReplyCnt`](/variables/gumpreplycnt/), EasyUO Reforged records the clicks too. A click sends the
window's checkboxes and text fields with the button, so they are in it too.

So `exevent GumpReply #GumpReply` sends the same answer again, to the gump of that type that is open now,
with its new serial. Copy it into a variable to keep it: `set %answer #GumpReply`.

So to find out what a gump expects, click the button once by hand and read `#GumpReply`: the script can then
send the same answer itself.

Reads `N/A` until an answer was recorded. With the click hook in the client, the last answer it recorded can
come from before the run.

## Example

```euo
exevent GumpReply JHEIIPI 0
if #GumpReplyRes = sent
  event sysmessage Sent: #GumpReply
halt
```
