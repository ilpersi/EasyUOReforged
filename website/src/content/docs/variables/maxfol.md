---
title: "#MaxFol"
description: "How many follower slots your character has."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Followers"]
aliases: ["max followers"]
dll: MaxFol
source: wiki
---

`#MaxFol` is how many follower slots your character has.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
set %free #MaxFol - #Followers
display ok Free slots: %free
halt
```
