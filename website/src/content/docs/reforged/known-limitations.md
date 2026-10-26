---
title: Known limitations
description: What is verified, what is not, and the known gaps of EasyUO Reforged.
sidebar:
  order: 2
---

EasyUO Reforged is a working, actively tested port, **not a finished release**. It is based on the last
public EasyUO source, which its author described as deprecated, so some features may be missing.

## What is verified

The interpreter core, the client data tables and the other logic that does not need a game client are
covered by automated tests. Anything that needs a running client is verified by hand, and only as far as
testing has reached. Confirmed against a live client so far:

- Detecting and attaching to a running client.
- Script execution: the interpreter, variables, flow control.
- [`FindItem`](/commands/finditem/) and the related item commands.
- The variable inspector and VarDump.
- [`menu`](/commands/menu/) windows: text, buttons, checkboxes, edit fields and images.
- The editor.

**Treat anything not listed as unverified**, and keep the original EasyUO next to it if you rely on
EasyUO for anything important, until you have checked that the scripts and features you need work.

## Known gaps

- **Client versions.** EasyUO Reforged knows the classic client (`client.exe`) from 2.0.0 up to 7.0.117.1,
  and two builds of `client_beta.exe` (7.0.117.1 and 7.0.117.31). A newer client needs its memory offsets
  added first; see [Add a new client](/developers/adding-a-client/).
- **[`Path`](/commands/path/) plans, it doesn't walk**, and it only knows the map files: player houses,
  items players placed, doors and creatures are not on its map. Walking a route, and seeing those, comes
  later; until then a script walks a planned route with [`event PathFind`](/commands/event/pathfind/). On a
  live client, `path find` has only been checked by hand so far.
- **Symbol fonts in menus.** A [`menu`](/commands/menu/) text, button or checkbox using a symbol font such
  as Wingdings only shows the intended glyphs if that exact font is installed. Otherwise Windows substitutes
  another font, as the original did.
- **[`menu Image File`](/commands/menu/image/file/)** reliably loads BMP, PNG, JPEG and GIF. Older formats
  the original accepted (WMF, EMF, ICO) may not work.
- **64-bit Windows only.** EasyUO Reforged itself is 64-bit; it still drives the usual 32-bit UO client.
- **`uo.dll`**, the API for external programs, is built but has not been tested by a real external program
  yet.
- **EUOUpdater**, the tool for new client versions, has had only light testing.

Expect bugs in less common commands and menu features, and please
[report them](/guide/troubleshooting/#reporting-a-bug).
