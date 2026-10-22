---
title: "#LTargetZ"
description: "World height of the last target; used when targeting the ground or a resource."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
related: ["#LTargetKind", "#LTargetX", "#LTargetTile"]
aliases: ["target position"]
dll: LTargetZ
source: wiki
---

`#LTargetZ` is the world height of the spot you targeted last. With [`#LTargetKind`](/variables/ltargetkind/)
`2` or `3`, [`event Macro 22`](/commands/event/macro/) targets the position in `#LTargetX`, `#LTargetY` and
`#LTargetZ`. See `#LTargetKind` for an example.

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.
