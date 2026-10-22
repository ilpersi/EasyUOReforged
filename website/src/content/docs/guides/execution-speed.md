---
title: "Execution speed"
description: "Cheffe's measurements of how fast different EasyUO commands run, such as GOTO compared with GOSUB."
sidebar:
  order: 4
source: wiki
---

The question about execution speeds of different EasyUO commands like...

"Is GOTO faster than GOSUB?"

...has come up a couple of times so I thought I'd write an extended answer in form of a tutorial for this.

I've found an old post of mine that I will quote here:

> EUOhas 20 cycles per second and in each cycle it executes 10 lines of the script (default). Some commands have built in waits so that the script speed slows down considerably.

> You can't say that one command is faster than the other. EUO gives away most of the available processing time so that the UO client and other Windows applications can have it.

> EUO doesn't know the difference between a processing intensive task such as "FINDITEM \*" at WBB or a simple "SET %X 3". While 10 lines per cycle is already too fast if you have 10 FINDITEMs in a row, you could execute hundreds of SET instructions in the same time without causing the CPU any stress.

> I'm working on a concept that'll automatically estimate the needed processing time for each command and speed up execution for commands that need virtually no time at all (so that you can execute more of those per cycle).

> You can already do that now using LINESPERCYCLE or #LPC. If you use this command wisely you can speed up execution speed in parts of the script where a lot of time is wasted and slow down execution in parts that are more difficult for the CPU.

So, to sum that up:

1\. EUO executes a fixed amount of lines per cycle (10 per default).

2\. It doesn't matter if these lines are comments, GOTOs or GOSUBs because the script will always sleep for 50ms between the cycles (resulting in ~20 cycles per second in which each cycle processes 10 lines causing a total of 200 lines to be executed per second).

Therefore, if you want to speed up your scripts, you have two options:

1\. Removing lines (e.g. comments) from the script so that it runs faster even with a low #lpc value. This is the dumb solution because it only treats the symptoms.

2\. Setting #lpc to a higher value for parts of the script that can be executed really fast and lowering it for commands that execute processing intensive tasks. This is the preferred solution.

Because EUO is currently unable to guess which commands really consume a lot of CPU time and which not, it automatically yields the CPU after a fixed amount of lines. If you want to help EUO then you should set #lpc to an appropriate value in all parts of the script.

Let's take a look at how EUO works internally:

```euo
Start:
    read (#lpc) number of lines
    execute these lines
    sleep for 50ms
goto Start
```

While the script sleeps for 50ms, other applications and even the EasyUO main window can use the CPU. If that sleep period were somehow removed then the following would happen:

1\. EUO consumes 100% CPU time 2. The EUO application window freezes up 3. Other processes with equal or lower priority are affected by lag.

Why would you want to remove that 50ms sleeping period then? Only if you REALLY want to know how fast the different commands are.

How come? Because the usual execution looks like this:

```euo
SET command:
0.1ms execution for 10 lines of SET
50ms sleeping period

FINDITEM command:
5ms execution for 10 lines of FINDITEM
50ms sleeping period
```

As you can see, in the first case we get a total of 50.1ms and in the second case 55ms. In order to find out how much slower FINDITEM is you could simply subtract 50ms from both results and then compare again. But there's the problem that those 50ms for the sleeping period are not too accurate (depends on the OS).

And because very small time spans are difficult to measure, you usually want to use not only a single instruction in your tests but thousands of it to get accurate values. To get 1 second of SET execution time, you'd end up with ~500 seconds of sleeping time ballast. That can't be the solution, can it?

By the way, the model presented above also explains why you may not always get 200 lines executed per second even if #LPC is 10. You only have 20 cycles per second if the execution of the commands takes virtually no time at all. In our example, FINDITEM uses up 5ms resulting in a total cycle time of 55ms which is 18.1 cycles per second. But that small asymmetric behavior isn't really important, just interesting to know.

So, if you really want to know how fast the different commands are in relation to each other, then you must somehow overcome that 50ms sleep period because it's messing with the results.

To do this, set #LPC to an extremely high value like 100000000. This will cause EasyUO to use 100% processing time and the sleeping period will never be reached (unless you want to wait a year or so).

As mentioned before, this will also freeze up the main window but the script will be running at the maximum speed your CPU can provide.

Now that sounds like a better way to get good results, right? Just be sure to HALT your script after executing those 100'000 SET instructions or you'll have an endless loop and must kill the EasyUO process.

Here's a script that measures how fast comments can be executed:

```euo
set #lpc 1000000000
for %cnt 1 10000
{
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
;this is a test, this is a test, this is a test, this is a test
}
halt
```

This script executes 1 million comment lines and 10,000 jumps (because of the FOR instruction). On my 2GHz Intel Centrino, that takes 18 seconds with EUO1.42 and 5 seconds with EUO1.5. Not exactly slow, is it?

Now I could do the same with 100,000 SET instructions or 10,000 FINDITEM instructions and do some basic math to get the execution speeds of all commands in relation to each other. Don't forget that some commands like KEY, CLICK, TARGET and WAIT have built-in waits that makes any execution speed tests pointless.

By the way, when I implement the dynamic LinesPerCycle system for EUO1.5, I will use the exact same method as described above to get average execution speed values for all commands. According to the results, I will give points to each command. When the parser executes your script, it will not pay any attention to the number of lines but the sum of the points of all executed commands to estimate when it is right to yield the CPU again and go into slumber for another 50ms.

The optimal maximum sum of points depends on your CPU and the amount of CPU time (in percent) you want to give to EUO. For that value, I might make a constant that can be set by the user and whose default value is determined at the first startup.

I hope I could give you some insight into EasyUO's inner workings and prove that it really depends on the script authors how fast their scripts run (at least until that dynamic LPC system works) and that you shouldn't remove all comments and GOSUBs in your scripts simply because of execution speed considerations.

Tutorials
