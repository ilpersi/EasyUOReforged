---
title: "event SysMessage"
description: "Shows a system message in the client; only you see it."
kind: subcommand
category: event
syntax: "event SysMessage {message}"
needsClient: true
related: ["event ExMsg", "#SysMsgCol", "Display"]
aliases: ["system message", "show message"]
dll: SysMessage
source: wiki
---

`event SysMessage` shows a message in the client's system message area, at the bottom of the game window
and in the journal. Only you see it; nothing is sent to the server. It is a quiet way for a script to report
what it is doing.

The message uses the colour in [`#SysMsgCol`](/variables/sysmsgcol/).

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Example

```euo
event SysMessage Your character name is #CharName
halt
```
