---
title: "Execute"
description: "Executes an external program."
kind: command
category: misc
syntax: "execute {filename} [argument...]"
related: ["terminate", "uoxl"]
source: wiki
---

The *execute* command executes an external command with the argunments given.

:::note
This command does NOT work unless you have enabled the "Allow Execute" configuration option.
:::

### Examples

## Example 1 : Script in Script

Running a script, from a script.

```euo
execute EasyUO.exe healthWatch.euo
```

## Example 2 : File Writing

For example purposes, assume the following:

```euo
%task is move
%guardzone is #false
#charPosX is 4321
#charPosY is 1234
#charPosZ is 3
%tileid is 7
```

### Write line at a time to a file

```euo
execute cmd.exe /c echo gosub railtask move %task %guardzone #charPosX #charPosY #charPosZ %tileid >>rail.txt
```

Makes a file named rail.txt that consists of:

```euo
gosub railtask move 0 4321 1234 3 7
```

### Write a many lines to a file at once

The magic of cmd.exe! This only opens console window once, improves long write times dramatically. Windows 2000+ only: Maximum command in Win2000 is 4096, WinXP and Vista 8192

**Do not press Enter anywhere on the execute line until the final ", it must be one solid line without line breaks.** (The Wiki is limited in its ability to wrap code text.)

```euo
   for %counter 1 %endspot
   {
      execute cmd.exe /c "echo set % , RailStep %counter >> rail.txt && echo set % , Task , %counter %Task >> rail.txt && echo set % , Guardzone
, %counter %GuardZone >> rail.txt && echo set % , SpotX , %counter #charPosX >> rail.txt && echo set % , SpotY , %counter #charPosY >> rail.txt && echo
set % , SpotZ , %counter #charPosZ >> rail.txt && echo set % , TileID , %counter %TileID >> rail.txt"
   }
```

EDIT on 23 jan 2008: You can break lines, though you must use the concatenation operator '+' as the first character on the "breaked lines":

```euo
   for %counter 1 %endspot
   {
      execute cmd.exe /c "echo set % , RailStep %counter >> rail.txt && echo set % , Task , %counter %Task
       + >> rail.txt && echo set % , Guardzone , %counter %GuardZone >> rail.txt && echo set % , SpotX , %counter
       + #charPosX >> rail.txt && echo set % , SpotY , %counter #charPosY >> rail.txt && echo
       + set % , SpotZ , %counter #charPosZ >> rail.txt && echo set % , TileID , %counter %TileID >> rail.txt"
   }
```

Makes a file named rail.txt that consists of:

```euo
set %RailStep 1
set %Task1 move
set %Guardzone1 0
set %SpotX1 4321
set %SpotY1 1234
set %SpotZ1 3
set %TileID1 7
```
