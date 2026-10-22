---
title: "Sound"
description: "Plays a .wav file, or the Windows default beep."
kind: command
category: misc
syntax: "sound [file]"
related: ["Display"]
aliases: ["beep", "play sound", "wav"]
source: wiki
---

`sound` plays a sound. Without a file it plays the Windows default beep. With a `.wav` file it plays that, in
the background: the script does not wait for the sound to end. A file that cannot be found plays nothing.

Give the full path of the file.

## Example

```euo
if #CharGhost = yes
{
  sound C:\Windows\Media\chimes.wav
  halt
}
```
