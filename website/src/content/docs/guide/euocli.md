---
title: Check a script with EUOCli
description: "EUOCli check reports what EasyUO would skip or misread in a script, without running it: unknown commands and #variables, missing spaces, open blocks, jumps to nowhere and a missing halt."
sidebar:
  order: 6
---

EasyUO gives no errors. A line it can't understand is skipped, and the script goes on, so a typo shows up
only as a script that does the wrong thing. `EUOCli check` reads a script without running it and reports
what EasyUO would skip or misread.

`EUOCli.exe` is in the release zip, next to `EasyUOReforged.exe`. It is a command-line program: run it from
a terminal, or let an [AI coding agent](/guide/agents/) run it on the scripts it writes. `check` needs no UO
client.

## Check a script

```text title="loot.euo"
set %bag ABCDEFG              ; your loot bag
finditm POF G_3
if (#FindCnt > 0)
{
  exevent drag #FindID #FindStak
  exevent dropc %bag
}
gosub report
```

```text
> EUOCli check loot.euo
loot.euo:2:1: warning [unknown-command] "finditm" is not a command: the interpreter skips this line without an error.
    Take the command from the command list. If this was meant as a label, it needs a : at the end.
loot.euo:3:4: warning [glued-words] "(#FindCnt" is one word to the interpreter: nothing in it is replaced or worked out.
    Put a space around every operator and parenthesis: ( %a > 1 ), %b + 1.
loot.euo:3:16: warning [glued-words] "0)" is one word to the interpreter: nothing in it is replaced or worked out.
    Put a space around every operator and parenthesis: ( %a > 1 ), %b + 1.
loot.euo:5:24: warning [unknown-variable] #FindStak is not a variable of EasyUO: it reads N/A.
    Take the name from the variable list.
loot.euo:8:7: warning [missing-sub] There is no "sub report" in this script: the gosub does nothing.
    A sub has to be in the same file as its gosub.
loot.euo:8: warning [restarts-at-end] After this line the script can reach its end, which starts it again from the first line (in a called file: returns to the caller).
    End the main part with halt, and put the subs after it. A called file ends with exit.
loot.euo: note [needs-client] These commands act on the UO client and are skipped when none is attached: exevent.
loot.euo: 6 warnings, 1 note
```

Each finding gives the file, the line and the column, the rule in brackets, what is wrong, and on the next
line what to do about it. A script with nothing to report prints `loot.euo: nothing found`.

## The command

```text
EUOCli check <script.euo> [more scripts] [--json] [--strict] [--curpath <folder>]
```

| Part | Meaning |
|---|---|
| `<script>` | A script file. `-` reads the script from standard input, to check text that isn't saved. |
| `--json` | Print the findings as JSON, for a program to read. |
| `--strict` | Exit with code `1` when there is a warning. Without it the exit code is `0` whatever is found. |
| `--curpath <folder>` | The folder [`call`](/commands/call/) starts from: the folder of `EasyUOReforged.exe` ([`#CurPath`](/variables/curpath/)). Default: the folder of `EUOCli.exe`. |

The exit code is `0` when the scripts were checked, `1` with `--strict` when a warning was found, and `2`
when the command line is wrong or a file can't be read.

`EUOCli help` lists the commands and `EUOCli version` prints the version, the same as
[`#ReforgedVer`](/variables/reforgedver/).

## What it reports

Everything is a warning or a note, never an error: old scripts rely on odd behaviour, and what looks wrong
may be meant. A note is information about the whole script.

| Rule | It reports |
|---|---|
| `unknown-command` | A line whose first word is not a [command](/commands/), a label or a brace. EasyUO skips the line. |
| `unknown-variable` | A `#name` that is not a [variable](/variables/). It reads `N/A`. |
| `unknown-subcommand` | `event`, `exevent`, `menu`, `namespace`, `str`, `sql` or `path` followed by a word that is not one of its sub-commands. The line does nothing. |
| `glued-words` | In a command that calculates (`set`, `if`, `while`, `until`, `return`, `waitfor`): words with no space between them, such as `(%a`, `1)`, `%a=1`, `%b+1`, `!%a`. |
| `brace-on-header-line` | A `{` at the end of an `if`, `for`, `while` or `sub` line. It is read as a parameter, not as a block. |
| `stray-brace` | A `{` line that doesn't directly follow its command, for example after a blank line. Its block always runs. |
| `unbalanced-braces` | A `}` with no `{` before it, or a `{` that is never closed. |
| `repeat-until` | An `until` without a `repeat`, or the other way round. |
| `missing-sub` | A `gosub` to a sub the file doesn't have. |
| `missing-label` | A `goto` to a label the file doesn't have. |
| `missing-call-file` | A `call` of a file that isn't found. |
| `restarts-at-end` | The main part of the script doesn't end with `halt`, `stop`, `exit` or a `goto`, so it can reach the last line, and EasyUO then starts it again from the top. |
| `menu-logic` | A `menu` sub-command of the [MENU system](/commands/menu/versions/) the script doesn't run under. |
| `needs-client` (note) | Which commands of the script act on the UO client. They are skipped when no client is attached. |
| `menu-logic-chosen` (note) | Which MENU system the script will run under, and why. |

[Common mistakes](/language/common-mistakes/) explains the rules of the language behind these.

## What it can't know

`EUOCli check` reads the script; it doesn't run it. So:

- **A word that only exists when the script runs is never reported:** a command, sub-command, sub or label
  held in a variable (`gosub %name`), or built with `,` or `.`.
- **Text is left alone.** Scripts keep a lot of plain text in `set` and `if` lines, and it may hold any
  character: `(none)`, `===`, `120/125`. Only what looks like operators and operands stuck together counts
  as glued.
- **Item types, IDs, gump names and journal texts are not checked.** Only your game knows them: see
  [Finding IDs and types](/guides/finding-ids/).
- **`restarts-at-end` looks at the last line of the main part.** A script that ends inside a block or in an
  `else`, or with a `gosub` to a sub that never returns, is reported although it may never reach its end.
- **A clean report doesn't mean the script works.** It means EasyUO will read every line as you wrote it.

## JSON

With `--json` the output is one object:

```json
{
  "version": "26.11.10.c0af675",
  "files": [
    {
      "file": "loot.euo",
      "lines": 8,
      "findings": [
        {
          "rule": "unknown-command",
          "severity": "warning",
          "line": 2,
          "column": 1,
          "word": "finditm",
          "message": "\"finditm\" is not a command: the interpreter skips this line without an error.",
          "hint": "Take the command from the command list. If this was meant as a label, it needs a : at the end."
        }
      ],
      "summary": { "warnings": 6, "notes": 1, "menuLogic": "", "clientCommands": ["exevent"] }
    }
  ],
  "warnings": 6,
  "notes": 1
}
```

`line` is `0` for a finding about the whole script, and `column` is `0` when a finding is about a whole
line. `menuLogic` is `1.5` or `1.6` for a script with `menu` lines, and empty otherwise. The output is
UTF-8.
