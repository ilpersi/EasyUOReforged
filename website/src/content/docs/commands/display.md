---
title: "Display"
description: "Shows a message."
kind: command
category: misc
syntax: "display {[ok]  |  [okcancel]  |  [yesno]  |  [yesnocancel]} {message}"
source: wiki
---

The [display](/commands/display/) command displays a standard Windows messagebox with a set of buttons of your choice.

## Example

```euo
display yesno You have run out of ingots. Do you want to end the script?
if #dispRes = yes
    halt
...
```

:::note
Use $ to create a newline:

```euo
display ok Test $1$2$3
```

creates:

```euo
Test
1
2
3
[ ok ]
```
:::
