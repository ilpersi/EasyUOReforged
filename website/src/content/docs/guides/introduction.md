---
title: "Introduction"
description: "What EasyUO is, what scripts can do with it, and where to start."
sidebar:
  order: 1
source: wiki
---

EasyUO is a free tool for writing scripts that play Ultima Online for you: small programs that read what the
client knows (your hit points, the items around you, the journal) and act on it, by clicking, typing, using
items and running the client's own macros. EasyUO Reforged is EasyUO rebuilt for modern 64-bit Windows; it runs
the same scripts.

The simplest script:

```euo
msg #SMC Hello Sosaria$
halt
```

It types `;Hello Sosaria` and presses Enter, which makes your character whisper "Hello Sosaria", then stops.

## What scripts can do

- Train skills while you are away from the keyboard.
- Craft, sort and move items.
- Buy from vendors, bank, restock.
- Keep your character alive: heal, cure, flee.
- Anything else you can describe as "when this happens, do that".

Check your shard's rules first: many shards limit or forbid unattended scripting.

## Where to go next

1. [Install EasyUO Reforged](/guide/install/) and [run your first script](/guide/first-script/).
2. Follow the [beginner's tutorial](/guides/beginners-tutorial/).
3. Learn the language: [variables](/language/variables/), [expressions](/language/expressions/),
   [operators](/language/operators/) and [control structures](/language/control-structures/).
4. Look up anything in the [command](/commands/) and [variable](/variables/) lists.
