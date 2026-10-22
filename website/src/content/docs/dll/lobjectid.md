---
title: "LObjectID"
description: "ID of the last object used; set it, then event Macro 17 uses that object."
kind: dll-property
category: property
syntax: "Get LObjectID  \u2192  number\nSet LObjectID {number}"
needsClient: true
related: ["#LObjectID"]
aliases: ["UO.LObjectID"]
---

`LObjectID` is a read/write property: the same value as [`#LObjectID`](/variables/lobjectid/), returned as a number.

ID of the last object used; set it, then event Macro 17 uses that object.

IDs come back as plain numbers, not as the letter codes the `#` variable shows.
