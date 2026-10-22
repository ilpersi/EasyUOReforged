---
title: "#EUOVer"
description: "Returns the current EasyUO version."
kind: variable
category: misc
access: ro
type: string
related: ["#ReforgedVer"]
source: wiki
---

The #euoVer system variable displays the version information of the currently executing EasyUO program. The format is as follows: (MAJOR)\_(MINOR)\_(BUILD).

## Example

```euo
;Checks to make sure the correct version of EUO is used for your script requirements.
;#euo = 1_40_88 ,which is version 1.40 (build 0058)  58 hex = 88 dec
set %euoBuildRequired  $ , 58
set %euoVersionRequired 1_40
str Left #euoVer 4
set %euover #strRes
str Right #euover 2
set %euoBuild #strRes
if  %euoVer <> %euoVersionRequired || %euoBuild < %euoBuildRequired
{
   display ok This program requires EUO version 1.4 (build 0058) or higher in order$
+ to work. Download the latest version from www.easyuo.com.$
   halt
}
```

## Reforged notes

EasyUO Reforged returns `1_50_00` here, the value of the EasyUO version it is ported from, so existing
version checks keep working. Its own build version is in [`#ReforgedVer`](/variables/reforgedver/).
