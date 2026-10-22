---
title: "Sleep"
description: "Waits a specified amount of time."
kind: command
category: client
syntax: "sleep {time}"
needsClient: true
related: ["wait"]
source: wiki
---

The sleep command suspends the processing of EasyUO for a specified amount of time, in milliseconds.

:::note
For values above 50 ms it is recommended that the [wait](/commands/wait/) command be used.

**Quoted from Cheffe**: Wait durations have to be exactly 50ms or multiples of it because that's how long one cycle takes. Even if you could specify values shorter than 50ms it would still take 50ms because that's how long it takes for the next cycle to start. Now, sleep doesn't work with cycles. It simply stops execution right where it is (freezing the EUO window). After the specified amount of milliseconds, execution is continued and the interrupted cycle continues as well.

If you only had one command per cycle then there wouldn't be any difference between sleep and wait because the interrupted cycle would end right after sleep was executed anyway (because it's only one line per cycle). If you have more lines then the cycle will continue as normal.

Sleep and Wait both don't take any CPU time at all. EUO doesn't do anything while waiting for another cycle to start and Sleep simply pauses the current cycle. Sleep only makes sense for short periods of time (\<50ms). If you want to wait for exactly 125ms then you can make a "wait 2" and a "sleep 25". Sleep freezes EUO while wait does not. Thus it makes sense to limit Sleep to very low values because you can combine those two commands to build all other values.
:::

Quote is from this thread: <http://www.easyuo.com/forum/viewtopic.php?p=34120#34120>

## Example

```euo
...
; Wait for 5 miliseconds
sleep 5
...
```
