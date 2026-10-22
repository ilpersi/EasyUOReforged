---
title: "event SysMessage"
description: "Outputs text to the client as a system message."
kind: subcommand
category: event
syntax: "event SysMessage {message}"
needsClient: true
source: wiki
---

The event SysMessage command outputs a message as a system message inside the client.

:::note
This command does NOT work unless you have enabled the "Enable Event Sysmessage" configuration option.
:::

## Example

```euo
;prints "Your character name is <your character's name>" to the bottom of the screen
event sysMessage Your character name is #charname
```
