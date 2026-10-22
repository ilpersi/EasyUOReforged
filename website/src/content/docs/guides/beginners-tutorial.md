---
title: "Beginner's tutorial"
description: "A first walk through writing and running an EasyUO script."
sidebar:
  order: 2
source: wiki
---

## What do I need?

In this tutorial we assume you are running the latest Ultima Online client, and you have installed the latest EasyUO update.

To get started, follow these simple guidelines:

1.  Make sure you have the correct EasyUO version for the current client version.
2.  Start your Ultima Online client (Remember it only works with the 2D client).
3.  Start the EasyUO program.
4.  Log in with a character.

## Your first EasyUO script

Copy and Paste, or type in the following program:

```euo
msg #smc Hello there!$
halt
```

Now press the Run icon or press F9 inside the EasyUO script. Your character will now whisper: "Hello there!".

## Something useful

Now we are going to try to do something more useful. We will move the character using the [move](/commands/move/) command:

```euo
; Calculate a new x co-ordinate based on your current position
set %newX #charPosX + 2
; Calculate a new y co-ordinate based on your current position
set %newY #charPosY + 2
; Move the character to the new position
move %newX %newY 0 10s
halt
```

Now we are going to open a pack using some of the event commands. First, we need to identify the ID of your backpack (inventory):

1.  Make sure you have the variable view open. Press Ctrl-R or choose View\|Variables\|Show.
2.  Open the backpack by double clicking it in your paperdoll.
3.  Find the #LOBJECTID variable in the list.
4.  Write down the value that's next to #LOBJECTID. It consists of 6-8 letters. That is your backpack's ID.

:::note
Most clients have the [BackpackId](/variables/backpackid/) system variable available, which automatically shows the item Id of the currently logged in character's backpack.
:::

Then copy and paste this script into EasyUO, be sure to edit it where noted:

```euo
; The id of your pack. Change it to the value you wrote down
set %pack XYZ
; Assign your pack's ID to the last object id system variable
set #lObjectID %pack
; Run UO's client macro for "Use Last Object"
event Macro 17
halt
```

## What's next?

With what you know now you should be able to understand most of the manual and also the various example scripts available in the example archives. You can also find other examples on the [EasyUO website](http://www.easyuo.com).
