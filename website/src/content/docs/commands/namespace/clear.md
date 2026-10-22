---
title: "namespace clear"
description: "Deletes every ! variable of the current namespace."
kind: subcommand
category: namespace
syntax: "namespace clear"
related: ["namespace local", "DeleteVar"]
source: wiki
---

`namespace clear` deletes every variable of the current namespace. It takes no name: to clear another
namespace, switch to it first.

## Example

```euo
namespace push
namespace local temp
namespace clear          ; start temp empty
; ...
namespace pop
```
