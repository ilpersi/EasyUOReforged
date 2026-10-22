---
title: "Send"
description: "Sends an HTTP POST request and runs the reply as an EasyUO script."
kind: command
category: misc
syntax: "send [debug]httppost[port] {host} {path} {data}"
related: ["#SendHeader", "Call", "Execute", "SQL"]
aliases: ["http", "web request", "post"]
source: wiki
---

`send` sends an HTTP POST request to a web server. **The server's reply is then run as an EasyUO script**,
as if it had been started with [`call`](/commands/call/): when it ends, the script goes on after the
`send`.

## Parameters

| Parameter | Meaning |
|---|---|
| `httppost` | Send to port 80. Add a port number to use another one: `httppost8080`. Put `debug` in front (`debughttppost`) to see the request and the reply in two message boxes. |
| `host` | The server, such as `www.example.com`. |
| `path` | The page, such as `/euo/action.php`. |
| `data` | The form data, such as `name=value&other=value`. |

[`#SendHeader`](/variables/sendheader/) adds lines to the request's header. The script waits until the reply
has arrived. An empty reply runs nothing.

:::danger[The reply runs as a script]
Whatever the server sends back is run with all the rights of a script: it can read your variables, move your
character and use [`execute`](/commands/execute/). Only send to a server you control or trust completely.
There is no setting to turn `send` off.
:::

## Example

```euo
send httppost www.example.com /euo/chat.php nick=%nick&text=%text
```
