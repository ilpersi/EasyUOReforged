---
title: "HideItem"
description: "Removes an items graphic from the client."
kind: command
category: client
syntax: "hideItem {id}"
needsClient: true
related: ["finditem"]
source: wiki
---

The hideItem command removes a specific items graphic from the client. It can be used to unclutter the visual appreance of the EasyUO client however, it does **nothing** on the server. Only non static items that are on the ground can be hidden.

## Example

```euo
; This will hide the item returned by the findItem command
findItem * G_12
hideItem #findId
halt
```
