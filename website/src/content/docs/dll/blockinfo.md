---
title: "BlockInfo"
description: "Reads the client's walkability data for an area of up to 32×32 tiles starting at `x`, `y`, `z`."
kind: dll-method
category: method
syntax: "Call BlockInfo x y z width height"
needsClient: true
related: ["event PathFind", "path check"]
aliases: ["UO.BlockInfo"]
---

Reads the client's walkability data for an area of up to 32×32 tiles starting at `x`, `y`, `z`. For each tile it runs the check the client makes before every step: can a character standing at height `z` on the tile south of it step north onto it? The answer is the height it would land at, or -128 (`$FF80`) when it can't. The client answers from everything it has loaded (house walls and floors included); a tile it hasn't loaded reads as -128. On a client whose function address is unknown, every byte is 0.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |
| `width` | number | Width in tiles. |
| `height` | number | Height in tiles. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `data` | string | Two bytes per tile, `width × height × 2` bytes in all: row by row from `x`, `y`, each a signed 16-bit number, low byte first. |

:::note
EasyUO 1.5 passed the client's function five arguments, but `client.exe` 7.0.117.1 takes six: the sixth points at a byte it writes. Given five, the client wrote that byte to an address near 0, which crashes it. EasyUO Reforged passes the sixth. The script command [`path check`](/commands/path/check/) asks the same of the client one step at a time, from any height and in any direction.
:::
