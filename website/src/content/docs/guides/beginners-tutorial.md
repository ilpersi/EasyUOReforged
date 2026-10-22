---
title: "Beginner's tutorial"
description: "A first walk through writing and running EasyUO scripts: speaking, walking and opening your backpack."
sidebar:
  order: 2
source: wiki
---

This tutorial writes three small scripts. Before you start:

1. [Install EasyUO Reforged](/guide/install/) and check that it supports your client version.
2. Start the Ultima Online client (the classic 2D client) and log in with a character.
3. Start EasyUO Reforged.

## Your first script

Type or paste this into the editor:

```euo
msg #SMC Hello there!$
halt
```

Press **F9**, or the Play button. Your character whispers "Hello there!":
[`msg`](/commands/msg/) types the text into the client, [`#SMC`](/variables/smc/) is a `;` (a message starting
with `;` is whispered) and `$` presses Enter. [`halt`](/commands/halt/) stops the script; without it, the
script would start over from the top.

## Walking

This script walks two steps south-east, using your position from [`#CharPosX`](/variables/charposx/) and
[`#CharPosY`](/variables/charposy/):

```euo
; work out a spot 2 tiles away
set %x #CharPosX + 2
set %y #CharPosY + 2
; walk there, giving up after 10 seconds
move %x %y 0 10s
halt
```

[`move`](/commands/move/) walks in a straight line. For longer walks around obstacles, use
[`event PathFind`](/commands/event/pathfind/).

## Opening your backpack

The client remembers the last object you used in [`#LObjectID`](/variables/lobjectid/), and its *Last Object*
macro uses it again. Put your backpack there and run the macro:

```euo
set #LObjectID #BackpackID       ; your backpack
event Macro 17 0                 ; use the last object: opens it
halt
```

While a script runs, the variable inspector on the right shows the current values of the variables, which helps
you see what your script sees.

## What next

- Read about [variables](/language/variables/), [expressions](/language/expressions/) and
  [control structures](/language/control-structures/).
- Learn to find things around you with [`finditem`](/commands/finditem/).
- Browse the [commands](/commands/) and [variables](/variables/).
