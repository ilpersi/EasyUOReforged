---
title: "#SendRes"
description: "How the last send get, post, put, delete or download went: OK when the server answered, otherwise why not."
kind: variable
category: result
access: ro
type: string
origin: reforged
related: ["Send", "#SendCode", "#SendReply", "#SendHeader"]
aliases: ["send result", "http error", "web error", "no answer"]
---

`#SendRes` says how the last [`send`](/commands/send/) line of the forms `get`, `post`, `put`, `delete` and
`download` went: `OK` when the server answered, or why it didn't, in words. It reads `N/A` until the script's
first such line, and again when the script is started over. The original `send httppost` leaves it alone.

`OK` means an answer came, whatever it said: a page that doesn't exist is `OK` with
[`#SendCode`](/variables/sendcode/) `404`. Check both.

| Value | When |
|---|---|
| `OK` | The server answered. [`#SendCode`](/variables/sendcode/) has its status, [`#SendReply`](/variables/sendreply/) its body. |
| `bad url: {url}` | The address doesn't start with `http://` or `https://`, or has no server name. |
| `cannot resolve {host}` | No server has that name, or there is no internet connection. |
| `cannot connect to {host}` | The server is there but doesn't take the connection: wrong port, or it is down. |
| `timeout` | 30 seconds passed with no progress. |
| `secure connection failed: …` | An `https` server whose certificate Windows doesn't trust: expired, for another name, or self-made. Windows says why. |
| `connection lost` | The connection broke before the answer was complete. |
| `redirect refused` | The server sent the request on from `https` to plain `http`. |
| `reply over 1 MB: use send download` | The answer is too big for a variable; `#SendReply` is empty. |
| `not saved: the server answered {code}` | `download` got no file (a status outside the 200s): the old file is left as it was. |
| `cannot write {file}: …` | `download` can't write there. Windows says why. |
| `cannot create the folder {folder}` | `download`'s folder doesn't exist and can't be made. |
| `outside the program folder: {file}` | Under [`EUOCli run`](/guide/euocli/#run-a-script), `download` writes only inside its folder. |
| `no url given: …`, `no file given: …`, `get takes only a url: …` | Words are missing or too many; nothing was sent. |

When nothing was sent or no answer came, [`#SendCode`](/variables/sendcode/) is `0` and
[`#SendReply`](/variables/sendreply/) is empty. A `send` line never stops the script.

## Example

```euo
send get https://example.com/
if #SendRes <> OK
  display ok No answer: #SendRes
else
  display ok The server answered #SendCode
halt
```

## Reforged notes

`#SendRes` is new in EasyUO Reforged, with the new forms of [`send`](/commands/send/).
