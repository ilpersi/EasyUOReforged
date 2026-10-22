---
title: "#Shard"
description: "Returns which shard you are logged into."
kind: variable
category: misc
access: ro
type: string
source: wiki
---

Holds the name of the shard that the client is logged in to.

## Example

```euo
if Alexandria in #shard
{
  msg this shard is great!$
}
```
