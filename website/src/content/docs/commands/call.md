---
title: "Call"
description: "Runs another script file, then comes back when it exits. EasyUO 1.5 finds the file only in its own folder or by a full path; Reforged also looks in the search folders."
kind: command
category: flow
syntax: "call {file} [parameter...]"
related: ["exit", "gosub", "#CurPath", "sql open"]
aliases: ["include", "run script", "library folder", "search folders", "EUOPATH"]
changed: true
source: wiki
---

`call` runs another script file. When that script reaches [`exit`](/commands/exit/) or its last line, the
calling script goes on with the line after the `call`.

## Parameters

| Parameter | Meaning |
|---|---|
| `file` | The script to run: a full path, or a name that is looked for in [`#CurPath`](/variables/curpath/) and, in Reforged, in the search folders (see [Where call looks for the file](#where-call-looks-for-the-file)). When a file isn't found as written, `.txt` and then `.euo` are added. |
| `parameter` | Optional values passed to the script. In it, `%1`, `%2`, … hold them and `%0` holds how many there are, as with [`gosub`](/commands/gosub/). |

## Where call looks for the file

`call` takes the first file it finds, in this order:

| Step | Where | EasyUO 1.5 |
|---|---|---|
| 1 | **A full path** (it starts with a drive, `C:\…`, or a backslash, `\…` or `\\server\…`) is used as written, and no folder is searched. | Yes |
| 2 | **[`#CurPath`](/variables/curpath/)**, the folder of the program (`EasyUOReforged.exe`, or `easyuo.exe` in EasyUO 1.5). | Yes |
| 3 | **The folders of *Tools → Search Folders***, from the top of the list down. | **No:** new in Reforged |
| 4 | **The folders of the `EUOPATH` environment variable**, from left to right. | **No:** new in Reforged |
| 5 | **Only under [`EUOCli`](/guide/euocli/):** the folders given with `--euopath`, then those of the `euopath` argument of an MCP tool. | **No:** new in Reforged |
| 6 | **Nothing found:** nothing happens, with no error, and the script goes on with the next line. | Yes |

In each place `call` tries the name as written, then with `.txt`, then with `.euo`, before it moves on to the
next one. EasyUO 1.5 does the same in `#CurPath` and for a full path. So `call helper` finds `helper.euo` in
`#CurPath` before it looks at `helper` in a search folder.

The script that runs `call` gives no folder of its own, in EasyUO 1.5 and in Reforged: a script in
`C:\Scripts` that calls `helper` doesn't look in `C:\Scripts` unless that folder is in a list.

[`sql open`](/commands/sql/open/#where-sql-open-looks-for-the-file) looks for a database file in the same
places, in the same order, trying `.db` and `.sqlite` instead.

:::note[Writing for EasyUO 1.5 too]
EasyUO 1.5 looks for a file only at a full path or in `#CurPath`, the folder of `easyuo.exe` (steps 1, 2 and 6).
The search folders, `EUOPATH` and `--euopath` are new in EasyUO Reforged: in EasyUO 1.5 a `call` of a file
that is only in such a folder does nothing, with no error. A script that must also run on EasyUO 1.5 keeps the
files it calls in the EasyUO folder, or in a folder inside it named in the `call` (`call lib\healing.euo`), or
gives a full path. See [a script for both](#a-script-for-both).

[`EUOCli check`](/guide/euocli/#check-a-script) and [`EUOCli run`](/guide/euocli/#run-a-script) search the
search folders too, so a file they find may still be missing for EasyUO 1.5.
:::

### The Search Folders list (Reforged)

*Tools → Search Folders* opens the list. It works like the window Windows uses for the `PATH` variable:

- **New** adds a row and **Edit** (or F2, or a double click) changes one. Type the folder in the row.
- **Browse...** picks a folder.
- **Delete** removes the selected row, and **Move Up** and **Move Down** change the order.
- **Edit text...** shows the whole list as one line, the folders separated by `;`.

A folder that doesn't exist is shown grey and skipped. A relative folder, such as `lib`, starts from
`#CurPath`. The list is saved when you press **OK**, and every script uses it from its next `call` or
`sql open`, also a script that is running. [`EUOCli`](/guide/euocli/) reads the same list.

### The EUOPATH variable (Reforged)

`EUOPATH` is a Windows environment variable, written like `PATH`: folders separated by `;`. Set it in
*Settings → System → About → Advanced system settings → Environment Variables*, then start EasyUO
Reforged again, because a program only sees the variables it was started with. It is searched after the
Search Folders list, by the editor and by `EUOCli`. As in the list, a relative folder starts from `#CurPath`
and a folder that doesn't exist is skipped. EasyUO 1.5 ignores it.

## Details

- **Variables are shared** between the two scripts. A called script cannot return a value, so set a
  variable; see [`exit`](/commands/exit/) for an example.
- **Spaces in the path:** a space separates parameters, so `C:\My Scripts\a.euo` is read as two words.
  Glue the parts together with commas and `#spc`: `call C:\My , #spc , Scripts\a.euo`. In Reforged a file in a
  search folder needs only its name, so a folder with spaces in it is no trouble there.

## Examples

```euo
call greet.euo Jim Bob
halt
```

`greet.euo`, in the folder of `EasyUOReforged.exe`:

```euo title="greet.euo"
display ok Hello %1 and %2
exit
```

This works in EasyUO 1.5 too, with `greet.euo` in the folder of `easyuo.exe`.

### A library folder (Reforged)

Keep the scripts that many scripts use in one folder, for example `C:\UO\Library`, and add it to
*Tools → Search Folders*. Every script can then call them by name, wherever the script itself is saved:

```euo
call healing.euo
call travel.euo Britain
halt
```

In EasyUO 1.5 these two lines do nothing, unless the files are in the folder of `easyuo.exe`.

### A script for both

Put the library in a folder inside the program's folder, such as `lib`, and name it in the `call`. A relative
path starts from `#CurPath` in EasyUO 1.5 and in Reforged alike:

```euo
call lib\healing.euo
call lib\travel.euo Britain
halt
```

## Reforged notes

- EasyUO 1.5 looks for a relative name in `#CurPath` only. Reforged also looks in the Search Folders list,
  in `EUOPATH` and, under `EUOCli`, in the `--euopath` folders. `#CurPath` is still searched first and in
  full, so a script that worked before loads the same file.
- A `call` whose file was missing did nothing before. If the file is now in a search folder, it runs.
- A file that is not UTF-8, such as an old script saved in the Windows encoding, is read as Windows-1252, as the
  editor reads it, so its letters with accents match the calling script's. See
  [Letters with accents](/language/variables/#letters-with-accents).
