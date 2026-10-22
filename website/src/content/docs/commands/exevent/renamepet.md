---
title: "exevent RenamePet"
description: "Renames a pet."
kind: subcommand
category: exevent
syntax: "Exevent RenamePet {id} {name}"
needsClient: true
related: ["exevent"]
source: wiki
---

The *Exevent RenamePet* command changes the name of the pet given by its id to name.

:::note
This command is only available from EUO 1.5 TV 56
:::

## Example

```euo
finditem %horse G_2
if #FINDCNT > 0
{
    exevent RenamePet #FINDID Name
}
halt
```
