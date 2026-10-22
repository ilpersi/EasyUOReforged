---
title: "Expressions"
description: "Expressions are important building blocks in an EasyUO script."
sidebar:
  order: 2
source: wiki
---

Expressions are important building blocks in an EasyUO script. They can be used to create relatively advanced integer mathematics.

An expression is any of the following:

- a literal
- a variable
- an expression enclosed with parenthesis
- an unary operator followed by an expression
- an expression followed by a binary operator and an expression

```euo
set %var 1337 ; literal numeric value
set %name cheffe ; literal string value
set %temp %var
set %faux ! #true ; unary operator
set %var %var + 1 ; binary operator
set %calculus ( 2 + 2 ) * ( 3 - 1 ) ; parenthesis enclosed expressions
```

## Statements

An EasyUO script is a sequence of statements. A statement is any of the following:

- a command
- a block
- a control structure

A command typically takes the form: \<command_name\> \<parameters\>

Example:

```euo
set %var 2 + 2
```

A block is a sequence of statements grouped within brackets. Opening and closing brackets *must* occurs on a distinct line (Hence one could argue that both "{" and "}" are statements by themselves). Blocks are almost exclusively used in conjunction with control structures.

```euo
{
    set %var 2 + 2
    display ok %var
}
```

Control structure are defined individually elsewhere in the documentation.
