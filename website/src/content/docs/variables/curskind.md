---
title: "#CursKind"
description: "Facet you are on: 0 Felucca, 1 Trammel, 2 Ilshenar, 3 Malas, 4 Tokuno, 5 Ter Mur."
kind: variable
category: extended
access: ro
type: number
needsClient: true
related: ["Tile", "#CharPosX"]
aliases: ["facet", "map"]
dll: CursKind
source: wiki
---

`#CursKind` is the facet your character is on:

| Value | Facet |
|---|---|
| 0 | Felucca |
| 1 | Trammel |
| 2 | Ilshenar |
| 3 | Malas |
| 4 | Tokuno |
| 5 | Ter Mur |

[`tile`](/commands/tile/) uses the same numbers.

## Example

```euo
if #CursKind = 0
  display ok Careful - this is Felucca.
halt
```
