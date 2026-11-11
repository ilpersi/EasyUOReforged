---
title: Check and run scripts with EUOCli
description: "EUOCli is EasyUO Reforged from the command line: check reports what EasyUO would skip or misread in a script, run runs a script and prints what happens, vars and clients read the game."
sidebar:
  order: 6
---

`EUOCli.exe` is EasyUO Reforged from the command line. It is in the release zip, next to
`EasyUOReforged.exe`: run it from a terminal, or let an [AI coding agent](/guide/agents/) run it on the
scripts it writes.

| Command | What it does |
|---|---|
| [`EUOCli check`](#check-a-script) | Reports what EasyUO would skip or misread in a script, without running it. |
| [`EUOCli run`](#run-a-script) | Runs a script with nobody watching and prints what happens. |
| [`EUOCli vars`](#read-variables) | Reads variables from a client, without a script. |
| [`EUOCli clients`](#list-the-clients) | Lists the UO clients found. |

`EUOCli help` lists the commands, `EUOCli help run` explains one, and `EUOCli version` prints the version,
the same as [`#ReforgedVer`](/variables/reforgedver/). The output is UTF-8.

## Check a script

EasyUO gives no errors. A line it can't understand is skipped, and the script goes on, so a typo shows up
only as a script that does the wrong thing. `EUOCli check` reads a script without running it and reports
what EasyUO would skip or misread. It needs no UO client.

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

### The command

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

### What it reports

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

### What it can't know

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

### JSON

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
line. `menuLogic` is `1.5` or `1.6` for a script with `menu` lines, and empty otherwise.

## Run a script

`EUOCli run` runs a script on the same engine as the editor, with nobody watching, and prints what happens:
what the script writes with [`log`](/commands/log/), what its [`display`](/commands/display/) boxes would
have shown, and why and where the run ended.

```euo title="sum.euo"
set %sum 0
for %i 1 5
  set %sum %sum + %i
log The sum is %sum
display yesno Go on?
log You answered #DispRes
finditem POF G_3
log finditem found #FindCnt
halt
```

```text
> EUOCli run sum.euo --dump %sum
running sum.euo without a client (commands that need one are skipped)
[4] log: The sum is 15
[5] display (yesno, answered Yes): Go on?
[6] log: You answered Yes
[8] log: finditem found N/A
ended: halt at line 9 after 0.1 s
1 line was skipped because its command needs a client
%sum = 15
```

The number in brackets is the line of the script.

### What is different from the editor

`run` is made for a script nobody has read yet, started by a program that can't click or look at the game.

- **No client unless you say so.** Without `--client` the script runs with no UO client, whatever is open:
  commands that need one are skipped and client variables read `N/A`, exactly as EasyUO does without a
  client. Nothing happens in the game. That is enough to test a script's logic. `--client 1` runs it on your
  character.
- **`display` doesn't open a box.** The text is printed, and the box is answered with its first button
  (`ok`, or `yes`), or with `--answer`.
- **It always ends.** The script is stopped after 60 seconds (`--timeout`), and when it reaches its end and
  starts over because it has no `halt`.
- **Some commands stop the run instead of running:** [`execute`](/commands/execute/),
  [`shutdown`](/commands/shutdown/), [`terminate`](/commands/terminate/), [`uoxl`](/commands/uoxl/) and
  [`send`](/commands/send/). They reach beyond the script: they start programs, switch the computer off,
  close or start clients, and fetch a reply from the web and run it. `--allow` lets them through.
- **`pause` ends the run:** nobody is there to press Start again.

[`menu`](/commands/menu/) works: the window opens on your screen. A script that waits for a click in it
runs until the timeout.

### The command

```text
EUOCli run <script.euo> [--client <n>] [--timeout <seconds>] [--json] [--trace]
           [--dump <variables>] [--answer ok|yes|no|cancel] [--allow <commands>]
```

| Part | Meaning |
|---|---|
| `<script>` | A script file. `-` reads the script from standard input. |
| `--client <n>` | Run it on UO client number `n`, as [`EUOCli clients`](#list-the-clients) lists them. Without it: no client. |
| `--timeout <seconds>` | Stop the script after this many seconds. Default: `60`. `0`: never. |
| `--json` | Print one JSON object per line instead of text. |
| `--trace` | Print every line before it runs, up to 5000 lines. |
| `--dump <variables>` | Print these variables when the run ends: `--dump %a,%b,#FindCnt`. |
| `--answer <button>` | Answer `display` boxes that have this button with it: `ok`, `yes`, `no` or `cancel`. |
| `--show-display` | Open the real message boxes and wait for a click. |
| `--allow <commands>` | Run these although they are blocked: `--allow execute,send`. |

A [`call`](/commands/call/) starts from the folder of `EUOCli.exe`, as it starts from the folder of
`EasyUOReforged.exe` in the editor.

### How a run ends

The last line says why the run ended, and the exit code says the same to a program.

| Reason | Exit code | What happened |
|---|---|---|
| `halt` | `0` | The script stopped itself with `halt` or `stop`. |
| `pause` | `0` | The script reached a `pause`. |
| `timeout` | `3` | It was still running after `--timeout`. |
| `error` | `4` | A command raised an error; the line says which. |
| `client-lost` | `5` | The client of `--client` closed during the run. Also the exit code when that client isn't there at the start. |
| `blocked` | `6` | The script reached a blocked command. Nothing after it ran. |
| `restart` | `7` | The script reached its end and started over: it has no `halt`. It was stopped before its first line ran again. |
| `interrupted` | `8` | You pressed Ctrl+C. |

Exit code `2` means the command line was wrong or the script couldn't be read.

### JSON events

With `--json` every event is one line holding one object, so a program can read the run as it goes:

```json
{"event":"start","file":"sum.euo","client":0,"timeout":60,"blocked":["execute","shutdown","terminate","uoxl","send"]}
{"event":"log","line":4,"text":"The sum is 15"}
{"event":"display","line":5,"buttons":"yesno","text":"Go on?","answer":"Yes"}
{"event":"log","line":6,"text":"You answered Yes"}
{"event":"log","line":8,"text":"finditem found N/A"}
{"event":"end","reason":"halt","detail":"","line":9,"exitCode":0,"elapsedMs":125,"client":0,"clientLinesSkipped":1,"vars":{"%sum":"15"}}
```

| Event | Fields |
|---|---|
| `start` | `file`, `client` (0: none), `timeout` in seconds, `blocked`: the commands that would stop the run. |
| `log` | `line`, `text`: a [`log`](/commands/log/) line. |
| `display` | `line`, `buttons`, `text`, `answer`: a `display` box and how it was answered. |
| `line` | `line`, `text`, `depth`: with `--trace`, a line about to run; `depth` is above 0 inside a called script. |
| `menu` | `text`: a notice about the [MENU system](/commands/menu/versions/) the script needs. |
| `end` | `reason`, `detail`, `line` (the last line that ran), `exitCode`, `elapsedMs`, `client`, `clientLinesSkipped`, `vars` (what `--dump` asked for). |

## Read variables

`EUOCli vars` reads variables from a client without a script: where the character stands, what the top
gump is, what the last target was.

```text
> EUOCli vars #CharName #CharPosX #CharPosY #ContName
#CharName = Lord_Blackthorn
#CharPosX = 1434
#CharPosY = 1699
#ContName = container_gump
```

```text
EUOCli vars <variable> [more variables] [--client <n>] [--json]
EUOCli vars --all [--client <n>] [--json]
```

| Part | Meaning |
|---|---|
| `<variable>` | A [`#variable`](/variables/); the `#` may be left out. A persistent `*variable` works too. `%` and `!` variables belong to a running script and can't be read. |
| `--all` | Every `#variable`. |
| `--client <n>` | Which client. Default: client 1 when one is running. `0`: no client, and client variables read `N/A`. |
| `--json` | Print `{"client": 1, "vars": {"#CharName": "..."}}`. |

Reading changes nothing in the game. Variables a command fills, such as `#FindID`, hold nothing here: no
script has run.

## List the clients

```text
> EUOCli clients
1  7.0.117.1  "Ultima Online - Lord Blackthorn (Atlantic)"  character Lord_Blackthorn
2  7.0.117.1  "Ultima Online"  nobody logged in
```

The number is what `--client` takes. `--json` prints the same as
`{"clients": [{"nr", "pid", "version", "title", "loggedIn", "character"}], "denied": 0}`; `denied` counts
clients that run as administrator and can't be opened.
