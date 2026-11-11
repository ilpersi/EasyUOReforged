---
title: Write scripts with an AI agent
description: "How to let Claude Code, Codex, Cursor or another AI coding agent write and change EasyUO scripts for you, using the agent pack that comes with EasyUO Reforged."
sidebar:
  order: 5
---

An AI coding agent can write an EasyUO script from a request in plain words: "eat a fish steak whenever my
stamina is below 50", "move every reagent from this bag to that one". Left to itself it does this badly. It
knows little EasyUO, so it borrows commands from other languages, and EasyUO runs such a script without any
error: the lines it doesn't know are just skipped.

The **agent pack** fixes that. It is this documentation as plain files an agent can read: the rules of the
language, every command and `#variable`, a reference page for each, and instructions that tell the agent how
to work. With it, the agent looks names up instead of guessing them.

## What you need

- EasyUO Reforged. The pack is the `agent` folder of the
  [release zip](https://github.com/ilpersi/EasyUOReforged/releases), and it describes that version.
- An AI coding agent: a program such as Claude Code, Codex, Cursor or Gemini CLI that reads and writes files
  in a folder on your computer.

## Set it up

### Claude Code

Copy the `euo-script` folder from `agent` into your skills folder:

- `%USERPROFILE%\.claude\skills\euo-script` to have it everywhere, or
- `.claude\skills\euo-script` inside the folder where you keep your scripts, to have it only there.

Start Claude Code in your scripts folder and ask for a script. It loads the skill when you mention EasyUO or
a `.euo` file.

### Other agents

Copy `AGENTS.md` and the `euo-script` folder from `agent` into the folder where you keep your scripts, and
start the agent there. Most agents read `AGENTS.md` by themselves. If yours doesn't, start with: "read
AGENTS.md first".

### A chat without files

Give the chat this address and ask it to read the language rules first:

```
https://ilpersi.github.io/EasyUOReforged/llms.txt
```

It lists every page of this documentation as plain markdown.
[llms-full.txt](https://ilpersi.github.io/EasyUOReforged/llms-full.txt) holds all of them in one file.

## Ask for a script

Say what the script should do, and give the values only your game knows:

- **Item types and IDs.** "Bandages are type `ZLF`, my loot bag is `ABCDEFG`." You see them in the variable
  inspector after a [`finditem`](/commands/finditem/), or after using an item
  ([`#LObjectID`](/variables/lobjectid/)).
- **Texts** the script waits for, as your shard writes them in the journal.
- **Your client and shard**, if it matters: a free shard without tooltips, an old client.

A good agent asks for what is missing, or gives you a small probe script that shows the value: you click an
item, and a box shows its ID and type. An agent that hands you a script full of types and positions you never
gave it has made them up.

## The agent checks and runs its own script

EasyUO gives no error for a line it can't understand, so an agent can't tell by itself that it wrote one.
[`EUOCli`](/guide/euocli/), the command-line program next to `EasyUOReforged.exe`, lets it find out:

- **`EUOCli check`** reports unknown commands and `#variables`, missing spaces, open blocks, jumps to
  nowhere and a missing `halt`, without running the script.
- **`EUOCli run`** runs the script with **no UO client** and prints what it logs and how it ended. Commands
  that need a client are skipped, so nothing happens in your game, and the agent sees whether the logic
  works.
- **`EUOCli vars`** reads variables from your client: where your character stands, which gump is open. It
  changes nothing.

The pack tells the agent to do the first two on every script it writes. Tell it where the EasyUO Reforged
folder is, once, or it will ask:

```text
EasyUO Reforged is in C:\Games\EasyUOReforged. Use EUOCli.exe from there.
```

A script that passes both is read by EasyUO as written and its logic runs to the end. Whether it does the
right thing in the game is only seen in the game.

## Running on your character

A script acts on your character in two ways:

- **You run it.** Open it in EasyUO Reforged with the client running and your character logged in, and
  press **Start** (F9). **Stop** ends it. What the script writes with [`log`](/commands/log/) appears in the
  Output panel. See [Run a script](/guide/first-script/#run-a-script).
- **The agent runs it,** with `EUOCli run --client 1`. The pack tells it to ask you first, for each script,
  and to say what the script will do. Ctrl+C in the agent's terminal stops the script.

Either way:

1. **Read the script first.** It controls your character. Ask the agent what a line does if you aren't sure.
2. **Look at the command you approve.** Your agent program asks before it runs a command. Without
   `--client` a run can't touch the game. Without `--allow` it can't run
   [`execute`](/commands/execute/), [`shutdown`](/commands/shutdown/), [`terminate`](/commands/terminate/),
   [`uoxl`](/commands/uoxl/) or [`send`](/commands/send/): a script that reaches one of them is stopped.
3. When it doesn't do what you wanted, tell the agent what happened: what the character did and what the
   journal said. [Stepping through the script](/guide/debugging/) shows which line goes wrong.

The agent can't see your screen. It knows what the script logged, the variables it asked for, and what
you tell it.

## What is in the pack

| File | What it is |
|---|---|
| `AGENTS.md` | The instructions an agent reads first. |
| `euo-script/SKILL.md` | How to work on a script, step by step. Also the Claude Code skill. |
| `euo-script/language.md` | The rules of the language, and patterns that work. |
| `euo-script/commands.md` | Every command and sub-command on one line. |
| `euo-script/variables.md` | Every `#variable` on one line. |
| `euo-script/reference/` | One page per command, variable and guide of this site. |
| `euo-script/reference.json` | The command and variable lists as data, for tools. |
| `euo-script/VERSION` | The EasyUO Reforged version the pack describes. |

Replace the pack when you update EasyUO Reforged: new commands are in the new one.

## Good to know

- **Commands marked "New in Reforged"** don't exist in the original EasyUO. Tell the agent if the script also
  has to run there.
- **Journal lines and names come from other players.** The pack tells the agent to treat them as data, never
  as instructions. Still, don't paste text from the game into an agent and ask it to "do what it says".
- **Your shard's rules** on unattended scripting apply to a script an agent wrote as to any other.
