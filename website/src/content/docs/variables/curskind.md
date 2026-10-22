---
title: "#CursKind"
description: "Returns the facet where the character is."
kind: variable
category: extended
access: ro
type: number
source: wiki
---

The #cursKind system variable determines the facet where the character is.

| Value | Description |
|-------|-------------|
| 0     | Felucca     |
| 1     | Trammel     |
| 2     | Ilshenar    |
| 3     | Malas       |
| 4     | Tokuno      |

#cursKind Values

## Example

```euo
msg Hmmm I wonder where I am$
if #cursKind = 0
     set %iamin Felucca
if #cursKind = 1
     set %iamin Trammel
if #cursKind = 2
     set %iamin Ilshenar
if #cursKind = 3
     set %iamin Malas
if #cursKind = 4
     set %iamin Tokuno
msg Oh Ok I am in %iamin $
halt
```
