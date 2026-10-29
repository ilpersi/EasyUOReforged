---
title: "namespace global"
description: "Makes a global namespace, shared with every running script, the current one."
kind: subcommand
category: namespace
syntax: "namespace global {name}"
related: ["namespace local", "#NSType"]
aliases: ["shared variables"]
source: wiki
---

`namespace global` makes the global namespace `name` current. A global namespace is shared by every script
running in EasyUO Reforged, in any tab: what one script sets, the others read, as long as they switch to the
same namespace first.

`name`: A name made of letters, digits and `_`, not starting with a digit. Case does not matter.

## Example

Two scripts, in two tabs:

```euo
; first script
namespace global shared
set !status mining
pause
halt
```

```euo
; second script
namespace global shared
display ok The first script is !status
halt
```
