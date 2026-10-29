---
title: "#Shard"
description: "Name of the shard the client is logged in to."
kind: variable
category: misc
access: ro
type: string
needsClient: true
related: ["#LShard", "#CharName"]
aliases: ["server", "shard name"]
dll: Shard
source: wiki
---

`#Shard` is the name of the shard the client is logged in to. Spaces in the name stay spaces.

## Example

```euo
if Atlantic in #Shard
  display ok Welcome to Atlantic.
halt
```
