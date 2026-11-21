---
title: "#CurPath"
description: "Folder of EasyUOReforged.exe, ending with a backslash."
kind: variable
category: script
access: ro
type: string
related: ["Call", "sql open"]
aliases: ["current path", "install folder"]
---

`#CurPath` is the folder `EasyUOReforged.exe` was started from, ending with `\`, for example
`C:\Games\EasyUO\`.

Relative paths in [`call`](/commands/call/) and [`sql open`](/commands/sql/open/) start from this folder.
A file `call` doesn't find here is then looked for in the CALL folders: see
[Where call looks for the file](/commands/call/#where-call-looks-for-the-file).

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
