---
title: "menu Font Name"
description: "Sets the font of the controls created after it."
kind: subcommand
category: menu
syntax: "menu Font Name {font}"
related: ["menu Font Size", "menu Font Style", "menu Clear"]
source: wiki
---

`menu Font Name` sets the font of the controls created after it, by its name as Windows knows it. Names with
spaces are fine. The default is Arial.

Symbol fonts such as Wingdings only show the intended symbols if that exact font is installed; otherwise
Windows substitutes another font and the characters look unrelated.

## Example

```euo
menu Font Name Times New Roman
menu Text title 10 10 Hello
```
