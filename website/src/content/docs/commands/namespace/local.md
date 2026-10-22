---
title: "namespace local"
description: "Makes a local namespace, private to this script, the current one."
kind: subcommand
category: namespace
syntax: "namespace local {name}"
related: ["namespace global", "namespace push", "#NSName"]
source: wiki
---

`namespace local` makes the local namespace `name` current. From then on, `!x` means variable `x` of that
namespace. Only this script can see a local namespace; switching away and back finds its variables as they
were.

`name`: A name made of letters, digits and `_`, not starting with a digit. Case does not matter.

A script starts in the local namespace `std`, and starts there again each time it is run.

## Example

```euo
namespace local ns1
set !test one
namespace local ns2
set !test two
namespace local ns1
display ok !test         ; one
halt
```
