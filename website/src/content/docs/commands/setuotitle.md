---
title: "SetUOTitle"
description: "Sets the title of the client window."
kind: command
category: client
syntax: "setuotitle {title}"
needsClient: true
related: ["GetUOTitle", "#CliTitle"]
aliases: ["window title", "rename window"]
changed: true
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
halt
```

## Reforged notes

- The title is set through Windows' Unicode call from the script's UTF-8 text, so every letter shows as itself.
  EasyUO 1.5 used the Windows code page, where a letter outside it showed as `?`. See
  [Letters with accents](/language/variables/#letters-with-accents).
