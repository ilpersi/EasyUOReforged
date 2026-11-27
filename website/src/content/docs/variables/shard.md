---
title: "#Shard"
description: "Name of the shard the client is logged in to."
kind: variable
category: client
access: ro
type: string
needsClient: true
related: ["#LShard", "#CharName"]
aliases: ["server", "shard name"]
dll: Shard
changed: true
source: wiki
---

`#Shard` is the name of the shard the client is logged in to. Spaces in the name stay spaces.

## Example

```euo
if Atlantic in #Shard
  display ok Welcome to Atlantic.
halt
```

## Reforged notes

- Its text is UTF-8, as all of a script's text in Reforged: a letter with an accent matches the same letter written
  in the script, and [`str`](/commands/str/) counts it as one letter, as in EasyUO 1.5. See
  [Letters with accents](/language/variables/#letters-with-accents).
