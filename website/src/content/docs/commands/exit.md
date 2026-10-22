---
title: "Exit"
description: "Exits a called script."
kind: command
category: flow
syntax: "exit"
related: ["call"]
source: wiki
---

*exit* will stop the execution of the current script. If it's called from inside a script that was called using [call](/commands/call/) it will resume execution from the line under the [call](/commands/call/) statement. If the *exit* is used from the main script, the script will start over.

## Example

```euo
event macro 1 0 %pet %command
if %pet = all
    exit
event macro 1 0 %pet follow me
```

EDIT on 23 jan 2008: As you can see, when calling a file (with the call command), there is no possibility to return a value with exit as you would do when returning from a subroutine.

Here's a way to get around this "problem":

calling file

```euo
set %a 0
call a.txt ;You may need to ajust the path here
display ok a = %a
halt
```

called file (a.txt)

```euo
set %a Hello,_I_am_the_variable_%a_set_in_a.txt
exit
```
