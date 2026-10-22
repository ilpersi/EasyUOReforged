---
title: "GetJournal"
description: "Reads one journal line of the list `ScanJournal` made: 0 is the newest."
kind: dll-method
category: method
syntax: "Call GetJournal index"
needsClient: true
related: ["ScanJournal", "#Journal", "dll:ScanJournal"]
aliases: ["UO.GetJournal"]
---

Reads one journal line of the list `ScanJournal` made: 0 is the newest.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `index` | number | Position in the list, counting from 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `text` | string | The line. |
| `colour` | number | Its colour. |
