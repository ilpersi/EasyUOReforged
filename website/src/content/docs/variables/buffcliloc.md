---
title: "#BuffCliloc"
description: "Cliloc number of the selected buff’s title."
kind: variable
category: buffs
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffIndex", "#BuffBarOpen", "#BuffName"]
aliases: ["buff cliloc"]
---

`#BuffCliloc` is the number of the client's localized text (cliloc) that names the buff selected by
[`#BuffIndex`](/variables/buffindex/). Unlike [`#BuffName`](/variables/buffname/), it is the same in every
client language, so it is the safer value to compare in a script you share.

Reads `N/A` when no buff is selected: the buff bar is closed or empty, the client's buff bar layout is not
supported, or the selected buff has left the bar since the last [`ScanBuffs`](/commands/scanbuffs/) or
`set #BuffIndex`.
