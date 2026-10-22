---
title: "Variables"
description: "Variables in Easy UO come in four types; Standard, Namespace, Persistent and System."
sidebar:
  order: 1
source: wiki
---

## Basics

Variables in Easy UO come in four types; Standard, Namespace, Persistent and System. The type of a variable is defined by its first character. Standard variables start with a percent sign (%), Namespace variables with an exclamation mark ( ! ), Persistent variables with an asterisk sign (\*) and System variables with an hash sign (#).

Variable names follow the same rules as other labels in EasyUO. A valid variable name starts with a letter or underscore, followed by any number of letters, numbers, or underscores.

```euo
set %var Bob
set %Var Joe
msg %var %Var ; outputs "Joe Joe"

set %4bank not_yet     ; invalid; starts with a number
set %_4bank not_yet    ; valid; starts with an underscore
```

## Standard Variables

Standard variables in EasyUO are represented by a percent sign (%) followed by the name of the variable. The variable name is case insensitive.

## Namespace Variables and Scope

Namespace variables in EasyUO are represented by an exclamation mark ( ! ) followed by the name of the variable. Namespace variable name is case insensitive.

Namespace variables visibility is affected by the [nameSpace](/commands/namespace/local/) command.

Namespace variables within a local namespace can only be accessed by the current script.

Namespace variables within a global namespace can be accessed by all scripts running in the same instance of EasyUO (not yet available).

## Persistent Variables

Persistent variables in EasyUO are represented by an asterisk sign (\*) followed by a variable name. In earlier versions of EasyUO, the variable names were limited to numbers between 1 to 1000 inclusive. Variable names can now be any valid variable name however, just as other types of variables.

Persistent variables are stored in the registry under the key **HKEY_CURRENT_USER\Software\EasyUO** and are therefore shared between any instance of EasyUO.

## System Variables

System variables in EasyUO are represented by an hash sign (#) followed by a descriptive text. As is true with everything else in EasyUO, system variable names are not case sensitive, meaning that #CHARID is the same as #charid, or even #ChArId.

System variables are all described in detail in the [System Variable Reference](/variables/).

## Variable Scope

The term *scope* used in reference to variables describes when a variable is known and visible to other parts of a program. The following table describes, in general, the scope of variables within EasyUO.

| type | Scope |
|----|----|
| Standard | Standard variables are visible to all code within the script that crates the variable. Standard variables are cleared when EasyUO begins executing a script. |
| Namespace | Namespace variable scope can be modified by using the Local and Global qualifiers. A Local namespace is visible only to the current script running, just as standard variables are. A Global namespace is accessible to all scripts running in the same EasyUO instance (available only in EasyUO 1.5) that have the namespace defined as global. This initializes that script's usage of the global namespace. Namespace Variables are cleared when EasyUO begins executing a script. |
| Persistent | Persistent variables are visible to all scripts running on the same computer. Persistent variables are stored in the registry and are never cleared unless you clear them in a script or edit the registry manually. |
| System | System variables are visible to each instance of EasyUO that is utilizing the same instance of Ultima Online. System Variables are not saved by EasyUO. |
