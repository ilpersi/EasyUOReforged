---
title: "#JColor"
description: "Colour of the journal line read by the last scanjournal."
kind: variable
category: journal
access: ro
type: number
needsClient: true
related: ["#Journal", "ScanJournal", "FindJournal"]
aliases: ["journal colour"]
source: wiki
---

`#JColor` is the colour (hue) of the journal line read by the last [`scanjournal`](/commands/scanjournal/) or found
by the last [`findjournal`](/commands/findjournal/), which can also search by it. It tells apart lines with the same
text, such as system messages and speech.

It cannot be set.
