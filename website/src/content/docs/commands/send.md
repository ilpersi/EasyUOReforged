---
title: "Send"
description: "Talks to a web server: get, post, put, delete and download (new in Reforged, HTTP or HTTPS) keep the answer; httppost, the only form EasyUO 1.5 has, runs the reply as a script."
kind: command
category: misc
changed: true
syntax: "send {get|post|put|delete|download} {url} [data|file]\nsend [debug]httppost[port] {host} {path} {data}"
sets: ["#SendRes", "#SendCode", "#SendReply"]
related: ["#SendHeader", "#SendRes", "#SendCode", "#SendReply", "Str", "Call", "Execute", "SQL"]
aliases: ["http", "https", "web request", "post", "get", "download", "webhook", "discord", "rest api", "url", "web page"]
source: wiki
---

`send` talks to a web server. It has two kinds of forms:

- **`get`, `post`, `put`, `delete` and `download`** (new in Reforged) send a request over HTTP or HTTPS and
  keep the answer: its body in [`#SendReply`](/variables/sendreply/), or in a file for `download`, its HTTP
  status in [`#SendCode`](/variables/sendcode/), and whether it worked in [`#SendRes`](/variables/sendres/).
  **The answer is never run.**
- **`httppost`**, EasyUO's original form and the only one EasyUO 1.5 has, posts over plain HTTP and **runs
  the server's reply as an EasyUO script**. It works exactly as in EasyUO 1.5: see
  [below](#the-original-form-httppost).

## Parameters

| Form | What it does | EasyUO 1.5 |
|---|---|---|
| `send get {url}` | Asks for the page at `url`. Data goes in the URL's query: `?name=value&other=value`. | **No:** new in Reforged |
| `send post {url} {data}` | Sends `data` to `url`, as a web form does. `data` is the rest of the line. | **No:** new in Reforged |
| `send put {url} {data}` | The same with the PUT method, for web services that ask for it. | **No:** new in Reforged |
| `send delete {url} [data]` | The DELETE method, for web services that ask for it. | **No:** new in Reforged |
| `send download {url} {file}` | Saves the page at `url` to `file`: a name relative to [`#CurPath`](/variables/curpath/), or a full path. | **No:** new in Reforged |
| `send [debug]httppost[port] {host} {path} {data}` | Posts over plain HTTP and runs the reply as a script: see [below](#the-original-form-httppost). | Yes |

:::note[Writing for EasyUO 1.5 too]
`get`, `post`, `put`, `delete` and `download` are new in EasyUO Reforged, and so are the variables they set
([`#SendRes`](/variables/sendres/), [`#SendCode`](/variables/sendcode/), [`#SendReply`](/variables/sendreply/))
and [`str urlencode` / `str jsonescape`](/commands/str/#encode-for-send-reforged). EasyUO 1.5 knows only
`httppost`: there, a `send` line with any other word does nothing, with no error, and the three variables read
`N/A`. A script that must also run on EasyUO 1.5 uses only `send httppost`, sets
[`#SendHeader`](/variables/sendheader/), and needs a server that answers in EasyUO script over plain `http`,
since the reply is run and nothing else tells the script what came back. To use the new forms where they exist,
test [`#ReforgedVer`](/variables/reforgedver/): it reads `N/A` in EasyUO 1.5.
:::

`url` starts with `http://` or `https://` and may have a port (`http://myhost:8080/x`) and a query, as you
copy it from a browser. `data` is everything after the URL, its words joined by one space: build it with `,`,
and pass values that may hold spaces, `&`, `=` or quotes through [`str urlencode`](/commands/str/#encode-for-send-reforged)
(form data) or [`str jsonescape`](/commands/str/#encode-for-send-reforged) (JSON) first.

## How the new forms work (Reforged)

- The script waits until the answer has come, or until 30 seconds pass with no progress. Stop and Pause work
  while it waits, and the variables window keeps updating.
- Then [`#SendRes`](/variables/sendres/) is `OK` when the server answered, whatever it answered, or says why
  not; [`#SendCode`](/variables/sendcode/) is the HTTP status (`200` is success, `404` not found, `500` an
  error on the server), or `0` when no answer came; [`#SendReply`](/variables/sendreply/) holds the body, byte
  for byte, up to 1 MB. A bigger answer is refused: use `download` for it.
- [`#SendHeader`](/variables/sendheader/) adds header lines, as for the original form. Without a `Content-Type`
  line, data goes as a web form (`application/x-www-form-urlencoded`), which PHP and most servers read; for
  JSON, set `Content-Type: application/json$`. EasyUO Reforged names itself `EasyUO Reforged` to the server
  unless a `User-Agent` line says otherwise.
- Redirects are followed, except from `https` to `http`. A proxy set for Windows' web service
  (`netsh winhttp set proxy`) is used; the browser's proxy settings are not.
- `download` replaces the file only when the status is in the 200s and the whole file arrived. Otherwise the old
  file stays as it was, and `#SendReply` holds what the server sent instead (its error page). Folders in the name
  are made.
- A `send` line never stops the script: check `#SendRes` and `#SendCode` after it.

:::caution[A web address can be a password]
A webhook address or an API key written in a script works for whoever reads the script. Don't share a script
that has one in it.
:::

## Examples (Reforged)

These use the new forms, so they need EasyUO Reforged. For a script that must also run on EasyUO 1.5, see
[the original form](#the-original-form-httppost) and its [example for both](#a-script-for-both).

### Ask a web page whether the script may run

```euo
send get https://example.com/myscript/status.txt
if #SendRes <> OK
{
  display ok No answer from the server: #SendRes
  halt
}
if #SendCode <> 200
{
  display ok The server answered #SendCode
  halt
}
str pos #SendReply stop
if #StrRes > 0
{
  display ok The author asks you not to run the script today.
  halt
}
display ok All clear.
halt
```

### Post to a Discord webhook

The webhook's address is in the channel's settings, under *Integrations*, *Webhooks*.

```euo
set %hook https://discord.com/api/webhooks/123/abc   ; your webhook's address
set %text #CharName , #SPC , is at , #SPC , #CharPosX , #SPC , #CharPosY
str jsonescape %text
set %body {"content":" , #StrRes , "}
set #SendHeader Content-Type: , #SPC , application/json$
send post %hook %body
if #SendCode <> 204
  display ok Discord answered #SendCode #SendRes
halt
```

### Send form data

To your own page, with a name that may hold spaces:

```euo
str urlencode #CharName
set %data name= , #StrRes , &gold= , #Gold
send post https://example.com/euo/report.php %data
display ok #SendCode #SendReply
halt
```

### Download a script, then run it

Fetch the newest copy of a helper script:

```euo
send download https://example.com/euo/helpers.euo helpers.euo
if #SendRes <> OK
  display ok Kept the old helpers.euo: #SendRes
call helpers.euo
halt
```

A downloaded script runs with all the rights of a script, as the `httppost` reply does: download only from a
server you control or trust completely.

## The original form: `httppost`

**This form works in EasyUO 1.5 and in Reforged alike**: it is the one to use in a script that must run on both.

`send httppost` sends an HTTP POST request and **runs the server's reply as an EasyUO script**, as if it had been
started with [`call`](/commands/call/): when it ends, the script goes on after the `send`.

| Parameter | Meaning |
|---|---|
| `httppost` | Send to port 80. Add a port number to use another one: `httppost8080`. Put `debug` in front (`debughttppost`) to see the request and the reply in two message boxes. |
| `host` | The server, such as `www.example.com`. |
| `path` | The page, such as `/euo/action.php`. |
| `data` | The form data, such as `name=value&other=value`. |

[`#SendHeader`](/variables/sendheader/) adds lines to the request's header. The script waits until the server
has sent the whole reply and closed the connection, and Stop can't interrupt that wait. An empty reply runs
nothing.

The request is the one EasyUO 1.5 made: plain HTTP 1.0, so a server that only answers `https` can't be reached,
and nothing tells the script how it went. With an empty `#SendHeader` the request has one blank line too many
before the data, so the server reads the wrong bytes. Old scripts set `#SendHeader` (PHP needs its
`Content-Type` line anyway), so set it too: `set #SendHeader Content-Type: , #SPC , application/x-www-form-urlencoded$`.

:::danger[The reply runs as a script]
Whatever the server sends back is run with all the rights of a script: it can read your variables, move your
character and use [`execute`](/commands/execute/). Only send to a server you control or trust completely.
There is no setting to turn `send` off in the editor. To keep a reply without running it, use `send post`
(Reforged only).
:::

```euo
set %nick Bob
set %text Hello
set %data nick= , %nick , &text= , %text
set #SendHeader Content-Type: , #SPC , application/x-www-form-urlencoded$
send httppost www.example.com /euo/chat.php %data
halt
```

### A script for both

[`#ReforgedVer`](/variables/reforgedver/) reads `N/A` in EasyUO 1.5, so a script can use `send httppost` there and
`send post` in Reforged, where it can also see whether the data arrived. A page that answers with nothing works for
both: an empty reply runs nothing.

```euo
set %data name=Bob&gold= , #Gold
set #SendHeader Content-Type: , #SPC , application/x-www-form-urlencoded$
if #ReforgedVer = N/A
{
  send httppost www.example.com /euo/report.php %data   ; EasyUO 1.5: no way to know how it went
  halt
}
send post http://www.example.com/euo/report.php %data
if #SendCode <> 200
  display ok Not sent: #SendRes #SendCode
halt
```

EasyUO 1.5 has no `str urlencode`, so in a script for both keep the values to letters, digits and `-_.~`: a space,
`&` or `=` in a value breaks the form data.

## Reforged notes

- `get`, `post`, `put`, `delete` and `download` are new, with [`#SendRes`](/variables/sendres/),
  [`#SendCode`](/variables/sendcode/) and [`#SendReply`](/variables/sendreply/). In EasyUO 1.5 a `send` line with
  any of these words did nothing.
- The original `httppost` form is unchanged, byte for byte: the same request, the reply still runs, and it leaves
  the three new variables alone.
- Under [`EUOCli run`](/guide/euocli/#run-a-script) every form of `send` is blocked unless `--allow send`; even
  then `download` writes only inside the program folder unless `--allow logfile` too.
