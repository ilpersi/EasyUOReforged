---
title: "event Sleep"
description: "Suspends the client for a specified time."
kind: subcommand
category: event
syntax: "event Sleep {ms}"
needsClient: true
source: wiki
---

:::caution[Not implemented in EasyUO Reforged]
EasyUO Reforged accepts `event Sleep` but does nothing with it: the interpreter has no handler for it, so the
client is not suspended. Use [`wait`](/commands/wait/) or [`sleep`](/commands/sleep/) to pause the script
instead.
:::

The event Sleep command suspends the client for a specified number of miliseconds. The client will be completely unresponsive, but will use 0% CPU time.

## Example

```euo
if %waitForVendorRespawn = #true
{
; sleep for one minute
event Sleep 60000
}
...
```
