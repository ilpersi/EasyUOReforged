---
title: "#CharID"
description: "Returns the id of the character."
kind: variable
category: character
access: ro
type: id
needsClient: true
source: wiki
---

The #charID system variable determines the id of your character. This is a unique identifier, so it can be used to identify different characters and make specific actions depending on what character it is. This variable can also be used as a container for [findItem](/commands/finditem/).

## Example

```euo
findItem *
for #findIndex 1 #findCnt
{
  if #findId <> #charId
    event ExMsg #findId 3 0 This is someone or something else.
  if #findId = #charId
    event ExMsg #charID 3 0 This is me!
}
halt
```
