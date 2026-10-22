---
title: "#Followers"
description: "How many follower slots your pets and summons use."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#MaxFol"]
aliases: ["pets", "control slots"]
source: wiki
---

`#Followers` is how many follower slots your pets and summons use now; [`#MaxFol`](/variables/maxfol/) is how many you have.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
if #Followers < #MaxFol
  gosub tame
```
