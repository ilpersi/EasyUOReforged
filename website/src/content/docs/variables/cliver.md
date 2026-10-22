---
title: "#CliVer"
description: "Returns the version of the client."
kind: variable
category: client
access: ro
type: string
source: wiki
---

Contains the version of the Ultima Online client that EasyUO is attached to.

## Example

```euo
if #cliVer <> 4.0.0e
{
  event SysMessage This script was developed for client 4.0.0e. Be aware of any changes.
  pause
}
```
