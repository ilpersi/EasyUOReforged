---
title: "menu Font Style"
description: "Sets bold, italic, underline or strikeout for the controls created after it."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Font Style [b][i][u][s]"
related: ["menu Font Name"]
source: wiki
---

`menu Font Style` sets the style of the controls created after it. Combine the letters: `b` bold, `i`
italic, `u` underline, `s` strikeout. Without letters, the style goes back to plain.

## Example

```euo
menu Clear
menu Window Size 200 60
menu Font Style bi
menu Text warn 10 10 Careful!
menu Font Style
menu Text body 10 30 Plain again
menu Show
halt
```
