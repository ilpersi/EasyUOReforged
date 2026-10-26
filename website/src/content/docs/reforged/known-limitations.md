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
- **[`Path`](/commands/path/)** knows the map files everywhere, but player houses, items players placed,
  doors and creatures only where your client holds them, around the character. A long route can lead into
  a house farther away; the walker goes round it once it gets near.
  - It reads the walls and floors of player houses only on `client_beta.exe` 7.0.117.31. On other clients
    the walker finds a house when its steps are refused, which is slower.
  - The walker doesn't go into player houses unless told to ([`path set doors all`](/commands/path/set/)).
    Inside a house, the server can refuse tiles the client shows as free.
  - A link to another facet (a moongate) is not followed: the walk stops there.
  - Client mode ([`path set mode client`](/commands/path/set/)) is not the default: on `client_beta.exe` the
    client's own walk keeps ending early or taking its own way, and once left
    [`#CharPosX`](/variables/charposx/) a few tiles off until the next login. There,
    [`path stop`](/commands/path/stop/) also can't stop the client's walk to the last point it was sent to.
  - Walking has been checked by hand on `client_beta.exe` only; `path find` and `path can` also on
    `client.exe`.
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
