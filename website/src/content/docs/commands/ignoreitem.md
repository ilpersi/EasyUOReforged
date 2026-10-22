---
title: "IgnoreItem"
description: "Removes items from the list searched by findItem."
kind: command
category: client
syntax: "ignoreItem [{Item ID} | {ID List} | {Item Type} | {Type List} | reset] {Numeric List}"
needsClient: true
related: ["finditem", "#findcnt", "#findid", "#findtype", "#findx", "#findy", "#findz", "#finddist", "#findkind", "#findstack", "#findbagid", "#findmod", "#findrep", "#findcol", "#findindex"]
source: wiki
---

**Overview**

ignoreItem will hide items from the [findItem](/commands/finditem/) command. If an item ID or type is ignored then any further [findItem](/commands/finditem/) commands will not find the item as long as the [findItem](/commands/finditem/) command is used with a matching parameter.

If an item *type* is ignored and [findItem](/commands/finditem/) is called using an *ID* then the item **will be found** even if the *type* of item found matches that which was previously ignored.

**item**

If an item ID or type is already ignored and ignoreItem is called to ignore it again the item ID or type will be removed from the ignore list even if the item is ignored in separate lists.

Example using a single pile of gold with a type of POF and ID of xxx

```euo
ignoreitem POF 1
; all gold is ignored
ignoreitem POF
; gold can be found again regardless of List number passed to previous command
finditem xxx
; search was done by ID, not type, so if the pile exists it will be found.
```

ignoreItem *does* support ignoring IDs and TYPEs in the same command.

You may pass the following parameters to ignoreItem:

- *Item ID*: The unique ID of a single item

```euo
ignoreItem BWVOKMS
```

- *Item ID List*: A list of 2 or more IDs joined by underscores

```euo
ignoreItem _BWVOKMS_RFTDQWE_
```

- *Item Type*: The type of item, a variable common to all instances of an item. (All stacks of gold have an item type of POF, each stack has its own unique ID)

```euo
ignoreItem POF
```

- *Item Type List*: A list of 2 or more item types joined by underscores

```euo
ignoreItem _POF_LKF_
```

## reset

The reset option will flush either all ignore item lists (global) or only a single list if the *list* option is passed

Example: flush list 2, but all other lists remain in tact

```euo
ignoreitem reset 2
```

## list

Multiple ignore lists can be managed by specifying a list in the ignoreItem command.

Example using item type *POF*:

```euo
ignoreitem POF 2
```

This stores item type POF in the second ignoreItem list. It still won't show up in a [findItem](/commands/finditem/) command, and the list can be managed/reset independently of other lists.

## Example

```euo
; IgnoreItem.txt
;
; This script will demonstrate how ignoreItem can be used.
;
; Press start, go to a shop and follow the instructions.

msg #SMC Use a dagger and target an NPC$
wait 3s
msg #SMC (Press play to continue)
pause

set %npc1 #lTargetID

msg #SMC Use a dagger and target another NPC$
wait 3s
msg #SMC (Press play to continue)
pause

set %npc2 #lTargetID

ignoreItem %npc1 1
ignoreItem %npc2 2

; Nothing will be found
findItem %npc1
msg #SMC 1: #findID $
findItem %npc2
msg #SMC 2: #findID $

ignoreItem reset 1

; NPC 1 will be found
findItem %npc1
msg #SMC 1: #findID $
findItem %npc2
msg #SMC 2: #findID $

ignoreItem %npc1 1
ignoreItem reset 2

; NPC 2 will be found
findItem %npc1
msg #SMC 1: #findID $
findItem %npc2
msg #SMC 2: #findID $
halt
```
