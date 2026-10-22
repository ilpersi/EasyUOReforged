---
title: "#BuffDesc"
description: "Second line of the selected buff’s tooltip."
kind: variable
category: buffs
access: ro
type: string
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffIndex", "#BuffBarOpen", "#BuffName"]
aliases: ["buff description"]
---

`#BuffDesc` is the second line of the tooltip of the buff selected by [`#BuffIndex`](/variables/buffindex/):
usually what the buff does, such as the stat bonus. It is processed like [`#BuffName`](/variables/buffname/):
client language, arguments filled in, markup dropped, spaces as `_`.

It also reads `N/A` for a buff without a description. Reads `N/A` when no buff is selected: the buff bar is closed or empty, the client's buff bar layout is not
supported, or the selected buff has left the bar since the last [`ScanBuffs`](/commands/scanbuffs/) or
`set #BuffIndex`.
