---
title: "#LTargetTile"
description: "Map graphic of the tile last targeted; used for resources such as trees."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
related: ["#LTargetKind", "#LTargetX", "Tile"]
aliases: ["tree", "resource tile"]
dll: LTargetTile
source: wiki
---

`#LTargetTile` is the graphic number of the map tile you targeted last, for example the tree you chopped.
With [`#LTargetKind`](/variables/ltargetkind/) `3`, [`event Macro 22`](/commands/event/macro/) targets that tile
at [`#LTargetX`](/variables/ltargetx/), [`#LTargetY`](/variables/ltargety/), [`#LTargetZ`](/variables/ltargetz/).
[`tile`](/commands/tile/) reads tile graphics from the map.

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.
