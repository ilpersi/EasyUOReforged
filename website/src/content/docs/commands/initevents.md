---
title: "InitEvents"
description: "Initializes all event commands."
kind: command
category: obsolete
syntax: "initEvents"
obsolete: true
source: wiki
---

The *initEvents* command initializes all event commands. If it is not run once per script, none of the event commands will function. You should only call *initEvents* once per script.

:::note
It should be noted that *InitEvents* is no longer required on current releases of EasyUO. The first time you use an [event Macro](/commands/event/macro/) it will automatically initialize. If it is used now it hurts nothing. But serves no purpose either
:::

## Reforged notes

EasyUO Reforged does not know the word at all: like any unknown command, a line starting with `initEvents`
is skipped. Event commands set themselves up the first time they run.
