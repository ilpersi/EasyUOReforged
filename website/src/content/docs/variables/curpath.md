---
title: "#CurPath"
description: "Folder of EasyUOReforged.exe, ending with a backslash."
kind: variable
category: misc
access: ro
type: string
related: ["Call", "sql open"]
aliases: ["current path", "install folder"]
---

`#CurPath` is the folder `EasyUOReforged.exe` was started from, ending with `\`, for example
`C:\Games\EasyUO\`.

Relative paths in [`call`](/commands/call/) and [`sql open`](/commands/sql/open/) start from this folder.

## Example

```euo
display ok EasyUO Reforged was started from #CurPath
call #CurPath , healing.euo
halt
```

`healing.euo`, in that folder:

```euo title="healing.euo"
display ok healing.euo runs.
exit
```
