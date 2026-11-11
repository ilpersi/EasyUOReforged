---
title: The agent pack and EUOCli
description: "For contributors: how the agent pack (the euo-script skill) is written, generated, checked and tried, and how EUOCli is built: its units, the rules of a run, the MCP server, and what to update with each kind of change."
sidebar:
  order: 9
---

Two things let an AI coding agent write EasyUO scripts: the **agent pack**, which tells it the language, and
**`EUOCli.exe`**, which lets it check and run what it wrote. This page is for people who change either. What
they do for a user is on [Write scripts with an AI agent](/guide/agents/) and
[Check and run scripts with EUOCli](/guide/euocli/). The plan, the owner's decisions and what each phase
found are in `docs/agent-support.md` in the repository.

| Piece | Where | What it is |
|---|---|---|
| The hand-written pack files | `agent/` | `README.md`, `AGENTS.md` and the skill's `euo-script/SKILL.md`. |
| The generator | `tools/docs/gen-agent-pack.mjs` | Builds the rest of the pack from this site's pages. |
| The rules pages | `language/common-mistakes.md`, `guides/patterns.md`, `guides/finding-ids.md` | Three pages of this site that become the pack's `language.md`. |
| The script checker | `parser/EuoLint.pas`, `parser/EuoVocabulary.pas` | What `EUOCli check` runs. |
| The program | `EUOCli.lpr`, `tools/EUOCli/*.pas` | The commands, the run and the MCP server. |
| The checks | `tests/tools/CheckAgentPack.ps1`, `tests/DocsLintTests.pas`, `tests/DocsExampleTests.pas`, `tests/EuoCli*Tests.pas` | All run by `tests/run_tests.ps1`. |

## The agent pack

