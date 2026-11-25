---
title: ScanGumps
description: "Lists every gump window open in the client, front to back, into the #Gump… variables."
kind: command
category: client
syntax: scangumps [T_typeIDs] [A_artIDs]
origin: reforged
needsClient: true
sets: ['#GumpCnt', '#GumpIndex', '#GumpName', '#GumpKind', '#GumpPosX', '#GumpPosY', '#GumpSizeX', '#GumpSizeY', '#GumpArt', '#GumpMin', '#GumpObjID', '#GumpSerial', '#GumpTypeID']
related: ['#GumpIndex', '#GumpTypeID', '#ContKind', 'event ContTop', 'ScanBuffs', 'FindItem', 'dll:ScanGumps', 'dll:GetGump']
dll: ScanGumps
aliases: ['gump list', 'gumps', 'windows', 'server gump', 'open gumps']
---

`ScanGumps` lists the gump windows open in the client: the backpack and other containers, the
paperdoll, the status bar, the skills window, and the gumps the server sends (menus, confirmations,
quest windows). Like [`FindItem`](/commands/finditem/), it takes a snapshot, selects the first
entry and puts the number of entries in [`#GumpCnt`](/variables/gumpcnt/). Set
[`#GumpIndex`](/variables/gumpindex/) (1-based) to walk through the rest.

The `#Cont…` variables describe only the gump on top. `ScanGumps` describes every one.

`ScanGumps` only **reads** client memory. It writes nothing, so it cannot disturb the client.

## Parameters

Both are optional and work like [`FindItem`](/commands/finditem/)'s filters. Each value is an ID in
the usual EUO format, and several values are joined with `_`.

| Parameter | Meaning |
|---|---|
| `T_typeIDs` | Keep only the server gumps with one of these type IDs: `T_JHEIIPI`, or `T_JHEIIPI_ABCDEF` for two. |
| `A_artIDs` | Keep only the gumps with one of these graphics: `A_YE` is the backpack. |

With both, a gump must match both. A server gump has no graphic, so `T_` and `A_` together find
nothing.

## Reading the results

For the selected gump:

| Variable | Value |
|---|---|
| [`#GumpName`](/variables/gumpname/) | The client's own name for the window, e.g. `container_gump`, `generic_gump`. |
| [`#GumpKind`](/variables/gumpkind/) | The same code as [`#ContKind`](/variables/contkind/). |
| [`#GumpPosX`](/variables/gumpposx/), [`#GumpPosY`](/variables/gumpposy/) | Position of the window, as `#ContPosX` / `#ContPosY`. |
| [`#GumpSizeX`](/variables/gumpsizex/), [`#GumpSizeY`](/variables/gumpsizey/) | Size of the window, as `#ContSizeX` / `#ContSizeY`. |
| [`#GumpArt`](/variables/gumpart/) | The window's graphic: `YE` for the backpack. |
| [`#GumpMin`](/variables/gumpmin/) | `#true` when the window is minimized, `#false` otherwise. |
| [`#GumpObjID`](/variables/gumpobjid/) | The object the window belongs to: the container, or the character of a paperdoll or status bar. |
| [`#GumpSerial`](/variables/gumpserial/) | Server gumps only: the serial the server gave this copy of the window. |
| [`#GumpTypeID`](/variables/gumptypeid/) | Server gumps only: which gump it is. |

## Examples

List every open window in the journal:

```euo
scangumps
for #GumpIndex 1 #GumpCnt
  event sysmessage #GumpName #GumpArt
halt
```

Wait until the server opens a gump you know, then tell where it is:

```euo
set %quest JHEIIPI      ; #GumpTypeID of that gump, read once by hand
repeat
  scangumps T_ , %quest
  wait 5
until #GumpCnt > 0
event sysmessage Quest window at #GumpPosX #GumpPosY
halt
```

Is the backpack open?

```euo
scangumps A_YE
if #GumpCnt > 0 && #GumpObjID = #BackpackID
  event sysmessage The backpack is open.
halt
```

## Notes

- **Only windows are listed, front to back.** Entry 1 is the window in front, usually the one opened,
  clicked or moved last; `client_beta.exe` keeps its menu bar in front of everything, as entry 1. Buttons, texts and other pieces inside a window are not entries.
- **Match server gumps on [`#GumpTypeID`](/variables/gumptypeid/).** It is the same every time the
  server opens the same gump. [`#GumpSerial`](/variables/gumpserial/) changes every time.
  [`#GumpKind`](/variables/gumpkind/) changes with every client update, so don't keep it in a
  script for long: use the type ID, the graphic or the name.
- **Formats.** IDs, the graphic and the kind are in the usual EUO format, like
  [`#ContID`](/variables/contid/). Positions and sizes are plain numbers. `#GumpMin` is `#true` or
  `#false`.
- **`N/A`** means the value is not there: no gump is selected (none open, or `#GumpIndex` past
  `#GumpCnt`); the window has no graphic (server gumps) or belongs to no object; `#GumpSerial`
  and `#GumpTypeID` of a window that is not a server gump; or the value is not known on this
  client build.
- **It is a snapshot.** The values are read when `ScanGumps` runs. A window that moves or closes
  afterwards keeps its old values until the next `ScanGumps`.
- **Bringing a window to the front.** [`event ContTop`](/commands/event/conttop/) does it, but counts
  from `0` and skips the [`IgnoreCont`](/commands/ignorecont/) gumps, which `ScanGumps` lists: see
  [Bring a gump to the front](/guides/patterns/#bring-a-gump-to-the-front) for how to turn
  `#GumpIndex` into its number.

## Reforged notes

`ScanGumps` and the `#Gump…` variables are new in EasyUO Reforged. Old EasyUO skips the line and
reads the variables as `N/A`. No existing command, variable or script changes meaning because of
them.

The graphic, the minimized flag, the serial and the type ID are read from the client build's own
table. They are known for client 7.0.29.97 and newer, and for the relocatable `client_beta.exe`.
On older clients those four variables read `N/A`, and the others still work. The serial and type
ID also read `N/A` on the builds from 7.0.30 to 7.0.46, where they are has not been checked.
