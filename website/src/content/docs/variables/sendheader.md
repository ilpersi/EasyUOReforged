---
title: "#SendHeader"
description: "Extra HTTP header lines for send; end each line with $."
kind: variable
category: result
access: rw
type: string
related: ["Send"]
aliases: ["http header"]
source: wiki
---

`#SendHeader` adds lines to the header of the HTTP request [`send`](/commands/send/) makes. End each line with
`$`. Without any `$`, nothing is added. Use `debughttppost` with `send` to see the request that goes out.

## Example

```euo
set %name Bob
set #SendHeader User-Agent: , #spc , EasyUO$
send httppost www.example.com /euo/action.php name=%name
halt
```
