---
title: "BuffBarOpen"
description: "1 when the client’s buff bar window is open, 0 when it is closed."
kind: dll-property
category: property
syntax: "Get BuffBarOpen  \u2192  boolean"
needsClient: true
related: ["#BuffBarOpen"]
aliases: ["UO.BuffBarOpen"]
---

`BuffBarOpen` is a read-only property: the same value as [`#BuffBarOpen`](/variables/buffbaropen/), returned as a boolean.

1 when the client’s buff bar window is open, 0 when it is closed.

It is also false on a client whose buff bar cannot be read, where `#BuffBarOpen` reads `N/A`.
