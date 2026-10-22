---
title: "Stat and skill gains on RunUO shards"
description: "How stat and skill gains work on RunUO-based free shards, and what that means for training scripts."
sidebar:
  order: 5
source: wiki
---

Originally written by Roadkill here: <http://www.easyuo.com/forum/viewtopic.php?t=15601>. This is pretty much a straight copy of his post, I simply cleaned up a little bit of the first half is all. Most of the "clean up" was actually just formatting, so all the content is still Roadkill's. Hopefully he'll come and check this out and edit it some more to his personal taste.

The internal mechanics of skill and stat gains on RunUO freeshards are available to anyone that knows how to read C# code. Roadkill has made the point that for most players, by the time you move to play on a freeshard, the primary enjoyment from playing Ultima Online does not come from trying to gain skills. If that is true, knowing the internal mechanics of how skill and stat gains are made on RunUO is of primary concern.

The points in the list below are central facts of the skill gain system on RunUO:

**Stat Gains:**

- There is no 8x8 on RunUO shards.

Whatever the code/algorithm on EA/OSI that exhibits the symptoms of a line of "gain spots" in 8 x 8 tile area, it doesn't exist on RunUO. This means that players can gain much faster by just going slow forward on a boat, or walking around on land. Any movement to "find the gainline" or "recapture the line", one forwarding, one back, etc., is all wasted time.

- There is anti-macro code in RunUO.

The same skills that are affected by the anti-macro code on OSI are affected on RunUO. However, the details of how the RunUO anti-macro code works are different that OSI's anti-macro code in the following ways:

- as on OSI, the anti-macro code operates as either target-based, or movement based. for target based skills, each unique object is considered to be one target.
- For movement based skills, RunUO divides the map into 5x5 areas which means that you do not have to move as much as on OSI. These area's are not based on your character's position in the world, but instead are layed out from the 0,0 tile on each map.
- For target and movement based anti-macro, you can gain on one target or one 5x5 area up to three times.
- All of each character's gains are tracked for five minute periods of time. This means that three gains on one area, where the gains occur within 5 minutes of the first gain, are all that is allowed. after 5 minutes passes for the first gain, the second gain is used to track the five minute period.
- if the character has less than 10 skill points in the skill being gained, the anti-macro code is not checked.
- the anti-macro code does not apply to pets at all.

**Skill gains:**

- The "skillgain" calculation to determine whether you gain while attempting the skill is pretty complex. With less than 10 points in the skill being checked, if you do gain you get a random increase from .1 to .4. With greater than 10 skill points in the skill being checked, it's always a .1 increase.

There are THREE weighted elements that are checked to determine if you gain, and your ability to optimize all three will GREATLY increase your gain rate. Here they are: a. 50%, "success factor": Each skill attempt on an object or action will have three skill levels associated with it. YOUR skill, the minimum skill for the object to gain from it, and the maximum skill that object can gain at. For example, a tinkered locked box may have a minskill of 50 lockpicking and a maxskill of 75. If YOUR lockpicking is \< 50 it's too hard--no gain; if your skill is \> 75, no gain--you must be between the two. Now, the closer you are to the MINSKILL, the more weight this is--it approaches zero as you approach the max skill. However, if you SUCCEED you get .5 of this, but if you fail, you get .2. Thus, you want to be working on objects where you are WELL AWAY from the MAXSKILL of that object! This factor is weighted 50% of the total, and if it's almost zero because you are doing things almost too easy for you, ...suxx.

b\. 25%, "Total Skills" factor: (Totalskillcap - TotalSkills ) / totalskillcap This means that if you have 700 skill cap and you're at 697 trying to gain, you'll get almos ZERO! But if you are at 400 skills you get .5 chance to gain from this alone! Therefore, DONT GET TO SKILLCAP! The LOWER your total skills are the more chance you have to gain! Therefore, gain your HARDEST and most EXPENSIVE skills first! Magery should be done FIRST, not last "when you have $$",or it costs 4 times as much. Use some non-resource using skill like anat or spirit speak etc. for the final "top off".

c\. 25% "base skill" factor: (Specific Skill Cap - base skill ) / skillcap This obvioiusly approaches zero as your baseskill reaches it's cap, so this factor is SQUAT if you are at 99.8 and your cap is 100! You LOSE 25% of your gain chance BAM. Instead, ALWAYS increase your skill cap if able with a POWER SCROLL, EVEN IF YOU DON"T INTEND ON BOOSTING THE SKILL!! A 120ps in magery when you are at 99.7 magery or so, say, will let this be 20/120 = 17% gain chance boost!! HUGE increase.

In summary: 1. LOCK YOUR SKILLS except for your gainers, DONT hit skillcap, train most expensive/hardest skills FIRST 2. EAT a Power Scroll if at ALL possible, even if you're going to 100! 3. Always train WELL BELOW the maxskill for an item, but enough you succeed about 20-40%. As soon as you can jump up to the next "thing" or level for skill training, do so if you're near the max with the old. Example, Don't train taming on horses at 60, move up to bears, kinda thing. 4. Just slow forward instead of 8x8. At higher levels, you're probably NOT gaining .3/5min, so you could just sit dead still conceivably...

Good luck, enjoy
