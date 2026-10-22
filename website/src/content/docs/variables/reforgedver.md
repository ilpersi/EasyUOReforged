---
title: "#ReforgedVer"
description: "Build version of EasyUO Reforged, such as 26.10.22.3c144de."
kind: variable
category: misc
access: ro
type: string
origin: reforged
related: ["#EUOVer"]
aliases: ["reforged version", "version"]
---

`#ReforgedVer` is the version of the EasyUO Reforged build running the script: the build date and the git
commit it was built from, `YY.MM.DD.<commit>`, for example `26.10.22.3c144de`. The window title and
**Help → About** show the same value.

[`#EUOVer`](/variables/euover/) still returns the original `1_50_00`, so existing version checks keep
working. Use `#ReforgedVer` when a script needs to know it runs on Reforged, or which build.

## Example

```euo
if #ReforgedVer = N/A
  display ok This script needs EasyUO Reforged.
```
