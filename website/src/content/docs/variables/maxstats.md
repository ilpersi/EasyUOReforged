---
title: "#MaxStats"
description: "Your character’s stat cap: the most strength, dexterity and intelligence together."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Str", "#Dex", "#Int", "exevent StatLock"]
aliases: ["stat cap"]
dll: MaxStats
source: wiki
---

`#MaxStats` is your character's stat cap: the most that strength, dexterity and intelligence can add up to.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
set %total #Str + #Dex + #Int
if %total >= #MaxStats
  display ok Stats are capped.
halt
```
