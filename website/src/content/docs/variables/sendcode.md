---
title: "#SendCode"
description: "The HTTP status of the last send get, post, put, delete or download: 200 for success, 0 when no answer came."
kind: variable
category: result
access: ro
type: number
origin: reforged
related: ["Send", "#SendRes", "#SendReply"]
aliases: ["http status", "status code", "404", "200"]
---

`#SendCode` is the HTTP status of the answer to the last [`send`](/commands/send/) line of the forms `get`,
`post`, `put`, `delete` and `download`: the number every web server sends first. It is `0` when no answer came
([`#SendRes`](/variables/sendres/) says why), and reads `N/A` until the script's first such line, and again when
the script is started over. The original `send httppost` leaves it alone.

| Status | Means |
|---|---|
| `200` | OK: the answer is in [`#SendReply`](/variables/sendreply/), or in the file for `download`. |
| `201`, `204` | Done: something was made, or there is nothing to send back (a Discord webhook answers `204`). |
| `400` | The server didn't understand the data. |
| `401`, `403` | Not allowed: a password or key is missing or wrong. |
| `404` | No such page. |
| `429` | Too many requests: wait before sending again. |
| `500`, `502`, `503` | Something went wrong on the server. |
| `0` | No answer: nothing was sent, or the server couldn't be reached. |

Any status the server sends counts as an answer: `#SendRes` is `OK` and `#SendReply` holds the page it sent,
often a message saying what went wrong. Redirects (`301`, `302`) are followed, so you see the status of the page
they lead to.

## Example

```euo
send get https://example.com/no-such-page
if #SendCode = 404
  display ok That page doesn't exist.
halt
```

## Reforged notes

`#SendCode` is new in EasyUO Reforged, with the new forms of [`send`](/commands/send/).
