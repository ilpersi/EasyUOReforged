---
title: "#Random"
description: "Holds a random number."
kind: variable
category: misc
access: ro
type: number
source: wiki
---

Holds a changing random value that ranges between 0 and 999.

## Example

```euo
;make a random number between 0 and 99.
set %a #random % 100

;make a random number between a range of two numbers
;set %random1 #random % %increments + #bottom
;%increments is (top# - bottom#) + 1
;#top is the highest number of the range
;#bottom is the lowest number of the range
;example of two random numbers between 3 and 10
set %random1 #random % 8 + 3
```
