---
title: "#MenuButton"
description: "Returns the name of the last clicked menu Button."
kind: variable
category: result
access: rw
type: string
source: wiki
---

Holds the name of the last menu button pressed.

If you close the menu window, the #menuButton value is set to "Close". The minimize and maximize buttons do not set the #menuButton variable, however.

:::note
You should set #menuButton to a meaningless value when you have read which button was clicked in order to distinguish between two seperate clicks
:::

## Example

```euo
menu Window Size 200 200
menu Window Title Test
menu Button button_1 10 20 50 25 Click me!
menu Button button_2 10 50 50 25 Click me!
menu Button button_3 10 80 50 25 Click me!
menu Show

set #menuButton Nothing
lookButton:
if #menuButton <> Nothing
{
  display ok #menuButton , #spc , was pressed
  set #menuButton Nothing
}
goto lookButton
```
