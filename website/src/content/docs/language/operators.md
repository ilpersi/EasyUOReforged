---
title: "Operators"
description: "EasyUO includes the traditional arithmetic operators as specified in the table below."
sidebar:
  order: 3
source: wiki
---

## Arithmetic Operators

EasyUO includes the traditional arithmetic operators as specified in the table below.

| Example | Name | Result |
|----|----|----|
| %a + %b | Addition | addition combines two numbers, the augend and addend, into a single number, the sum. |
| %a - %b | Subtraction | subtraction takes one number called the minuend, away from a second number called the subtrahend, and results in the difference. |
| %a \* %b | Multiplication | multiplication is a quick way of adding identical numbers. The two numbers being multiplied are called factors, and the result is the product. |
| %a / %b | Division | division is an arithmetic operation which is the reverse operation of multiplication, and sometimes it can be interpreted as repeated subtraction. Division in EasyUO is Integer based, meaning that when the division operator is used any remainders are dropped. See below. |
| %a % %b | Modulo | the modulo operation finds the remainder of division of one number by another. |
| ABS %a | Absolute | The absolute value operation returns the numerical representation of the value provided without regard to it's sign. |

## Comparison Operators

EasyUO can perform mathimatical comparisons of any two values using the operators specified below.

| Example | Name | Result |
|----|----|----|
| %a = %b | Equality | Tests that the two operands are the same. |
| %a \<\> %b | Not equal | Tests that the two operands are not the same. |
| %a \< %b | Less than | Tests that the first operand is lesser than the second. |
| %a \> %b | Greater than | Tests that the first operand is greater than the second. |
| %a \<= %b | Less than or equal to | Tests that the first operand is exactly equal or less than the second. |
| %a \>= %b | Greater than or equal to | Tests the the first operand is exactly equal or greater than the second. |
| %a in %b | Contained In | Tests that the first string value is contained somewhere within the second. |
| %a notIn %b | Not contained in | Tests that the first string value is not contained anywhere within the second. |

EasyUO is a weakly typed language. It is therefore possible for any variable to contain either integer numeric data or string data at any time. In terms of Comparison Operations, it is therefore possible to perform invalid comparisons. If this is the case, the result will always evaluate to false. for example, the statement "if hello \> 33" will always be false. knowing this behavior it is possible to find out if a variable contains a valid number, as shown below:

```euo
set %cnt invalid
if ! ( %cnt > 0 || %cnt < 1 )
  set %cnt 0
set %cnt %cnt + 1
```

## Logical Operators

EasyUO can perform logical comparisons of any two values using the operators specified in the table below.

| Example | Name | Result |
|----|----|----|
| %a && %b | And | If both values evaluate as true, the expression is true. |
| `%a \|\| %b` | Or | If either one of the values evaluates as true, the expression is true. |
| ! %a | Not | Gives the logical inverse of the evaluation. True will exaluate to false, and false to true. |

## Concatenation Operators

| Example | Name | Result |
|---|---|---|
| + | Line continuation | indicates that the current line is the continuation of the previous line. It must be the first character on the line, not counting white spaces. Trailing white spaces on the previous line are ignored. Unlike other operators, no space is required after the line continuation operator. If a space is present immediately after the operator, it will be parsed normally and it will be part of the final string.`display ok This+ is+ all+ on+ one+ line.$halt`Because in between every '+' sign and the next word there is a space, this will result in a line like: "This is all on one line". |
| , | String concatenation | Concatenates the value of both operands into a single string value. (left-associative)`set %var1 Aset %var2 B set %test %var1 , %var2`%test becomes "AB". |
| . | Append concatenation (array) | Appends the first operand with the value of the second operand and evaluates the result. (right-associative)`set %var1 Aset %var2 Bset %Var1B s7_is_1337 set %test %var1 . %var2`%test becomes "s7_is_1337". |

## Precedence and associativity

In an expression that contains multiple operators, EasyUO uses a number of rules to decide the order in which operators are evaluated. The first and most important rule is called operator precedence. Operators of higher precedence within an expression are executed before operators of a lower precedence. For example multiplication has a higher precedence than addition. Therefore, in the expression 2 + 3 \* 4, multiplication is evaluated before addition and the result of the whole expression is 14.

