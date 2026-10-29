---
title: "Stat and skill gains on RunUO shards"
description: "How stat and skill gains work on RunUO-based free shards, and what that means for training scripts."
sidebar:
  order: 7
source: wiki
---

How fast a training script gains depends on the shard's rules. This page describes the gain system of
**RunUO**, which many free shards were built on, as players read it from RunUO's source code in the 2000s.
Shards based on newer code (ServUO, ModernUO) or with custom rules can behave differently.

## Stat gains

- **There is no "8×8" on RunUO.** Whatever makes official shards seem to have lines of gain spots in 8×8 areas
  does not exist here. Moving slowly in one direction (on a boat, or walking) is enough; walking back and
  forth to "find the gain line" wastes time.
- **There is anti-macro code**, for the same skills as on official shards, but it works differently:
  - It is either target-based or movement-based. For target-based skills, each object is one target.
  - For movement-based skills the map is divided into 5×5 tile areas, counted from tile 0,0 of each map, not
    from where your character stands.
  - You can gain up to three times per target or per 5×5 area in any five-minute period. When five minutes
    have passed since the first gain, the second one starts the next period.
  - Below 10 points in a skill, the anti-macro code is not checked.
  - It does not apply to pets.

## Skill gains

Below 10 points, a gain adds 0.1 to 0.4 at random; from 10 points on, it always adds 0.1. Whether you gain on
an attempt depends on three weighted factors:

1. **How hard the attempt is (50 %).** Each object or action has a minimum and a maximum skill for gaining:
   below the minimum it is too hard, above the maximum too easy. The closer your skill is to the minimum, the
   higher the chance; it drops towards zero near the maximum. A success counts half of this factor, a failure
   only a fifth.
2. **How far your total skills are from the total cap (25 %).** `(total cap − total skills) ÷ total cap`. At
   697 out of 700 this is almost zero; at 400 out of 700 it is about half.
3. **How far the skill is from its own cap (25 %).** `(skill cap − base skill) ÷ skill cap`. At 99.8 out of 100
   it is almost zero.

What that means for training:

- Lock every skill except the ones you are training, and stay below your total skill cap.
- Train the hardest and most expensive skills first, while your total is low.
- Raise a skill's cap with a power scroll if you can, even if you only want to reach 100: 99.7 out of a cap
  of 120 still has a large third factor.
- Train well below an object's maximum skill, where you succeed about 20–40 % of the time, and move on to
  harder objects as soon as you can (bears instead of horses for taming, for example).

*Based on a forum post by Roadkill, copied to the EasyUO wiki.*
