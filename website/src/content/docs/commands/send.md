---
title: "Send"
description: "Sends a HTTP request to a server and runs the code that is returned."
kind: command
category: misc
syntax: "send {{\"HTTPPost[port]\"}}}  {site} {path} {post data}"
source: wiki
---

The [send](/commands/send/) command sends a HTTP request to a web server and executes the code that is returned.

:::note
Allow Send must be enabled for this command to work.
:::

## Example

```euo
;******************************
; EUO Chat V1.0 by Cheffe
;******************************
;
; Allow send must be enabled!!!

menu Clear
menu Window Size 245 120
menu Window Title EUO Chat V1.0
menu Show 200 200
menu HideEUO

menu Text 1 20 20 Please enter your nickname:
menu Font BGColor White
menu Edit 2 20 40 200
menu Font BGColor BtnFace
menu Button 3 130 70 90 25 OK

set #menuButton 0
N1:
    if #menuButton = closed
        halt
    if #menuButton <> 3
goto N1

menu Get 2
set %nickname #menuRes

;******************************

menu Clear
menu Window Size 500 230
menu Font BGColor White
menu Edit e1 20 180 360
menu Font BGColor BtnFace
menu Button b1 400 180 80 25 Send!

set #menuButton 0
N2:
    N3:
        if #scnt2 > 30
        {
            send HTTPPost www.easyuo.com /webscripts/euochat.pl R
            set #scnt2 0
        }

        if #menuButton = CLOSED
            halt

        if #menuButton <> b1
    goto N3
    set #menuButton 0

    menu Get e1
    send HTTPPost www.easyuo.com /webscripts/euochat.pl S %nickname , : #menuRes
    menu Activate e1

goto N2
```
