---
title: "Click"
description: "Clicks at `x`, `y` in the client window, like `click`."
kind: dll-method
category: method
syntax: "Call Click x y\nCall Click x y count\nCall Click x y count left\nCall Click x y count left down up\nCall Click x y left down up movecursor\nCall Click x y count left down up fast movecursor"
needsClient: true
related: ["Click"]
aliases: ["UO.Click"]
---

Clicks at `x`, `y` in the client window, like `click`. Defaults: 1 click, left button, press and release, with the 150 ms pause before each click, without moving the real cursor.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `count` | number | How many clicks. Default: 1. |
| `left` | boolean | True for the left button, false for the right. |
| `down` | boolean | Press the button. |
| `up` | boolean | Release the button. |
| `fast` | boolean | Skip the 150 ms pause before each click. |
| `movecursor` | boolean | Move the real mouse cursor there first. |

## Returns

Nothing.

:::note
The last form, `x y left down up movecursor`, is kept only for old programs: it always clicks once, fast.
:::
