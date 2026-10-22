---
title: "SetDelay"
description: "Registers a function the DLL calls whenever a method has to wait (two pointers: the function, and a value passed back to it)."
kind: dll-call
category: call
syntax: "SetDelay {function} {info}"
---

Registers a function the DLL calls whenever a method has to wait (two pointers: the function, and a value passed back to it). The function receives the milliseconds to wait and the info pointer, and returns false to cancel. Without it, the DLL simply sleeps.

A `Query` command: push it and any values, then call `Query`.
