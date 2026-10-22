---
title: "Call"
description: "Transfers execution to another script file."
kind: command
category: flow
syntax: "call {file} [parameter...]"
source: wiki
---

*call* command will transfer execution to another script. It will run the script until it meets the [exit](/commands/exit/) command or the end of the file.

:::note
Right now EasyUO doesn't really support strings. Therefore, CALL won't work if the path to a file contains any spaces. Use the DOS short filename syntax to get around this problem.

wrong: C:\My Documents\blabla.txt

correct: C:\MyDocu~1\blabla.txt
:::

## Example

```euo
call subs.txt recall %runebookid %runenum
halt
```

Note: call arguments handling work exactly the same as goSub command. Thus, %0 will hold the number of parameters passed, %1 will hold the first argument passed value and so on. See [exit command](/commands/exit/) page for more infos.

EDIT on 23 jan 2008: For those who know nothing about MS-DOS shortcut thing, here's a way to get around it when using paths containing spaces(Tested on Windows Vista):

Wrong: C:\My Documents\file.txt

Correct: C:\My , #spc , Documents\file.txt (tested on Windows Vista, compatibility with older systems isn't guaranteed)
