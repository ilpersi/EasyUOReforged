---
title: "If"
description: "Executes code based on the evaluation of an expression."
kind: command
category: flow
syntax: "if ( ! ) ( expression ) ( lines | { } )\n:''or''\nif ( ! ) ( expression ) ( lines | { } ) else ( lines | { } )"
related: ["else"]
source: wiki
---

The `if` construct is one of the most important features of many languages, the EasyUO scripting language included. It allows for conditional execution of code fragments.

As described in the section about [expressions](/language/expressions/), `expression` is evaluated to its boolean value. If it evaluates to [true](/variables/true/), the next statement will be executed. If `else` is present and the expression evaluates to [false](/variables/false/), then the statement after `else` will be executed instead.

If `%a > %b` evaluates to [true](/variables/true/) in the following code fragment, it will display *"a is bigger than b"*; if it evaluates to [false](/variables/false/), *"a is equal or less than b"* will be displayed instead:

```euo
set %a 100
set %b #random
if %a > %b
    display ok a is bigger than b
else
    display ok a is equal or less than b
halt
```

Often you would want to have more than one statement executed conditionally. Of course, there is no need to wrap each statement in an if clause. Instead, you have two options. You can group several statements into a statement group or you can specify how many lines after the if statement are to be evaluated. For example, if `%a > %b` evaluates to [true](/variables/true/) in the following fragment, it would display *"a is bigger than b"* and would then assign the value of `%a` into `%b`; if it evaluates to [false](/variables/false/), *"b is equal or bigger than a"* would be displayed and the value of `%b` assigned into `%a` instead:

```euo
set %a 100
set %b #random
if %a > %b
{
    display ok a is bigger than b
    set %b %a
}
else
{
    display ok b is equal or bigger than a
    set %a %b
}
halt
```

OR

```euo
set %a 100
set %b #random
if %a > %b 2

    display ok a is bigger than b
    set %b %a
else 2
    display ok b is equal or bigger than a
    set %a %b
halt
```

The ! right after the command is a reversal of the expression which is following.

```euo
set %var hello
if %var = world
    display ok This shouldnt be displayed.
if %var <> world
    display ok This should be displayed because hello is another (<>) than world.
if ! %var = world
    display ok this should be displayed because hello is not equal world.
stop
```

## Nesting Conditional Statements

`if` statements can be nested indefinitely within other `if` or `else` statements, which provides you with complete flexibility for conditional execution of the various parts of your script.

```euo
set %a #random % 3 + 1
if %a = 1
{
  display ok One
}
else
{
  if %a = 2
  {
    display ok Two
  }
  else
  {
    display ok Three
  }
}
halt
```
