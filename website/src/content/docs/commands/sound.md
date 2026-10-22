---
title: "Sound"
description: "Plays a wave file or the SystemDefault beep."
kind: command
category: misc
syntax: "sound [filename]"
source: wiki
---

The [sound](/commands/sound/) command plays a wave file or the SystemDefault beep.

## Example

```euo
if #charghost = YES
{
sound
halt
}
```

:::note
For File Use:

If the sound file is in a directory which exists in your dos PATH environment variable, you do not need to include a full path. Try this:

sound chimes.wav

You should hear the windows chimes sound. Sound will also accept absolute paths.

sound c:\windows\media\chimes.wav
:::
