---
title: "#CliLang"
description: "Language code of the client, such as ENU."
kind: variable
category: client
access: ro
type: string
needsClient: true
related: ["#CliVer"]
aliases: ["client language"]
---

`#CliLang` is the three-letter language code of the attached client, for example `ENU` for English. It is
empty when the client does not report one.

Texts such as [`#BuffName`](/variables/buffname/) and journal lines are in this language, so a shared script
can check it before comparing text.

## Example

```euo
if #CliLang <> ENU
  display ok This script expects an English client.
```
