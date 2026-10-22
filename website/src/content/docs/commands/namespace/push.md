---
title: "namespace push"
description: "Stores the current namespace name and scope."
kind: subcommand
category: namespace
syntax: "nameSpace push"
source: wiki
---

*(Added in 1.40)* The **[Namespace](/commands/?category=namespace)** push command stores the current [Namespace](/commands/?category=namespace) name and scope in an internal stack.

The default [Namespace](/commands/?category=namespace) is [local](/commands/namespace/local/) and named STD. This setting is restored when the script is stopped.

:::note
Currently only Local scope is available. Global scope is to be introduced in a future version of EasyUO.
:::

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