The pack is one folder, `euo-script`, plus an `AGENTS.md` and a `README.md` beside it. The folder is a
Claude Code skill as it is: copying it into `.claude\skills\` is the whole setup, and other agents are
pointed to it by `AGENTS.md`.

### What is written by hand, and what is generated

| File of the pack | Comes from |
|---|---|
| `README.md`, `AGENTS.md`, `euo-script/SKILL.md` | `agent/`, copied as they are. |
| `euo-script/language.md` | The three rules pages, one after the other. |
| `euo-script/commands.md`, `variables.md` | The frontmatter of every command and variable page: `syntax`, `description`, `needsClient`, `origin`, `changed`. |
| `euo-script/reference.json` | The same frontmatter as data, with `aliases` and each page's file. `EUOCli docs` reads it. |
| `euo-script/reference/**` | One markdown file per page of the `language`, `commands`, `variables`, `guides`, `guide` and `reforged` folders. |
| `euo-script/VERSION` | `--version`, or `git describe --tags --always`. |
| `euo-script/LICENSE-GFDL-1.2.txt` | `website/LICENSE-GFDL-1.2.txt`. Pages with `source: wiki` keep their notice. |

**Nothing generated is committed.** The generator stops if it finds a `language.md`, `commands.md`,
`variables.md` or `reference.json` in `agent/euo-script/`.

Left out on purpose: the `dll`, `designer` and `developers` folders (they are not about writing scripts),
and `guide/agents.md` (it describes the pack itself). So this page and the prompt examples never reach an
agent.

### Where a change goes

| You want to change | Change |
|---|---|
| A rule of the language, a pattern, a probe script | One of the three rules pages. They are ordinary pages, read by people too, so each rule exists once. |
| How the agent works: its steps, when it asks, what it must never do | `agent/euo-script/SKILL.md`. |
| The few rules for an agent that reads nothing else | `agent/AGENTS.md`. |
| A command's or variable's line on the lists | The frontmatter of its page. |
| When Claude Code loads the skill | `description:` in the frontmatter of `SKILL.md`. |
| What the tools say about themselves | `Instructions` and `ToolList` in `tools/EUOCli/climcp.pas`. |

A new command or `#variable` needs nothing here: its page is in the pack with the next build.

Things that are easy to get wrong:

- **`SKILL.md`'s `name:` is the folder's name,** `euo-script`. `EUOCli init` and the generator both use it.
- **The `description:` decides whether the skill is used at all.** Until it loads the skill, Claude Code
  reads only its name and that line. Keep the words a user would say in it: EasyUO, EUO, `.euo`, UO macro or script.
- **`SKILL.md` names files relative to its own folder** (`language.md`, `reference/commands/...`).
  `AGENTS.md` names them as `` `euo-script/...` ``, with the backtick: `EUOCli init` rewrites exactly that
  to `` `.claude/skills/euo-script/...` `` when it writes the block into a user's `AGENTS.md`.
- **Frontmatter is read by a small parser of the generator's own:** one `key: value` per line, lists on
  one line. It stops the build on a line it can't read, so a page is never left out silently.
- **A command page needs a `syntax`,** and every page a `title` and a `description`.
- **The same rule is said in several places:** `SKILL.md`, `AGENTS.md`, `README.md`, the server's
  `Instructions`, and the user pages. When a safety rule changes, change all of them.

### Build it

The generator needs Node only, no `npm install`:

```powershell
node tools/docs/gen-agent-pack.mjs --check
node tools/docs/gen-agent-pack.mjs --out C:\Temp\pack
node tools/docs/gen-agent-pack.mjs --site website\dist
```

| Option | What it does |
|---|---|
| `--check` | Builds the pack in memory and writes nothing. The quickest way to see whether a page breaks it. |
| `--out <folder>` | Writes the pack into the folder, **emptying it first**. |
| `--site <dist folder>` | Writes it as `<dist>\agent\`, with `llms.txt` and `llms-full.txt` at the root. |
| `--version <text>` | The text for `VERSION` and the file headers. |

It runs in three places by itself:

- **`npm run build` in `website/`:** `astro.config.mjs` calls it when the build is done, so the published
  site serves `/agent/...`, `/llms.txt` and `/llms-full.txt`. `npm run dev` does not serve them.
- **`release.yml`:** writes the pack into the zip's `agent` folder, with the tag as version.
- **`CheckAgentPack.ps1`:** builds it into a temporary folder to check it.

### What checks it

| Check | It fails when |
|---|---|
| The generator | A page can't be read, a command has no `syntax`, a page is missing from the lists, or an `euo` example of `agent/` doesn't end with `halt`. |
| `CheckAgentPack.ps1`: the lists | A command, sub-command or `#variable` of the interpreter is not on `commands.md` or `variables.md`. Exceptions: `$NotInPack`. |
| `CheckAgentPack.ps1`: the rules | The "Which commands do what" table of the mistakes page differs from what the command handlers do (which call `Eval`, `ScanForBlock`, `ParseTicksOrSeconds`). |
| `CheckAgentPack.ps1`: the flags | A command page's `needsClient` differs from how the interpreter registers the command. Exceptions: `$ClientDiffers`. |
| `CheckAgentPack.ps1`: the gate | Something with `origin: reforged` or `changed: true` is neither mentioned in the rules pages nor on `$NoRuleNeeded` with a reason. |
| `TDocsLintTests` | The script checker warns about an `euo` example of this site or of `agent/`. A mistake shown on purpose goes in its `Excepted` table, with the reason. |
| `TDocsExampleTests` | An example's `; => %x = 5` comment is not what the interpreter gives. Such examples may use only the commands on its `Allowed` list. |

The gate is there so that nobody adds a command without deciding whether an agent has to be told how to use
it. `CheckAgentPack.ps1` needs Node: without it the check is skipped with a warning, and fails in CI.

### Try it with an agent

An installed skill is a copy. It does not follow the repository, so refresh it after a change:

```powershell
cd website
npm run build
cd ..
.\EUOCli.exe init C:\Temp\scripts
```

From a checkout, `EUOCli` finds the pack the site build wrote (`website\dist\agent\euo-script`). To use
another one, pass `--pack <folder>\euo-script`. Then start the agent in that folder, in a new session, and
ask for a script. Look at what it does, not only at the script:

- Did it load the skill, and read `language.md` before writing?
- Did it look the commands up, or write them from memory?
- Did it ask for the values it could not know, or make them up?
- Did it check the script, run it without a client, and say what it could not test?
- Did it ask before a run on a client?

If you also keep the skill in `%USERPROFILE%\.claude\skills\euo-script`, that copy is as old as the day you
put it there.

## EUOCli

`EUOCli.lpi` builds a console program that requires the `euoparser` package and LCL, and takes
`easyuo/scriptfile.pas` by path, to read script files as the editor does. It has its own unit folders
(`lib\...-euocli\` and `...-euocli-release\`). See [Build from source](/developers/building/).

| Unit | What it holds |
|---|---|
| `EUOCli.lpr` | Reads the arguments and standard input, prints what comes back as UTF-8 bytes, ends the process. Nothing else. |
| `tools/EUOCli/climain.pas` | `RunCli`: takes the command line apart and calls the command's unit. `help` and `version`. |
| `clicheck.pas` | `check`: runs `TEuoLinter` and prints its findings as text or JSON. |
| `clisession.pas` | `TRunSession`: one run of a script on a `TExecutor`, with its rules. |
| `clirun.pas` | `run`, `vars`, `clients`, and the exit codes. |
| `climcp.pas` | `mcp`: `TMcpServer` and the program's loop. |
| `clidocs.pas` | `docs`: finds the pack and looks a name up in it. |
| `cliinit.pas` | `init`: copies the pack and writes `AGENTS.md` and `.mcp.json`. |

### The program only prints

Every command is a function of the form "arguments in, lines and an exit code out":

```pascal
function RunCli(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;
```

The test suite calls these directly (`tests/RunTests.lpi` has `tools\EUOCli` on its unit path), so no test
starts the program. Two commands print while they work, through a procedure the program sets:
`clirun.CliOnLine` for `run`, and `climcp.McpOut` for the server. Keep new logic out of `EUOCli.lpr`.

### Two things about how it starts and ends

- **It looks for UO clients when it starts, whatever the command.** Linking the engine brings in
  `uo/uoselector.pas`, whose initialization starts the thread that finds clients, as in the editor. It only
  reads. `check` and a run without `--client` never attach to one.
- **It ends with `TerminateProcess`, on purpose.** That unit's finalization stops its thread with
  `TerminateThread`. A program that is done in milliseconds got there while the thread still held locks, and
  hung about every other run. By then everything is written and released. The header of `EUOCli.lpr` has the
  details: read it before changing how the program exits.

### The script checker

`parser/EuoLint.pas` is a pure unit: lines in, findings out. It runs nothing and copies nothing:

- **Names** come from the interpreter (`TEuoInterpreter.GetCommandNames` / `GetVariableNames`).
- **Sub-commands** come from `parser/EuoVocabulary.pas`, the table the editor's autocomplete uses.
  `CheckDocsCoverage.ps1` fails when its first level differs from the command handlers.
- **Lines, blocks and jumps** are read with the interpreter's own code: `EuoScriptWords`, `EuoBlocks`,
  `EuoJumpTarget`, `EuoMenuSelect`.

Its rules of conduct:

- Everything is a warning or a note. Old scripts rely on odd behaviour.
- A word that exists only when the script runs is never reported: a name held in a variable, or built with
  `,` or `.`.
- **A false warning costs more than a missed mistake.** An agent "fixes" what it is warned about, and a
  checker that complains about working scripts is one nobody believes.

To add a rule:

1. Its id in the list at the top of `EuoLint.pas`, and the check.
2. Tests in `tests/EuoLintTests.pas`: a script that triggers it, and scripts that must stay silent.
3. Run `TDocsLintTests`. It runs the checker over every example of this site and the self-test scripts. If
   the new rule warns about one, the rule is wrong, the example is wrong, or it is wrong on purpose and goes
   in `Excepted`.
4. Its row in "What it reports" on [the EUOCli page](/guide/euocli/#what-it-reports), and in `SKILL.md` if
   the agent should know it by name.

### A run

`TRunSession` (`clisession.pas`) runs a script on the same `TExecutor` as the editor. `EUOCli run` starts
one and waits for its end; the server keeps one alive between tool calls. A new option of a run goes in
`TRunOptions`, so both get it.

It works through hooks of the interpreter and the executor. **All of them are off unless a host sets
them:** the editor and `uo.dll` run scripts exactly as before. `TEuoHostHooksTests` covers each hook.

| Hook | What the host gets |
|---|---|
| `TEuoInterpreter.OnDisplay` | Answers a `display` instead of the message box. |
| `TEuoInterpreter.BlockCommands` | Commands that stop the run instead of running. `BlockedCmd` says which one did. |
| `TEuoInterpreter.Restarts`, `TExecutor.StopOnRestart` | The run stops when a script without `halt` starts over, before its first line runs again. |
| `TExecutor.OnLine` | Called with each line about to run, for a trace. |
| `TEuoInterpreter.ClientSkips` | How many lines were skipped for lack of a client. |
| `TEuoInterpreter.TakeLog` | The lines the script wrote with `log`. |

The host's part: **the main thread keeps pumping the LCL message loop** while a run is alive (`menu` builds
its windows there, through `TThread.Synchronize`) and calls `Tick`, which notices how the run ends. The
timeout counts the time the script runs, not the time it sits paused.

### The rules that are not yours to tune

These are the owner's decisions. Don't loosen one to make something else easier: open an issue first.

- **No client unless one is named.** `EUOCli run` uses a client only with `--client N`.
- **`execute`, `shutdown`, `terminate`, `uoxl` and `send` are blocked** unless `--allow` names them, and a
  blocked command stops the run. `DefaultBlocked` in `clisession.pas` is the list.
- **Every run ends:** at its timeout, or when a script without `halt` starts over.
- **`euo_run` has no argument for a client or a blocked command.** `euo_run_live` is the only tool with
  `client` and `allow`. Agent programs let a user allow a tool for good, whatever its arguments, so a
  `client` argument on `euo_run` would turn one click into every later run on the user's character.
  `TestRunHasNoWayToAClientOrABlockedCommand` pins the shape of the tool list.
- **The script stops when standard input ends,** so a run never outlives the agent that started it.

### The MCP server

`EUOCli mcp` speaks JSON-RPC 2.0, one message per line, on standard input and output.

- **Nothing else may reach standard output** while it runs. Every message goes through `McpOut`.
- **`TMcpServer.Handle` takes one message and returns its answer.** `tests/EuoCliMcpTests.pas` talks to
  the server that way, without a pipe. `RunMcp` is the program's loop: a thread reads standard input into
  the server's queue, and the main thread answers, pumps the message loop and keeps the run's clock.
- **Both ways of opening a session are answered.** Protocol versions 2024-11-05 to 2025-11-25 start with
  `initialize`. Version 2026-07-28 removed that handshake: each request carries the version, and
  `server/discover` describes the server. `McpVersions` lists what is accepted. For a new version of the
  protocol, read what changed before adding it to the list.
- **Only tools are offered:** no resources, prompts or notifications.
- **A tool answers with one piece of text,** JSON for all but `euo_docs`. A failure is raised as
  `EMcpToolError` and comes back with `isError`; an unknown tool is error -32602.
- **A run tool waits a few seconds** (`wait`, at most `McpMaxWait`) and then answers with the run's state.
  A script that is still going is followed with `euo_status`.

To add a tool:

1. Its row in `ToolList` (name, title, description, the JSON schema of its arguments, and whether it only
   reads), its branch in `CallTool`, and its method.
2. Tests in `EuoCliMcpTests`.
3. Its row in the tool table on [the EUOCli page](/guide/euocli/#tools-for-an-agent-euocli-mcp) and in
   "With the tools" of `SKILL.md`.
4. If it can act on a client or on the computer, it is not `euo_run`, and "What you approve" says so.

To talk to the server by hand, pipe messages into it:

```powershell
$messages = @(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"hand","version":"0"}}}',
  '{"jsonrpc":"2.0","method":"notifications/initialized"}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"euo_run","arguments":{"script":"set %a 2 + 3\nlog a is %a\nhalt"}}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"euo_status","arguments":{}}}'
)
$messages | .\EUOCli.exe mcp
```

The last message matters. The input ends with the pipe, and the server then stops the script: a run that is
the last message is answered at once, as still running. With a message after it, the call waits for the
script as it does for an agent.

### docs and init

- **`docs` stores nothing about the language.** It finds a name in the pack's `reference.json` (names
  first, then `aliases`) and prints that page's file.
- **The pack is looked for next to the program,** in `agent\euo-script` (a release), `euo-script`, and
  `website\dist\agent\euo-script` (a checkout after a site build). `--pack` names another.
- **`init` owns three things in the user's folder:** `.claude\skills\euo-script\` (replaced on each run,
  plus `euocli-path.txt`, which tells the skill where the program is), the block between two marker lines
  in `AGENTS.md`, and the `easyuo` entry of `.mcp.json`. It must never touch anything else there, and a
  `.mcp.json` it can't read is left alone.

### Tests

| Suite | What it covers |
|---|---|
| `TEuoLintTests` | Each rule of the checker, and what must stay silent. |
| `TEuoCliCheckTests` | `check`: text and JSON output, exit codes, standard input. |
| `TEuoHostHooksTests` | The hooks, and that they are off by default. |
| `TEuoCliRunTests` | `run`: `display` capture, timeout, restart, blocked commands, exit codes, JSON events. |
| `TEuoCliMcpTests` | The server: both protocol forms, each tool, stepping and breakpoints, the end of a session. |
| `TEuoCliInitTests` | `init` and `docs`, with a small pack made in a temporary folder. |
| `TDocsLintTests`, `TDocsExampleTests` | The examples of this site ([above](#what-checks-it)). |

```powershell
tests/RunTests.exe --format=plain --suite=TEuoCliMcpTests
```

None of them uses a UO client. What needs one (`run --client`, `vars`, `clients`, `euo_run_live`) is checked
by hand, one thing at a time.

## What to update with a change

| The change | Also update |
|---|---|
| A new script command or `#variable` | Its page, as always. Then either a mention on a rules page or an entry in `$NoRuleNeeded`. |
| A new rule or pattern for agents | A rules page. Give its example a `; =>` comment if it can run without a client. |
| A new option of a command | Its `...Help` text in the unit, [the EUOCli page](/guide/euocli/), `SKILL.md` if an agent should use it. |
| A new command of `EUOCli` | `climain.pas` (dispatch and `Help`), a unit with its `Run...` and `...Help`, `EUOCli.lpi`, tests, the EUOCli page, `SKILL.md`. |
| A new tool | [The MCP server](#the-mcp-server), steps 1 to 4. |
| A new checker rule | [The script checker](#the-script-checker), steps 1 to 4. |
| A safety rule | Every place that states it: `SKILL.md`, `AGENTS.md`, `agent/README.md`, `Instructions` in `climcp.pas`, the help texts, the two user pages, and its test. |

Anything a user would notice also gets its line in `CHANGELOG.md` and on
[What's new in Reforged](/reforged/whats-new/).

CI builds `EUOCli.lpi` with the other programs and runs all of the above through `run_tests.ps1`. A change
under `agent/` or to the generator also starts the Docs build check. A release puts `EUOCli.exe` and the
`agent` folder into the zip.
