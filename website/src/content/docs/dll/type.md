---
title: "Type"
description: "Describes a member: pushes its kind (1 read-only property, 2 read/write property, 3 method), then one parameter mask per form (`n` number, `s` string, `b` boolean, `*` anything that follows)."
kind: dll-call
category: call
syntax: "Type {name}"
related: ["dll:GetKeywords"]
---

Describes a member: pushes its kind (1 read-only property, 2 read/write property, 3 method), then one parameter mask per form (`n` number, `s` string, `b` boolean, `*` anything that follows).

An `Execute` command: push it, then the name and any values, then call `Execute`.
