# EasyUO Reforged agent pack

What an AI coding agent (Claude Code, Codex, Cursor, Gemini CLI, ...) needs to write and change
EasyUO scripts for you: the language rules, every command and `#variable`, and a reference page for
each, as plain markdown. Without it, agents invent commands that don't exist, and EasyUO runs such a
script without any error.

Full instructions: <https://ilpersi.github.io/EasyUOReforged/guide/agents/>

## Set it up

**In one step.** Open a terminal in the EasyUO Reforged folder (one level up from this one) and name
the folder where you keep your scripts:

```
EUOCli init C:\Games\UO\Scripts
```

It copies this pack there as a Claude Code skill, writes `AGENTS.md` for other agents, and adds the
`.mcp.json` entry that gives the agent EUOCli's tools. Run it again after an update. Then start your
agent in that folder. The rest of this section is the same by hand.

**Claude Code.** Copy the `euo-script` folder into your skills folder:

- for every project: `%USERPROFILE%\.claude\skills\euo-script`
- or for one script folder only: `<your scripts>\.claude\skills\euo-script`

Then ask for a script in plain words. Claude loads the skill when you mention EasyUO or a `.euo` file.

**Any other agent.** Copy `AGENTS.md` and the `euo-script` folder into the folder where you keep
your scripts, and start the agent there. Most agents read `AGENTS.md` by themselves; if yours
doesn't, tell it: "read AGENTS.md first".

**A chat without files.** Give it this address:
<https://ilpersi.github.io/EasyUOReforged/llms.txt>

## What is in it

| File | What it is |
|---|---|
| `AGENTS.md` | The instructions an agent reads first. |
| `euo-script/SKILL.md` | How to work on a script, step by step. Also the Claude Code skill. |
| `euo-script/language.md` | The language rules, and patterns that work. |
| `euo-script/commands.md` | Every command and sub-command on one line. |
| `euo-script/variables.md` | Every `#variable` on one line. |
| `euo-script/reference/` | One page per command, variable and guide: the documentation site as markdown. |
| `euo-script/reference.json` | The command and variable lists as data. |
| `euo-script/VERSION` | The EasyUO Reforged version the pack describes. |

The pack describes the version it came with. Replace it when you update EasyUO Reforged.

## Licence

The pack is part of EasyUO Reforged, under its BSD 2-Clause licence. The reference pages based on the
EasyUO wiki say so at their foot: that text is available under the GNU Free Documentation License
1.2, whose text is in `euo-script/LICENSE-GFDL-1.2.txt`.

## What the agent can and can't do

It writes, explains and changes scripts, and it uses `EUOCli.exe` (in the EasyUO Reforged folder,
one level up from this one) on them:

- `EUOCli check` reports what EasyUO would skip or misread.
- `EUOCli run` runs a script with **no UO client**: nothing happens in your game, and the agent
  sees whether the logic works.
- `EUOCli vars` reads variables from your client, such as where your character stands. It changes
  nothing.

Tell the agent where the EasyUO Reforged folder is, or it will ask. After `EUOCli init` it knows.

With the `.mcp.json` entry that `EUOCli init` writes, the agent gets the same as tools
(`EUOCli mcp`), and can also step through a script line by line, as you do in the editor.

The agent is told to run a script on your character (`EUOCli run --client 1`, or the tool
`euo_run_live`) only after you say yes to that script, and after telling you what it will do. Your
agent program also asks before it runs a command or uses a tool:

- In a command, look for `--client` and `--allow`. Without them a run can't touch the game or start
  anything on your computer.
- Of the tools, `euo_run` can do neither, so it is safe to allow for good. `euo_run_live` is the one
  that acts on your character: allow it one run at a time.

It can't see your game screen. Read a script before you let it run on your character, as with any
script you didn't write.
