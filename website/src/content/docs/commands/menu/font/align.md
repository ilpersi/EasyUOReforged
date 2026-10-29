---
title: "menu Font Align"
description: "Sets how the text of labels and check boxes created after it is aligned."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Font Align {left|center|right}"
related: ["menu Text", "menu Check"]
source: wiki
---

`menu Font Align` sets the alignment for the controls created after it:

- for a [text label](/commands/menu/text/) with several lines, how the lines line up;
- for a [check box](/commands/menu/check/), `right` puts the caption on the left of the box.

The default is `left`.

## Example

```euo
menu Clear
menu Window Size 200 60
menu Font Align center
menu Text info 10 10 First line$second line, longer
menu Show
halt
```
