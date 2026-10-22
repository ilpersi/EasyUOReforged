---
title: "Set"
description: "Sets a variable to a value (variable assignment)."
kind: command
category: misc
syntax: "set {{!namespaceVariable}}} [expression] [abs]"
source: wiki
---

The [set](/commands/set/) command, sets a varible to what an expression evaluates to. If the abs option is specified, the absolute (mathimatically) value will be assigned. Ommitting the expression will set the variable to a blank string.

## Example

```euo
set %a 2
set %b $a ;we can use hexadecimal too
set %c ( %a * %b ) + 1 ;%c is 21
set %d %a * ( %b + 1 ) ;%d is 22
set %e %a * %b + 1 ;%e is 21
set %f ;set %f to a blank string
set %varname 0 ;initializing a variable to 0
halt
```

:::note
Set is used to increment a variable by 1 by doing: set %varname %varname + 1
:::
