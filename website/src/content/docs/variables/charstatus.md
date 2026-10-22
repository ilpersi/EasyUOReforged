---
title: "#CharStatus"
description: "Returns different states that the character can be in."
kind: variable
category: character
access: ro
type: string
needsClient: true
source: wiki
---

Determines different states that the character can be in.

| Value | Description |
|----|----|
| C | Character is poisoned. |
| H | Character is hidden. |
| B | Character is female. |
| G | Character is in war mode. |
| D | Character is affected with lethal strike. |
| A | Character is frozen (actively casting a spell / Waiting for transport after using help-menu) . |

Table of #charStatus values

## Example

```euo
...
if C in #charStatus
{
    gosub cureMe
}

...

sub cureMe
    ...
    return
```
