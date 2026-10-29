---
title: "#BuffName"
description: "Title of the selected buff, as its tooltip shows it."
kind: variable
category: buffs
access: ro
type: string
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffIndex", "#BuffBarOpen", "#BuffDesc", "#BuffCliloc"]
aliases: ["buff name"]
---

`#BuffName` is the first line of the tooltip of the buff selected by [`#BuffIndex`](/variables/buffindex/),
for example `Bless`. The text comes from the client's own cliloc table, so it is in the client's language.
`~1_STR~`-style arguments are filled in, `<br>` becomes a space, other markup is dropped, and spaces become
`_` as in every string variable, so `str pos #BuffName Bless` works.

It also reads `N/A` for a buff without a title. Reads `N/A` when no buff is selected: the buff bar is closed or empty, the client's buff bar layout is not
supported, or the selected buff has left the bar since the last [`ScanBuffs`](/commands/scanbuffs/) or
`set #BuffIndex`.

## Example

```euo
scanbuffs
for %i 1 #BuffCnt
{
  set #BuffIndex %i
  event sysmessage #BuffName : #BuffDesc
}
halt
```
