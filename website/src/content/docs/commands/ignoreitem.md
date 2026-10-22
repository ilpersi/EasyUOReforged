---
title: "IgnoreItem"
description: "Makes FindItem skip items by ID or type; the same call again un-ignores them."
kind: command
category: client
syntax: "ignoreitem {id|type}[_{id|type}...] [list]\nignoreitem reset [list]"
needsClient: true
related: ["FindItem", "IgnoreCont", "#FindIndex"]
aliases: ["ignore item", "skip item"]
source: wiki
---

`ignoreitem` adds items to a list that [`finditem`](/commands/finditem/) skips.

## Parameters

| Parameter | Meaning |
|---|---|
| `id` / `type` | What to ignore: an item ID (6–8 letters) or an item type (2–3 letters). Join several with `_`. |
| `list` | Optional name (a word or number) to group entries, so they can be reset together. |
| `reset` | Removes every entry, or only those of the given `list`. |

## Details

- **Calling it again toggles.** Ignoring an ID or type that is already ignored removes it from the list,
  whichever list it was added to.
- **Types and IDs are separate.** Ignoring a type hides matching items from a `finditem` by type, but a
  `finditem` by an item's ID still finds it.

```euo
ignoreitem POF 1      ; all gold is ignored
ignoreitem POF        ; gold is found again, although it was added to list 1
```

## Examples

```euo
; ignore one pile, then several items at once
ignoreitem BWVOKMS
ignoreitem BWVOKMS_RFTDQWE_POF

; ignore every item found so far, then start again
for #FindIndex 1 #FindCnt
  ignoreitem #FindID tmp
ignoreitem reset tmp
```
