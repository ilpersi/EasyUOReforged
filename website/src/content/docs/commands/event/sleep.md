---
title: "event Sleep"
description: "Not implemented in EasyUO Reforged: accepted, but does nothing."
kind: subcommand
category: event
syntax: "event Sleep {milliseconds}"
needsClient: true
related: ["Wait", "Sleep"]
source: wiki
---

:::caution[Not implemented in EasyUO Reforged]
EasyUO Reforged accepts `event Sleep` but does nothing with it: the interpreter has no handler for it, so the
client is not suspended. Use [`wait`](/commands/wait/) or [`sleep`](/commands/sleep/) to pause the script.
:::

In the original documentation, `event Sleep` suspended the client itself for the given number of
milliseconds: it stopped responding, but used no CPU.