If consecutive operators in an expression have the same precedence, a rule called associativity is used to decide the order in which those operators are evaluated. An operator can be left-associative, right-associative, or non-associative.

Left-associative operators of the same precedence are evaluated in order from left to right. For example, addition and subtraction have the same precedence and they are left associative. In the expression 10 - 4 + 2, the substraction is done first because it is to the left of the addition and the expression therefore produces a value of 8.

Right-associative operators of the same precedence are evaluated in order from right to left.

A non-associative operator cannot be combined with other operators of the same precedence.

| Precedence    | Operator               | Associativity     |
|---------------|------------------------|-------------------|
| 1a | .                      | right-associative |
| 2a | ,                      | left-associative  |
| 3             | ( )                    | non-associative   |
| 4             | unary minus, and NOT   | right-associative |
| 5             | \* / %                 | left-associative  |
| 6             | \+ -                   | left-associative  |
| 7             | \< \> \<= \>= in notIn | left-associative  |
| 8             | = \<\>                 | left-associative  |
| 9             | &&                     | left-associative  |
| 10            | the OR operator        | left-associative  |
| 11            | ABS                    | left-associative  |

Note about the dot (array operator) and comma (concatenation) operators: These operators have the highest precedence. They are special for they are evaluated before everything else (including commands). This property enable their use in any context like this:

```euo
dis . play yes , no ok
h , a , l , t
```

### Associativity for Dummies

This section was mainly added for many users that have trouble understanding the differences between the dot and comma operators and proper usage of them, but a proper understanding of associativity is all that is really needed. When an operator is RIGHT-ASSOCIATIVE such as in the case of the dot (".") operator, everything to the RIGHT of the operator is evaluated before everything to the left. Think of it as reading from right to left.

A left associative operator, such as the comma, and many other mathematical operators, everything to the left is evaluated before what is evaluated to the right. Think of this as reading normally; left to right. Let's take the following example:

```euo
set %text1 The . #spc . quick . #spc . brown . #spc . fox . #spc . was . #spc . of . #spc . the . #spc . genus . #spc . vulpis
set %text2 The , #spc , quick , #spc , brown , #spc , fox , #spc , was , #spc , of , #spc , the , #spc , genus , #spc , vulpis
```

In this case, both operators have the same effect and the two variables will be identical, as there are no evaluations done. However, it is considered proper coding to use the comma operator for string/value concatenation. But take a look at the following example:

```euo
set %var1 3
set %var2 spotNumber
set %var23 Tada!

set %Test1 %var2 , %var1
set %Test2 %var2 . %var1
```

After looking at the first example and then this one, you might expect that %Test1 and %Test2 would be identical. However, they are not at all. The variable %Test1 would equal "spotNumber3" whereas the variable %Test2 would equal "Tada!" Go ahead and test it yourself. Why does this occur? Associativity! Since the comma is left-associative, you read (evaluate) the line from left to right. %var2 is evaluated to "spotNumber" and then joined with %var1 which is evaluated to "3". However, since the dot is right-associative, you "read" (evaluate) from right to left! %var1 is evaluated first to "3", and THEN joined with %var2 to become %var23.. and then %var23 is evaluated to "Tada!"

**Examples:**

```euo
set %r 5 + 3 * 2 ; 5 + ( 3 * 2 ) = 11

set %r 8 - 3 - 2 ; ( 8 - 3 ) - 2 = 3

set %r 1 + 2 * 2 ; 1 + ( 2 * 2 ) = 5

set %r 1 + 2 * 2 * 4 ; 1 + ( ( 2 * 2 ) * 4 ) = 17

set %r ( 1 + 2 ) * 2 * 4 ; ( ( 1 + 2 ) * 2 ) * 4 = 24

set %a 3
set %z3 8 ; z[a]
set %w8 1337 ; w[z[a]]
set %euo %w . %z . %a
display ok %euo
halt
```
