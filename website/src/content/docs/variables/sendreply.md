---
title: "#SendReply"
description: "What the server sent back to the last send get, post, put or delete, byte for byte."
kind: variable
category: result
access: ro
type: string
origin: reforged
related: ["Send", "#SendRes", "#SendCode", "Str"]
aliases: ["send reply", "http reply", "web page text", "response body"]
---

`#SendReply` holds what the server sent back to the last [`send`](/commands/send/) line of the forms `get`,
`post`, `put` and `delete`: the page or the data, byte for byte, its line breaks included. It reads `N/A`
until the script's first such line, and again when the script is started over. The original
`send httppost` leaves it alone: it runs its reply instead.

- After `download`, it is empty when the file was saved; when it wasn't, it holds what the server sent instead,
  such as its error page.
- When no answer came, or the answer was over 1 MB, it is empty: [`#SendRes`](/variables/sendres/) says why.
- Nothing in it is run. Take it apart with [`str`](/commands/str/): `str pos`, `str part`, `str mid`.

## Example

A page that answers a line such as `price=1200;stock=8`:

```euo
send get https://example.com/euo/price.txt
if #SendCode <> 200
  halt
str part #SendReply price= 2
str part #StrRes #SMC 1
set %price #StrRes
display ok The price is %price
halt
```

## Reforged notes

`#SendReply` is new in EasyUO Reforged, with the new forms of [`send`](/commands/send/).
