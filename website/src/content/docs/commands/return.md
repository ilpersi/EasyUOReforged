---
title: "Return"
description: "Returns from a sub."
kind: command
category: flow
syntax: "return { expression }"
related: ["gosub", "sub"]
source: wiki
---

The *return* command transfers the execution back to where the [sub](/commands/sub/) was called using [gosub](/commands/gosub/).

providing a variable or expression to *return* will put the given value into the [result](/variables/result/) system variable.

## Example

```euo
gosub makeLowerCase #charname
event macro 1 0 my name is #result
halt

;The following sub takes the first parameter
;makes it lowercase, and then returns the
;lowercase version.
sub makeLowerCase
    str lower %1
return #strRes    ; the lowercase version of %1 is now stored in #result and control is returned to the main script.
```
