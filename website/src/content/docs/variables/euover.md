---
title: "#EUOVer"
description: "Always 1_50_00, the EasyUO version Reforged is ported from; see #ReforgedVer."
kind: variable
category: misc
access: ro
type: string
related: ["#ReforgedVer"]
aliases: ["version", "easyuo version"]
source: wiki
---

`#EUOVer` is the version of EasyUO, written `major_minor_build`. EasyUO Reforged always returns `1_50_00`, the
version it is ported from, so scripts that check for EasyUO 1.5 keep working.

To tell EasyUO Reforged apart, or one build from another, use [`#ReforgedVer`](/variables/reforgedver/).

## Example

```euo
str left #EUOVer 4
if #StrRes <> 1_50
  display ok This script needs EasyUO 1.5.
```
