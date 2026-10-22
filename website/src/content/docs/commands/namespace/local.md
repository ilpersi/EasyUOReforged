---
title: "namespace local"
description: "Defines the current namespace and its scope."
kind: subcommand
category: namespace
syntax: "nameSpace local {namespace name}"
source: wiki
---

The namespace local command defines the current namespace name and scope. The {namespace name} cannot start with a number, but can start with an underscore and can include any aphanumeric character. A local namespace can only be accessed by the script that defined it.

The default namespace is named STD and has local scope. This namespace is restored when the script is stopped, or there are no previous namespaces defined at the point that a [nameSpace pop](/commands/namespace/pop/) occurs.

## Example

```euo
namespace local ns1
set !test test1

namespace local ns2
set !test test2

namespace local ns3
set !test test3

namespace local ns1
display ok !test

namespace local ns2
display ok !test

namespace clear ns2
namespace local ns2
display ok !test

namespace local ns3
display ok !test

halt
```
