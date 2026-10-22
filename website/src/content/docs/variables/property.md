---
title: "#Property"
description: "Returns the result of the last event Property command."
kind: variable
category: result
access: ro
type: string
source: wiki
---

Holds the value from the last [event Property](/commands/event/property/) statement executed. Each line from a context menu in the client is delimited with a $ character, with denotes "new line". For example, a runebook will show up in game as:`

Runebook

Blessed

`in the #property variable, this would look like: RUNEBOOK$BLESSED

## Example

```euo
finditem *
if #FINDCNT > 0
{
  event Property #findID
  display ok #property
}
halt
```
