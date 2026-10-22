---
title: "event Property"
description: "Reads the property description of an item."
kind: subcommand
category: event
syntax: "event Property {ID}"
needsClient: true
source: wiki
---

The event Property command reads the description and properies of an item and places the information in the system variable #property. Each line in the #property variable is seperated by '$'.

Note: event Property doesn't work for pre-AoS (Age of Shadow) freeshards.

## Example

```euo
; This will use the item returned by the findItem command and save
; the information displayed in game by the property pop-up widow
; into the #property variable.
findItem ABC
event Property #findID
```
