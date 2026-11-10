# EasyUO Reforged agent pack

What an AI coding agent (Claude Code, Codex, Cursor, Gemini CLI, ...) needs to write and change
EasyUO scripts for you: the language rules, every command and `#variable`, and a reference page for
each, as plain markdown. Without it, agents invent commands that don't exist, and EasyUO runs such a
script without any error.

Full instructions: <https://ilpersi.github.io/EasyUOReforged/guide/agents/>

## Set it up

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

It writes, explains and changes scripts. It can't run them or see your game yet: you run the script
in EasyUO Reforged and tell the agent what happened. Read a script before you run it, as with any
script you didn't write.
