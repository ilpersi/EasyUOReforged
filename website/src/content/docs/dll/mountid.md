---
title: "MountID"
description: "ID of the mount item your character rides, or N/A while it is on foot."
kind: dll-property
category: property
syntax: "Get MountID  \u2192  number"
needsClient: true
related: ["#MountID"]
aliases: ["UO.MountID"]
---

`MountID` is a read-only property: the same value as [`#MountID`](/variables/mountid/), returned as a number.

ID of the mount item your character rides, or N/A while it is on foot.

IDs come back as plain numbers, not as the letter codes the `#` variable shows.

It is 0 while your character rides nothing, where `#MountID` reads `N/A`.
