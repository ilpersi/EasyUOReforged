---
title: "MountType"
description: "Type of the mount item your character rides, or N/A while it is on foot."
kind: dll-property
category: property
syntax: "Get MountType  \u2192  number"
needsClient: true
related: ["#MountType"]
aliases: ["UO.MountType"]
---

`MountType` is a read-only property: the same value as [`#MountType`](/variables/mounttype/), returned as a number.

Type of the mount item your character rides, or N/A while it is on foot.

IDs come back as plain numbers, not as the letter codes the `#` variable shows.

It is 0 while your character rides nothing, where `#MountType` reads `N/A`.
