---
title: "#CharType"
description: "Body type of your character, as a Sys26 type."
kind: variable
category: character
access: ro
type: id
needsClient: true
related: ["#CharID", "#FindType"]
aliases: ["body type", "character graphic"]
dll: CharType
---

`#CharType` is your character's body type: the graphic the client draws for it, in the same Sys26 form as
[`#FindType`](/variables/findtype/). It changes when the body does, for example when you polymorph or
turn into a ghost.

## Example

```euo
set %normal #CharType
; ... later
if #CharType <> %normal
  display ok Your body changed.
```
