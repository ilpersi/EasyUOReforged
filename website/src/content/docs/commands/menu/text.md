---
title: "menu Text"
description: "Creates a label at the specified position in the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Text {name} {x} {y} {text}"
source: wiki
---

The [menu Text](/commands/menu/text/) command creates a label at the specified position in the EasyUO menu window.

## Example

```euo
; This will create a text line named text_1 at position 10 20
; with the words Read me!
; Note that when refering to this field later in the script
; you will reference the NAME and not the displayed TEXT.
menu Text text_1 10 20 Read me!
```
