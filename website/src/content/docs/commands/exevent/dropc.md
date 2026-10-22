---
title: "exevent Dropc"
description: "Drops an object in a given container using packets."
kind: subcommand
category: exevent
syntax: "Exevent Dropc {container id} [x y]"
needsClient: true
related: ["exevent"]
source: wiki
---

The *Exevent Dropc* command drops obects you drag using the [Exevent Drag](/commands/exevent/drag/) command to any container you want.

If you specify x/y then the item will be dropped in the container at the x/y coordinates relative to the container's location, otherwise it will be dropped on the container.

If you want to combine the stack being dragged with another stack of the same item type, just pass the ID of the destination stack as `{container id}`.

:::note
- This command is only available from EUO 1.5
- The x/y parameter is only available from EUO 1.5 TV 56
- You shouldn't use [Event Drag](/commands/event/drag/) in connection with [Exevent Dropc](/commands/exevent/dropc/) command or you'll end up with a ghost item on your cursor. That's why there is an [Exevent Drag](/commands/exevent/drag/) command
:::

## Example

```euo
finditem %gold G_2
if #FINDCNT > 0
{
    Exevent Drag #findid #findstack
    wait 10
    Exevent Dropc #backpackid  ;drops in a random location in backpack or stacks with existing
    wait 10
}

event macro 8 7   ;opens backpack
contpos 100 100   ;positions it at 100,100
finditem %mushroom G_2
if #FINDCNT > 0
{
        Exevent Drag #findid 1
        wait 10
        Exevent Dropc #backpackid 80 80  ;drops the mushroom at 80,80
        wait 10
}
halt
```

## User Contributed Notes

**Orngrimm 11.Apr.07:**\
Use [Exevent DropC](/commands/exevent/dropc/) to add one stack to another (stacking): Think of the other stack as a container!

```euo
   exevent drag %itemID %StackAmmount  ;%itemID being the ID of the stack you want to add to another stack
    exevent dropc %StackID  ;%StackID being the ID of the target-stack
```

Recent findings about [exevent dropc](/commands/exevent/dropc/): Some users noticed some problems with the method above: Sone (all?) Pol96-Servers dont handle stacks as containers like EA or RunUO does. So the first stack reappears at the original location after the dropC-try.

**snicker7 10/21/05:**\
Here are a few things to note about [exevent dropc](/commands/exevent/dropc/):

[exevent dropc](/commands/exevent/dropc/) can drop to ANY container or object (see below) that is within reach, REGARDLESS of whether or not the container or object is actually visible on the screen. This means that even if you have a bag 2 levels deep in a chest locked down on the floor of your house, if you know the ID of the container, you can drop things into it. Attempting to drop to a container that does not exist or that is out of reach will cause the item to "bounce back" to its original position.

Additionally, [exevent dropc](/commands/exevent/dropc/) will take ANYTHING as a parameter that you could normally drag and drop an item onto; it is not solely limited to containers. This includes things like NPCs, Spellbooks, BOD Books, Animals (beetles, packhorses, etc), even other players to initiate trade sessions. For a simple example, say you wanted to drop an item into the backpack of your beetle:

```euo
finditem %beetleID G_2
if #FINDCNT > 0
{
    exevent drag %itemID    ;%itemID being the ID of the object
    exevent dropc #findid   ;#findID being the ID of the beetle
}
```

You don't actually have to even know the ID of the beetle's backpack (which is different from the beetle's actual ID), because it functions just as if you had actually dropped the item onto the beetle normally. This also means that if you were to drop meat onto it, it would not go into the pack, but would instead be considered food to the beetle.
