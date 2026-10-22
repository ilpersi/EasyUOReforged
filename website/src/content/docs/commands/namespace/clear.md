---
title: "namespace clear"
description: "Clears every variables within the current namespace."
kind: subcommand
category: namespace
syntax: "nameSpace clear"
source: wiki
---

*(Added in 1.39)* The **[Namespace](/commands/?category=namespace)** clear command clears every variables within the current [Namespace](/commands/?category=namespace).

The default [Namespace](/commands/?category=namespace) is [local](/commands/namespace/local/) and named STD. This setting is restored when the script is stopped.

:::note
Global namespaces are only available in EasyUO 1.5.
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
