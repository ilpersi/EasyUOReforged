---
title: "exevent GumpReply"
description: "Answers a gump the server sent, the way a click on one of its buttons does."
kind: subcommand
category: exevent
syntax: "exevent GumpReply {gump} {button} [switches] [id:text ...]"
origin: reforged
needsClient: true
sets: ['#GumpReply', '#GumpReplyRes', '#GumpReplyCnt']
related: ["ScanGumps", "#GumpTypeID", "#GumpReply", "#GumpReplyCnt", "#GumpReplyRes", "dll:GumpReply", "dll:GetGumpReply"]
aliases: ["gump reply", "answer gump", "click gump button", "gump button", "server gump"]
dll: GumpReply
---

`exevent GumpReply` answers a gump the server sent (a menu, a confirmation, a quest window), as if you
had clicked one of its buttons. It sends the server the same answer the client sends for a click, with
the checkboxes and text fields you give it, and closes the window in the client.
[`#GumpReplyRes`](/variables/gumpreplyres/) says whether it went out, and
[`#GumpReply`](/variables/gumpreply/) keeps the answer, so the same line can send it again later.

## Parameters

| Parameter | Meaning |
|---|---|
| `gump` | Which gump: its [`#GumpTypeID`](/variables/gumptypeid/), such as `JHEIIPI`, for the gump of that type in front; or a number, a position in the last [`ScanGumps`](/commands/scangumps/) list, such as `#GumpIndex`. |
| `button` | The number of the button. `0` means "close", which every gump accepts. |
| `switches` | Optional. The IDs of the checkboxes and radio buttons that are on, joined with `/`: `3/7`. `-` for none. |
| `id:text` | Optional, one per text field: its ID, a colon, and the text. Write a space as `_`, a real `_` as `\_` and a `\` as `\\`. A text is cut at 239 characters, as the client cuts it. |

The button numbers and IDs come from the shard: each gump has its own. The easiest way to find them: click the
button once by hand and read [`#GumpReply`](/variables/gumpreply/), which records the click (see below). It shows
the button, and the checkboxes and text fields the window sent with it.

## Results

| [`#GumpReplyRes`](/variables/gumpreplyres/) | Meaning |
|---|---|
| `sent` | The answer went out. [`#GumpReply`](/variables/gumpreply/) holds it. |
| `nogump` | No such gump is open: nothing was sent. |
| `error` | The words are wrong, or this client build can't answer gumps: nothing was sent. |

`sent` means the server got the answer. Whether it did what you wanted, the game tells: the journal, an
item, a new gump.

## Examples

Confirm with OKAY (button 1) the confirmation gump of type `JHEIIPI`, if it is open:

```euo
exevent GumpReply JHEIIPI 1
if #GumpReplyRes = nogump
  event sysmessage The confirmation is not open.
halt
```

Tick checkboxes 3 and 7, type a name into text field 5, and press button 2:

```euo
set %menu YISCGQI          ; the gump's #GumpTypeID on your shard
exevent GumpReply %menu 2 3/7 5:Iron_Golem
halt
```

Close every server gump that is open:

```euo
scangumps
for %i 1 #GumpCnt
{
  set #GumpIndex %i
  if #GumpName = generic_gump
    exevent GumpReply %i 0
}
halt
```

Send the last answer again, when the same gump opens next time:

```euo
set %answer #GumpReply
repeat
  scangumps T_ , %answer
  wait 5
until #GumpCnt > 0
exevent GumpReply %answer
halt
```

The last example works because the first word of `#GumpReply` is the type ID, so `scangumps T_ , %answer`
looks for that type, and `exevent GumpReply %answer` sends the whole answer.

## Notes

- **The serial is taken from the gump open now.** Each time the server opens a gump it gives it a new
  serial, and it ignores an answer with any other serial, without a word. That is why the command finds the
  gump in the client every time and never reuses an old serial: an answer kept in `#GumpReply` works on the
  next copy of the same gump.
- **An answer to a gump that is not open does nothing**, on the server as in the command (`nogump`).
- **The client's window closes**, as it does after a click. Only for the client's own gumps with type IDs
  from `$2410` to `$2462` (`AUN` to `GSN`) it stays open, because the client keeps some of those open after
  some buttons.
- **A button the gump doesn't have** is up to the shard. ModernUO ignores it on most gumps and keeps waiting
  for an answer, which does no harm; its newer gumps pass it to the gump, and a confirmation then takes it as
  "not OK", like Cancel. The client's window is closed either way.
- **Clicks by hand are recorded too.** A small hook in the client records every gump answer it sends:
  `#GumpReplyCnt` goes up and `#GumpReply` holds the answer. The editor puts it in as soon as it finds the
  client, while no script is running; otherwise the first `exevent GumpReply`, or the first time a script reads
  `#GumpReply` or [`#GumpReplyCnt`](/variables/gumpreplycnt/), does. A click made before that is not recorded.
  The hook stays until the client closes and changes nothing the client does. On a client build where it can't
  be put in safely, only this command's answers are recorded.
- It needs the client's event hook, as every `exevent` does.

## Reforged notes

`exevent GumpReply`, `#GumpReply` and `#GumpReplyRes` are new in EasyUO Reforged. Old EasyUO skips the
line. No other `exevent` changes.

It works where [`#GumpTypeID`](/variables/gumptypeid/) can be read: client 7.0.29.97 and newer except 7.0.30
to 7.0.46, and the relocatable `client_beta.exe`. Elsewhere it gives `error` and sends nothing.
