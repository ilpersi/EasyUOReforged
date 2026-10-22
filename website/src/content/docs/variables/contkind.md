---
title: "#ContKind"
description: "Returns the kind of the currently selected container/gump."
kind: variable
category: container
access: ro
type: id
needsClient: true
source: wiki
---

The #contKind system variable determines the kind of the currently selected container/gump. Most menus have a kind attached to them. The can be utilized to find out if a crafting menu is open, if something is being dragged, if a runebook is open and many other things.

:::note
This variable can change every time a new patch is released for the client, and EasyUO is updated. Good scripting standards dictate that you use variables in top of your script for #contKind's. In this way #contKind values can easily be updated when the client is patched.
:::

:::note
EasyUO currently only holds information in the #cont\* on the "top most" gump. This means that the last gump that was opened or moved in any way is what EUO is reporting.
:::

## Example

```euo
...
if #contKind <> %craftMenuKind
     gosub useNewTool
...
```
