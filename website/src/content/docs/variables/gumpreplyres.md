---
title: "#GumpReplyRes"
description: "What the last exevent GumpReply did: sent, nogump or error."
kind: variable
category: gumps
access: ro
type: string
origin: reforged
needsClient: false
related: ["exevent GumpReply", "#GumpReply"]
aliases: ["gump reply result"]
---

`#GumpReplyRes` says what the last [`exevent GumpReply`](/commands/exevent/gumpreply/) did:

| Value | Meaning |
|---|---|
| `sent` | The answer went out; [`#GumpReply`](/variables/gumpreply/) holds it. |
| `nogump` | No such gump was open, so nothing was sent. |
| `error` | The words were wrong, or this client build can't answer gumps. Nothing was sent. |

Reads `N/A` until `exevent GumpReply` ran in this run.

## Example

```euo
exevent GumpReply JHEIIPI 1
if #GumpReplyRes <> sent
  display ok The confirmation was not open ( #GumpReplyRes ).
halt
```
