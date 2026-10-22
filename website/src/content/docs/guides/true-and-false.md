---
title: "#True and #False"
description: "How to use #True and #False as on/off flags in your scripts."
sidebar:
  order: 3
source: wiki
---

## Quick Guide: #True & #False

**Author: Una**

**Purpose**

To teach you the idea of #true and #false and how to use em in scripts

## #True and #False

### How to use em and why

Boolean #true and #false are like ON / OFF variables. If something is ON, Positive, running or it has happened, its #True. If something is OFF, negative or has not yet happened its #False.

```euo
set %UseMagery yes

if %UseMagery = yes
   Use Spell Mini heal

if %UseMagery = no
   Heal with bandages
```

Most of beginners do it this way. Theres nothing really wrong, its just harder way. If you do it this way, you dont have to type so much and it looks better.

```euo
set %UseMagery #true

if %UseMagery
   Use Spell Mini Heal

if ! %UseMagery
   Heal with bandages
```

This may look confusing at start, but further look, will make it all clear. Lets take a closer look at those lines:

```euo
if %UseMagery
```

This will check, if %UseMagery is #true. If it is, then "if" sentence gets executed.

```euo
if ! %UseMagery
```

This is same, but it will turn things upside down. It will check if its UNtrue. So if this is #false, it gets executed Using #true and #false makes your script look better and easyer to understand. If you can, use these.

This was all for Booleans today. Hope you got something from this Quickye!

<hr>

Back to Tutorials
