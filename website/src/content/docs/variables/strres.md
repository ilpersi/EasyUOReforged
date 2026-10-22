---
title: "#StrRes"
description: "Returns the result of the last str command."
kind: variable
category: result
access: rw
type: string
source: wiki
---

Holds the value from the last [Str (command)](/commands/str/) statement executed.

## Example

```euo
finditem *
if #FINDCNT > 0
{
  event Property #findID
  str len #property
  display ok the length if the string in the property variable is , #spc , #strRes
}
halt
```
