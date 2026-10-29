---
title: ScanBuffs
description: "Reads the client's buff bar into the #Buff… variables, optionally only one buff icon."
kind: command
category: client
syntax: scanbuffs [iconID]
origin: reforged
needsClient: true
sets: ['#BuffCnt', '#BuffIndex', '#BuffID', '#BuffCliloc', '#BuffName', '#BuffDesc', '#BuffTime']
related: ['#BuffBarOpen', '#BuffIndex', 'FindItem', 'ScanJournal', 'dll:ScanBuffs', 'dll:GetBuff']
dll: ScanBuffs
aliases: ['buff bar', 'buffs', 'bless', 'curse', 'buff timer']
---

`ScanBuffs` reads the buffs and debuffs shown in the client's buff bar. Like
[`FindItem`](/commands/finditem/), it takes a snapshot, selects the first entry and says how many
there are in [`#BuffCnt`](/variables/buffcnt/). Set [`#BuffIndex`](/variables/buffindex/) (1-based) to walk through the rest, the way
[`#FindIndex`](/variables/findindex/) walks `FindItem`'s results.

`ScanBuffs` only **reads** client memory. It writes nothing and patches nothing, so it cannot
disturb the client.

## Parameters

| Parameter | Meaning |
|---|---|
| `iconID` | Optional. Keep only the buffs with this icon ID, a plain number. Bless is `30018` (`$7542`). |

## Reading the results

For the selected buff:

| Variable | Value |
|---|---|
| [`#BuffID`](/variables/buffid/) | Icon ID, a plain number. |
| [`#BuffCliloc`](/variables/buffcliloc/) | Cliloc number of the buff's title. |
| [`#BuffName`](/variables/buffname/) | First line of the tooltip, e.g. `Bless`. |
| [`#BuffDesc`](/variables/buffdesc/) | Second line of the tooltip. |
| [`#BuffTime`](/variables/bufftime/) | Seconds left, as the tooltip shows them. `-1` means the buff has no timer (Hiding, for one). |

`#BuffCnt` is the number of buffs, and [`#BuffBarOpen`](/variables/buffbaropen/) tells whether the buff bar window is open at all.

## Examples

List every active buff in the journal:

```euo
scanbuffs
for %i 1 #BuffCnt
{
  set #BuffIndex %i
  event sysmessage #BuffName : #BuffTime s
}
halt
```

Recast Bless when it is about to run out:

```euo
scanbuffs 30018
if #BuffCnt = 0 || #BuffTime < 10
  display ok Time to recast Bless.
halt
```

Tell a closed buff bar from an empty one:

```euo
scanbuffs
if #BuffBarOpen = 0
  display ok Open the buff bar first.
halt
```

## Notes

- **The buff bar window must be open.** The data lives in the client's `BuffIcons` gump. With the
  window closed, `#BuffCnt` is `0` and the other variables read `N/A`. The same `N/A` appears for
  a buff that has no tooltip text.
- **Texts come from the client's own cliloc table**, so they are in the client's language.
  `~1_STR~` arguments are filled in, `<br>` becomes a space and other markup is dropped. Spaces
  become `_`, as in every string variable, so `str pos #BuffName Bless` works.
- **`#BuffTime` updates in coarse steps** (about every 5 seconds), because that is how often the
  client refreshes the tooltip. A buff whose timer the client no longer knows shows `0`.
- **The variables follow the client live.** The selected buff is found again by its icon ID when
  other buffs come and go. Once it leaves the bar, `#BuffID`, `#BuffCliloc`, `#BuffName`,
  `#BuffDesc`, `#BuffTime` and `#BuffIndex` read `N/A` until the next `ScanBuffs` or
  `set #BuffIndex`. `#BuffCnt` is always the live count. Inside a loop over `#BuffIndex`,
  positions can shift if a buff ends meanwhile: run `ScanBuffs` again if you need a fixed list.

## Reforged notes

`ScanBuffs` and all `#Buff…` variables are new in EasyUO Reforged. No existing command, variable
or script changes meaning because of them.

It works on clients whose buff bar layout has been verified: the 7.0.117.1 beta
(`client_beta.exe`) and the fixed-base clients (checked on 7.0.117.1 and on a 2013 client). On
any other client the command does nothing and the variables read `N/A`, so it never reads garbage
from an unverified layout.
