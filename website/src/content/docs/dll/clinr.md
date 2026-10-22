---
title: "CliNr"
description: "Which of the running clients the script drives, counting from 1."
kind: dll-property
category: property
syntax: "Get CliNr  \u2192  number\nSet CliNr {number}"
related: ["#CliNr"]
aliases: ["UO.CliNr"]
---

`CliNr` is a read/write property: the same value as [`#CliNr`](/variables/clinr/), returned as a number.

Which of the running clients the script drives, counting from 1.

**`Set CliNr` attaches the handle to client number n** (1 to `CliCnt`). A program does this first, before reading anything else.
