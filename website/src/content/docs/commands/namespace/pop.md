---
title: "namespace pop"
description: "Restores the current namespace name and scope."
kind: subcommand
category: namespace
syntax: "nameSpace pop"
source: wiki
---

The namespace pop command restores the current namespace name and scope from an internal stack.

The default namespace is named STD and has local scope. This namespace is restored when the script is stopped, or there are no previous namespaces defined at the point that a nameSpace pop occurs.

## Example

```euo
set !return ; make sure !return is empty
gosub test
display ok !return
halt

sub test
    nameSpace Push ; saves current namespace
    nameSpace Local Test ; create a new temporary namespace to work with
    set !return this_is_a_test
    nameSpace Pop ; restore previous namespace
    nameSpace Copy ret* From Local Test ; copy variables to the original namespace
    nameSpace Push ; saves current namespace
    nameSpace Local Test
    nameSpace Clear ; free memory used by temporary namespace
    nameSpace Pop ; restore previous namespace
return
```
