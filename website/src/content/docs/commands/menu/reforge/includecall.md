---
title: "menu Reforge IncludeCall"
description: "Makes Reforged's choice of MENU system look at the files the script calls, too."
kind: subcommand
category: menu
syntax: "menu Reforge IncludeCall {#true|#false}"
origin: reforged
menuLogic: ['1.5', '1.6']
related: ["menu Reforge Mode", "Call"]
aliases: ["include call", "called files"]
---

When a script starts, Reforged picks its [MENU system](/commands/menu/versions/) by reading the script for
the sub-commands only EasyUO 1.6 has. By default it reads only the main script. With
`menu Reforge IncludeCall #true` it also reads the files the script pulls in with [`call`](/commands/call/),
and the files those call.

## Parameters

| Parameter | Meaning |
|---|---|
| `#true` | Read the called files too. `true`, `1` and `-1` mean the same. |
| `#false` | Read only the main script, the default. `false` and `0` mean the same. |

## Description

- **Which files.** Every `call` line with a file name written out, found the way `call` finds it: a name
  without a folder is looked for in EasyUO Reforged's own folder, and `.txt`, then `.euo`, is added when the
  name as given does not exist. Each file is read once, so files calling each other are fine.
- **Not seen.** A file name taken from a variable (`call %lib`) or built with `,` is only known when the line
  runs, so that file is not read. Neither is a file that does not exist when the script starts. Use
  [`menu Reforge Mode 1.6`](/commands/menu/reforge/mode/) for those scripts.
- **[`menu Reforge Mode`](/commands/menu/reforge/mode/) wins.** When the script sets the mode, nothing is
  read.
- Like `menu Reforge Mode`, it is read from the main script before it runs, needs its value written out, does
  nothing when the line runs, and is ignored by EasyUO 1.5 and 1.6.

## Example

Save this as `menulib.txt` in the folder EasyUO Reforged is in:

```euo title="menulib.txt"
menu Form lib 300 200 260 50 Built by menulib.txt
menu Text t 10 10 This window comes from the called file.
menu SetProp lib visible #true
exit
```

Then run this script. Without its first line it would run under the 1.5 MENU and show nothing.

```euo title="Main script"
menu Reforge IncludeCall #true
call menulib.txt     ; uses menu Form: the script runs under the 1.6 MENU
halt
```

## Reforged notes

`menu Reforge IncludeCall` is new in EasyUO Reforged, which runs both MENU systems.
