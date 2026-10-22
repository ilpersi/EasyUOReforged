---
title: "#LObjectID"
description: "Returns the id of the last used object."
kind: variable
category: lastaction
access: rw
type: id
needsClient: true
source: wiki
---

The #lObjectID system variable contains the ID of the last used object. You can also write to this variable and use it in conjuction with [event Macro](/commands/event/macro/) 17 (LastObject), which will use the object as if it was double-clicked with the mouse.

:::note
This variable is UO client dependent. Setting #LOBJECTID in one instance of EasyUO will affect the variable as it is seen by all other instances of EasyUO bound to that client. It is recommended to sanitize the variable by saving the existing value before overwriting it, then restoring the original value when the function is complete.
:::

## Example

```euo
set #lObjectID %carpentryTool
event macro 17
; crafting menu is now open
...

set !_orig.lobjectid #LOBJECTID
set #LOBJECTID %BandageID
event macro 17
set #LOBJECTID !_orig.lobjectid
target 2s
...
```
