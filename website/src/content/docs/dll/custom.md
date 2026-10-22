---
title: "Custom"
description: "Sends a raw packet to the server: `packet` holds its bytes, exactly as the server expects them."
kind: dll-method
category: method
syntax: "Call Custom packet"
needsClient: true
related: ["dll:Equip"]
aliases: ["UO.Custom"]
---

Sends a raw packet to the server: `packet` holds its bytes, exactly as the server expects them.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `packet` | string | The packet's bytes. |

## Returns

Nothing.

:::note
A malformed packet can get you disconnected. Only for people who know the UO protocol.
:::
