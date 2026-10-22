---
title: "#ContType"
description: "Returns the object type of the currently selected container/gump."
kind: variable
category: container
access: ro
type: id
needsClient: true
source: wiki
---

The #contType system variable determines the object type of the currently selected container/gump.

:::note
EasyUO currently only holds information in the #cont\* on the "top most" gump. This means that the last gump that was opened or moved in any way is what EUO is reporting.
:::

## Example

```euo
....
if #contType <> %trashbarreltype
       gosub opentrash
....
```
