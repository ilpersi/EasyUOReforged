---
title: "ScanBuffs"
description: "Reads the buff bar, like `scanbuffs`; with `icon`, only buffs with that icon ID."
kind: dll-method
category: method
syntax: "Call ScanBuffs\nCall ScanBuffs icon"
needsClient: true
related: ["ScanBuffs", "dll:GetBuff", "dll:BuffBarOpen"]
aliases: ["UO.ScanBuffs"]
---

Reads the buff bar, like `scanbuffs`; with `icon`, only buffs with that icon ID. Read them with `GetBuff`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `icon` | number | Buff icon ID. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `count` | number | How many buffs. |
