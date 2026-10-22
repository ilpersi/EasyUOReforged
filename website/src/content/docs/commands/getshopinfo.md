---
title: "GetShopInfo"
description: "Retrieves information from the client about the currently shown top entry on a shopping gump."
kind: command
category: client
syntax: "getShopInfo"
needsClient: true
sets: ["#shopcurpos", "#shopcnt", "#shopitemtype", "#shopitemid", "#shopitemname", "#shopitemprice", "#shopitemmax"]
related: ["setshopitem"]
source: wiki
---

The getShopInfo command retrives information about the currently shown top entry on an open gump. When it is called it fills all the #shop\* system variables with their appropriate information

:::note
Every time you scroll to a new entry, you have to call getShopInfo to update the #shop\* system variables.
:::
