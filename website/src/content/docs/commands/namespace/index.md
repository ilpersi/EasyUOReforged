---
title: "Namespace"
description: "Switches the set of ! variables a script uses: private to the script, or shared with other scripts."
kind: command
category: namespace
syntax: "namespace {local|global|clear|push|pop|copy} [parameters...]"
related: ["#NSName", "#NSType"]
aliases: ["! variables", "shared variables", "scope"]
source: wiki
---

A namespace is a named set of `!` variables. At any moment one namespace is current, and every `!x` in the
script means the variable `x` of that namespace. Switching namespaces gives a sub its own variables, or lets
several scripts share some.

- **Local** namespaces belong to one script tab: no other script sees them.
- **Global** namespaces are shared by every script running in EasyUO Reforged, in any tab.

A script starts in the local namespace `std`. [`#NSName`](/variables/nsname/) and
[`#NSType`](/variables/nstype/) tell which namespace is current.

| Command | What it does |
|---|---|
| [namespace local](/commands/namespace/local/) | Makes a local namespace current. |
| [namespace global](/commands/namespace/global/) | Makes a global namespace current. |
| [namespace push](/commands/namespace/push/) | Remembers the current namespace. |
| [namespace pop](/commands/namespace/pop/) | Goes back to the namespace last remembered. |
| [namespace copy](/commands/namespace/copy/) | Copies variables between the current namespace and another. |
| [namespace clear](/commands/namespace/clear/) | Deletes every variable of the current namespace. |

`%` variables are not affected by namespaces: they always belong to the script.

## Example

A sub that works in its own namespace, so it cannot overwrite the caller's `!` variables:

```euo
set !count 10
gosub work
gosub work
display ok !count            ; still 10
halt

sub work
  namespace push
  namespace local work
  set !count !count + 1
  namespace pop
return
```
