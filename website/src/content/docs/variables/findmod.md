---
title: "#FindMod"
description: "Returns displacement for #findX and #findY."
kind: variable
category: finditem
access: rw
type: string
needsClient: true
source: wiki
---

The #findMod system variable Determines displacement for #[findX](/variables/findx/) and #[findY](/variables/findy/). The displacement is in the format {X}\_{Y} and is added to #[findX](/variables/findx/) and #[findY](/variables/findy/) respectively.

## Example

```euo
set #findmod 140_220 ;displacement of backpack location on paperdoll
finditem #backpackid C_ , #charid
event drag %something
msg $
wait 2s
click #findx #findy p ; drop on paperdoll's backpack icon
```
