---
title: "InitEvents"
description: "Obsolete: event commands set themselves up; the line is ignored."
kind: command
category: obsolete
syntax: "initevents"
obsolete: true
related: ["Event"]
source: wiki
---

Old EasyUO versions needed `initevents` once per script before any [`event`](/commands/event/) command would
work. Later versions set the event commands up the first time one is used, so the command was no longer
needed.

EasyUO Reforged does not know the word at all: like any unknown command, a line starting with `initevents` is
skipped. Remove it from your scripts.
