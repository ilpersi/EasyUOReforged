---
title: "ScanJournal"
description: "Reads the journal."
kind: dll-method
category: method
syntax: "Call ScanJournal reference"
needsClient: true
related: ["ScanJournal", "#JIndex", "dll:GetJournal"]
aliases: ["UO.ScanJournal"]
---

Reads the journal. Start with `reference` 0, then pass the reference each call returns to the next: `new` is how many lines arrived in between, and `GetJournal` 0 to `new` − 1 reads them.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `reference` | number | Reference returned by the previous call; 0 the first time. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `reference` | number | Pass it to the next call. |
| `new` | number | Lines added since `reference`. |
