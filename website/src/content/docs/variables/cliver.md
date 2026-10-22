---
title: "#CliVer"
description: "Version of the attached client, such as 7.0.117.1."
kind: variable
category: client
access: ro
type: string
needsClient: true
related: ["#CliLang", "#EUOVer"]
aliases: ["client version"]
dll: CliVer
source: wiki
---

`#CliVer` is the version of the attached client, as EasyUO Reforged recognised it, for example `7.0.117.1`.

## Example

```euo
if #CliVer <> 7.0.117.1
  event SysMessage This script was written for 7.0.117.1.
```
