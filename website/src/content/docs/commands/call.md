---
title: "Call"
description: "Runs another script file, then comes back when it exits."
kind: command
category: flow
syntax: "call {file} [parameter...]"
related: ["exit", "gosub", "#CurPath"]
aliases: ["include", "run script"]
source: wiki
---

`call` runs another script file. When that script reaches [`exit`](/commands/exit/) or its last line, the
calling script goes on with the line after the `call`.

## Parameters

| Parameter | Meaning |
|---|---|
| `file` | The script to run. A relative path starts from [`#CurPath`](/variables/curpath/), the folder of `EasyUOReforged.exe`. When the file is not found as written, `.txt` and then `.euo` are added. |
| `parameter` | Optional values passed to the script. In it, `%1`, `%2`, … hold them and `%0` holds how many there are, as with [`gosub`](/commands/gosub/). |

## Details

- **File not found:** nothing happens and the script goes on with the next line.
- **Variables are shared** between the two scripts. A called script cannot return a value, so set a
  variable; see [`exit`](/commands/exit/) for an example.
- **Spaces in the path:** a space separates parameters, so `C:\My Scripts\a.euo` is read as two words.
  Glue the parts together with commas and `#spc`: `call C:\My , #spc , Scripts\a.euo`.

## Example

```euo
call greet.euo Jim Bob
halt
```

`greet.euo`, in the folder of `EasyUOReforged.exe`:

```euo title="greet.euo"
display ok Hello %1 and %2
exit
```
