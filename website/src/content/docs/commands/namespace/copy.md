---
title: "namespace copy"
description: "Copy variables from one namespace to another."
kind: subcommand
category: namespace
syntax: "nameSpace copy {filter} {from  |  to} {local  |  global} {namespace name}"
source: wiki
---

*(Added in 1.40)* The **[Namespace](/commands/?category=namespace)** copy command allows to copy all or part of variables within a [Namespace](/commands/?category=namespace) into another. The {filter} parameter is use to specify which variables should be copied and accepts two special characters "?" and "\*".

The "?" character matches any single character and can be use multiple times within one {filter} expression. I.e. "return?" will match any variable whose name start with "return" and has one additional character.

The "\*" character matches zero or more unspecified character. It can only appear but once within a {filter} expression. I.e. "return\*" will match any variable whose name start with "return".

The {from \| to} parameter defines the direction for the copy, while the {local \| global} {namespace name} parameters define the [name](/variables/nsname/) and scope of the [Namespace](/commands/?category=namespace) to be used.

From: copies variables from the specified [Namespace](/commands/?category=namespace) into the current [Namespace](/commands/?category=namespace).

To: copies variables from the current [Namespace](/commands/?category=namespace) into the specified [Namespace](/commands/?category=namespace). If the specified [Namespace](/commands/?category=namespace) doesn't exist at this time, it will be created.

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
