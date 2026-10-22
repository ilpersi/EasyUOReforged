---
title: "SetUOTitle"
description: "Sets the title of the client window."
kind: command
category: client
syntax: "setuotitle {title}"
needsClient: true
related: ["GetUOTitle", "#CliTitle"]
aliases: ["window title", "rename window"]
source: wiki
---

`setuotitle` changes the title of the client window, for example to tell several clients apart. Setting
[`#CliTitle`](/variables/clititle/) does the same.

:::note
UOAssist and Razor can write their own information in the title bar. Turn that option off ("Use titlebar
for display") if they overwrite your title.
:::

## Example

```euo
setuotitle Mule - #CharName
```
