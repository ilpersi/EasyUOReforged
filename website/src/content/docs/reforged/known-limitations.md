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
- [`menu`](/commands/menu/) windows of the EasyUO 1.5 MENU system: text, buttons, checkboxes, edit fields
  and images.
- The editor.

**Treat anything not listed as unverified**, and keep the original EasyUO next to it if you rely on
EasyUO for anything important, until you have checked that the scripts and features you need work.

## Known gaps

- **[`ScanProps`](/commands/scanprops/)** puts the tooltip text together itself, from the client's cache, the way
  `client.exe` 7.0.108.0 and newer and the betas do. Its text can differ from `event property`'s in three cases:
  words the client's swear filter would mask in player-written text show unmasked; a non-English client set to
  show English tooltips gives the client language's text; and older clients (7.0.29.97 and 7.0.45.89, for one,
  don't capitalise a word after `>`) can show small differences.
- **`event property`** leaves two small text buffers in the client's memory each time it runs, as in EasyUO 1.5:
  the client function it calls makes new copies of the name and property text, and nothing frees them. Many
  thousands of calls add up to megabytes. [`ScanProps`](/commands/scanprops/) makes no such copies.
- **Client versions.** EasyUO Reforged knows the classic client (`client.exe`) from 2.0.0 up to 7.0.117.1,
  and four builds of `client_beta.exe` (7.0.117.1, 7.0.117.31, 7.0.118.132 and 7.0.119.0). A newer client needs its memory offsets
  added first; see [Add a new client](/developers/adding-a-client/).
