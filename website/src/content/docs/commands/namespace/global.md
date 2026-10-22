---
title: "namespace global"
description: "Defines the current namespace and its scope."
kind: subcommand
category: namespace
syntax: "nameSpace global {namespace name}"
source: wiki
---

*(Added in 1.39)* The **[Namespace](/commands/?category=namespace)** global command defines the current [Namespace](/commands/?category=namespace) name and scope. The {namespace name} must be a valid EasyUO name. The scope is global. A Global [Namespace](/commands/?category=namespace) can be accessed by any script running within the same EasyUO instance.

The default [Namespace](/commands/?category=namespace) is [local](/commands/namespace/local/) and named STD. This setting is restored when the script is stopped.

:::note
Global namespaces are only available in EasyUO 1.5.
:::

## Example

EDIT on 2 feb. 2008: global nameSpaces are particularly useful when running multiple scripts at the same time. To test these snippets copy/paste each one in a different page (run the first script, then the second, then the third to test). They MUST be wittin the same EUO instance though!!

first script:

```euo
nameSpace global test
set !testMsg Vhann_was_here_to_show_ppl_how_to_use_global_namespaces
pause
```

second script:

```euo
;Important: you MUST enter the nameSpace before you can access
;the variables created in other scripts
nameSpace global test
display Ok !testMsg
set !testMsg !testMsg , $you_can_use_globals_in_more_than_2_scripts_at_a_time.
pause
```

Third script:

```euo
nameSpace global test
display Ok !testMsg
halt
```
