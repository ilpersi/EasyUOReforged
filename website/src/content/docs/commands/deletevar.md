---
title: "DeleteVar"
description: "Sets a variable to an empty string."
kind: command
category: obsolete
syntax: "deleteVar {variable name}"
obsolete: true
source: wiki
---

The [deleteVar](/commands/deletevar/) command deletes the content of a variable.

:::note
- The content can only be deleted if the variable has already been assigned to.

- The deleteVar command is deprecated since the set command can now assign an empty string value to a variable.
:::

## Example

```euo
...
; set %test to something
set %test TEST

; note there is no % char in front.
deleteVar test

; %test now holds nothing
...
```