- **[`Path`](/commands/path/)** knows the map files everywhere, but player houses, items players placed,
  doors and creatures only where your client holds them, around the character. A long route can lead into
  a house farther away; the walker goes round it once it gets near.
  - It reads the walls and floors of player houses on `client.exe` 7.0.117.1 and `client_beta.exe`
    7.0.117.31, within about 18 tiles of the character, where the client keeps them. Another build gets this
    when its signature scan finds where that build keeps them. Where it can't, the walker learns a house from
    the client itself ([`path check`](/commands/path/check/)) once it is within 12 tiles: a route planned
    from farther away can still lead toward it.
  - A tile the client hasn't loaded reads as refused to [`path check`](/commands/path/check/), which is why
    the walker only asks about the next 12 tiles.
  - The walker doesn't go into player houses unless told to ([`path set doors all`](/commands/path/set/)).
    Inside a house, the server can refuse tiles the client shows as free. On a build where it can't read
    house pieces, it can't tell a house's door from any other door, but it learns the floor behind it from
    the client once the character is within 12 tiles, so routes still go round the house.
  - A link to another facet (a moongate) is not followed: the walk stops there.
  - Client mode ([`path set mode client`](/commands/path/set/)) is not the default: on `client_beta.exe` the
    client's own walk keeps ending early or taking its own way, and once left
    [`#CharPosX`](/variables/charposx/) a few tiles off until the next login. There,
    [`path stop`](/commands/path/stop/) also can't stop the client's walk to the last point it was sent to.
  - Walking has been checked by hand mostly on `client_beta.exe`. On `client.exe`: `path find`, `path can`,
    `path check`, and one walk round a player house.
  - Whether the character walks or runs is up to the client: it runs while Always Run is on, and also
    whenever your mouse pointer rests away from the character. It reads the real pointer itself, so a script
    can only steer that by moving your mouse (see [Running](/commands/path/#running)).
- **[`#MountID`](/variables/mountid/), [`#MountType`](/variables/mounttype/) and
  [`#FindLayer`](/variables/findlayer/)** read the equip layer where `client.exe` 7.0.117.1 and 7.0.108.0
  and `client_beta.exe` keep it (read from their code; checked live on `client.exe` 7.0.117.1 and
  `client_beta.exe` 7.0.117.31). On older clients they are unverified.
- **[`MoveItem`](/commands/moveitem/)** was checked on a ModernUO shard with `client.exe` 7.0.118.46. A server
  outside the RunUO family that gives the picked-up part of a stack a new ID can report `left` where a drop was
  refused. Once, `client.exe` 7.0.118.46 crashed right after the server refused a pick-up sent the way
  `moveitem` and [`exevent Drag`](/commands/exevent/drag/) send it. Eleven more refused pick-ups did not crash
  it, and the cause is unknown. If it happens to you, please report it.
- **[`ScanGumps`](/commands/scangumps/)** reads [`#GumpArt`](/variables/gumpart/), [`#GumpMin`](/variables/gumpmin/),
  [`#GumpSerial`](/variables/gumpserial/) and [`#GumpTypeID`](/variables/gumptypeid/) on `client.exe` 7.0.29.97 and
  newer and on `client_beta.exe`; on older clients, and for the serial and type ID on 7.0.30 to 7.0.46, they read
  `N/A`. The list itself needs the client's gump list address: on 5.0.4a the tables have none, so `ScanGumps` finds
  nothing, and on 4.0.11c the address they give is wrong, so it finds nothing either.
- **[`exevent GumpReply`](/commands/exevent/gumpreply/)** was checked on a ModernUO shard. It closes the
  client's window the way a click does, even when the server did not accept the button; on most ModernUO gumps
  that copy then stays unanswered on the server until you log out, which does no harm. Recording your own
  clicks ([`#GumpReplyCnt`](/variables/gumpreplycnt/)) puts a small hook into the client's send function; it was
  checked on `client.exe` 7.0.118.46 and `client_beta.exe` 7.0.118.132 and 7.0.119.0, and on another build it stays
  off when the function does not start the way it expects. The editor puts it in as soon as it finds the client,
  whether or not a script uses it. A click made before that, or without the editor (under `EUOCli`) before a
  script first read [`#GumpReply`](/variables/gumpreply/) or `#GumpReplyCnt`, is not recorded.
- **Symbol fonts in menus.** A [`menu`](/commands/menu/) text, button or checkbox using a symbol font such
  as Wingdings only shows the intended glyphs if that exact font is installed. Otherwise Windows substitutes
  another font, as the original did.
- **[`menu Image File`](/commands/menu/image/file/)** reliably loads BMP, PNG, JPEG and GIF. Older formats
  the original accepted (WMF, EMF, ICO) may not work.
- **[The MENU Designer](/designer/)** reads only the `menu` lines of a script, and leaves out those with
  variables and what a running script reads; it designs for the 1.6 MENU system only. See its
  [Limitations](/designer/limitations/).
- **EasyUO 1.6's `menu`.** The [1.6 MENU logic](/commands/menu/versions/) is checked automatically against
  what EasyUO 1.6.0.337 did in 23 recorded test scripts, and by hand in the editor with test scripts and an
  example from the ScriptUO tutorial on the 1.6 menu. It has not yet been tried with real 1.6 scripts that
  play the game.
  - A script runs under one MENU system from start to end, with the files it calls. Reforged picks it from the
    script's text when it starts: a 1.6 sub-command that only a variable or a called file supplies is not
    seen, unless the script sets [`menu Reforge Mode`](/commands/menu/reforge/mode/) (or, for called files,
    [`menu Reforge IncludeCall`](/commands/menu/reforge/includecall/)).
  - Where EasyUO 1.6 crashed or wrote into the wrong control, Reforged does nothing instead: `menu Image`
    drawing commands on a control that is not an image, and [`menu Show`](/commands/menu/show/),
    [`menu Hide`](/commands/menu/hide/) or `menu Window` after the name `form0` was given to another control.
    It also never moves a control into itself or into one of its own children, and
    [`menu Activate`](/commands/menu/activate/) skips a control that cannot take the focus.
  - A [`menu Panel`](/commands/menu/panel/) created with a negative size reads back 0, not the number given.
  - [`menu Image File`](/commands/menu/image/file/) draws the whole picture; EasyUO 1.6 lost a bitmap's last
    column.
  - While a script rebuilds a menu window that is shown, the 1.5 logic holds back repainting until it is done;
    the 1.6 logic does not, so the window may flicker.
- **64-bit Windows only.** EasyUO Reforged itself is 64-bit; it still drives the usual 32-bit UO client.
- **`uo.dll`**, the API for external programs, has only been tested by a small Python script (ctypes) on
  `client.exe` 7.0.117.1. It selected the client, read variables, and planned and checked with the
  [`GetPath`](/dll/getpath/), [`PathCan`](/dll/pathcan/) and [`PathCheck`](/dll/pathcheck/) methods. The rest
  of its methods have not been tried from an external program.
- **EUOUpdater**, the tool for new client versions, has had only light testing.
- **[`send`](/commands/send/)**'s `get`, `post`, `put`, `delete` and `download` use the proxy set for Windows'
  web service (`netsh winhttp set proxy`), not the browser's. Their `https` is tested by hand on public sites
  only. The original `send httppost` can't reach a server that only answers `https`.

Expect bugs in less common commands and menu features, and please
[report them](/guide/troubleshooting/#reporting-a-bug).
