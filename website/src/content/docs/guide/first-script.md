---
title: Your first script
description: The EasyUO Reforged window, running and stopping a script, working with several clients, and settings worth knowing.
sidebar:
  order: 2
---

## The window

- **Tabs**: one open script per tab. Use *File → New* or *Open*, or drag a `.euo` file onto the window.
  The tabs of the last session come back when you start the app again.
- **Editor** (left and centre): a code editor with syntax highlighting and line numbers.
- **Variable inspector** (right): a tree of every built-in `#variable` grouped by category, plus your
  script's own `%variables`. The values refresh a few times a second while a script runs.
- **Title bar**: shows the version (`YY.MM.DD.<commit>`), also under *Help → About* and in
  [`#ReforgedVer`](/variables/reforgedver/).

## Run a script

1. Make sure the UO client is running and your character is logged in.
2. Paste a script into a tab. A minimal one:

   ```euo
   ; announce where the character is, then stop
   display OK Char is at #CharPosX , #SPC , #CharPosY
   halt
   ```

3. Press **F9** (*Control → Start*), or the Play button on the toolbar.
4. *Control → Pause*, *Stop* and *Stop All* (stops the scripts of every tab) control execution. The editor
   is read-only while a script runs.

If you get *"No supported UO client found!"*, the client isn't running, isn't logged in, or is a version
this build doesn't recognize yet.

New to the language itself? The [introduction](/guides/introduction/) and the
[beginner's tutorial](/guides/beginners-tutorial/) start from zero; the [Language](/language/variables/)
section is the full reference.

## Several clients

- *Tools → New Client* starts another UO client. You'll be asked where `client.exe` is the first time.
- *Tools → Swap To Next Client* changes which running client the active script drives. In a script,
  [`uoxl swap`](/commands/uoxl/) does the same, and [`#CliNr`](/variables/clinr/) tells which client is
  being driven.

## Settings worth knowing

- **Tools → Don't Move Cursor** is on by default: [`click`](/commands/click/) and target commands work
  without moving your real mouse pointer. Turn it off if a script needs the real cursor moved.
- **Tools → Manage VarList** chooses which variables the inspector shows.
- **Building a big [`menu`](/commands/menu/) window?** A script runs [`#LPC`](/variables/lpc/) lines
  (10 by default) and then pauses 50 ms, so a menu with a hundred controls takes about half a second to
  appear. Put `set #LPC 1000` before building it, and `set #LPC 10` once it is on screen if you want the
  normal pace back. Rebuilding a window that is already showing is drawn in one go.

Next: [debugging](/guide/debugging/).
