---
title: "event PathFind"
description: "Moves you to a specified position if it is possible."
kind: subcommand
category: event
syntax: "event PathFind {X-Coordinate} {Y-Coordinate} [Z-Coordinate]"
needsClient: true
source: wiki
---

The event PathFind moves you to the position given by the coordinates. If the Z coordinate os omitted, it is assumed to be -1.

:::note
- Please note that your script will keep on executing while the character is moving. Take a look at the example below which mimics the way that the move command works.
- The event PathFind command only works within one screen. If you need to move longer you need to break up the path in to several calls.
:::

## Example

```euo
;===========================================================
; Name: pathFind
; Author: ScriptFellow (the.WZA)
; Parameters: %1 = X
;             %2 = Y
;             %3 = Z
;             %4 = tolerance
;             %5 = timeout (in seconds)
; Purpose: Pathfind to the given coordinates
; Return: %return (#true or #false )
;-----------------------------------------------------------
sub pathFind
set %_x %1
set %_y %2
if %0 <= 2 || %2 = N/A
   set %_z -1
else
   set %_z %3
if %0 <= 3 || %3 = N/A
   set %_tolerance 0
else
   set %_tolerance %4
if %0 <= 4
   set %_endTime #sCnt + 15
else
   set %_endTime #sCnt + %5
set %return #false
deleteJournal
scanJournal 2
event PathFind %_x %_y %_z
_pathFindScanAgain:
scanJournal 1
if pathfinding in #journal
   goto _pathFindOkay
if can't_get_there in #journal || #sCnt > %_endTime
   return
goto _pathFindScanAgain
_pathFindOkay:
gosub _pathFindDist %_x %_y %_z #charPosX #charPosY #charPosZ
set %return %return <= %_tolerance
if %return
{
   if %_tolerance > 0
   {
      set %1 #cliLeft + #cliXRes / 2
      set %2 #cliTop + #cliYRes / 2
      if #charDir < 3
          set %1 %1 + 1
      else
      {
         if #charDir > 3 && #charDir < 7
            set %1 %1 - 1
      }
      if #charDir = 0 || #charDir = 6
         set %2 %2 - 1
      else
      {
         if #charDir > 1 && #charDir < 5
            set %2 %2 + 1
      }
      click %1 %2 R
   }
   return
}
if #sCnt > %_endTime
   return
goto _pathFindOkay

sub _pathFindDist
set %1 %1 - %4 abs
set %2 %2 - %5 abs
set %3 %3 - %6 abs
gosub max %1 %2 %3
return

; to be defined
sub max
set %return %1
for %_idx 2 %0
{
   if % . %_idx > %return
   set %return % . %_idx
}
return
```
