---
title: "#LObjectID"
description: "ID of the last object used; set it, then event Macro 17 uses that object."
kind: variable
category: lastaction
access: rw
type: id
needsClient: true
related: ["#LObjectType", "event Macro", "#LTargetID"]
aliases: ["last object", "use object"]
source: wiki
---

`#LObjectID` is the ID of the object you used last (double-clicked). Set it and run
[`event Macro 17`](/commands/event/macro/) (*Last Object*) to use any object as if you had double-clicked it.

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.

## Example

```euo
set %old #LObjectID
set #LObjectID %bandages
event Macro 17 0
target 2s
set #LObjectID %old
```
