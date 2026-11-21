---
title: "#SendHeader"
description: "Extra HTTP header lines for send; end each line with $."
kind: variable
category: script
access: rw
type: string
changed: true
related: ["Send", "#SendRes"]
aliases: ["http header", "content-type", "user-agent", "api key header"]
source: wiki
---

`#SendHeader` adds lines to the header of the HTTP requests [`send`](/commands/send/) makes, every form of it.
Separate the lines with `$`; a `$` at the end does no harm. Use `debughttppost` with `send` to see the request
that the original form sends. EasyUO 1.5 has `#SendHeader` too, for `send httppost`, its only form.

A line is a name, a colon and a value, such as `Content-Type: application/json`. Since a space ends a word,
glue the parts with [`#SPC`](/variables/spc/): `set #SendHeader Content-Type: , #SPC , application/json$`.
The value stays for every `send` that follows, until the script sets another.

- **`httppost`** (EasyUO 1.5 and Reforged): the text goes out as it is, `$` turned into line breaks. Leave it
  empty and the request gets a blank line too many before the data, which the server then misreads: set at least
  a `Content-Type` line.
- **`get`, `post`, `put`, `delete`, `download`** (new in Reforged): a line without a colon is left out, so `N/A`
  sends nothing. A `Content-Type` line replaces the form type data goes as; a `User-Agent` line replaces the
  name `EasyUO Reforged`.

## Examples

For EasyUO 1.5 and Reforged:

```euo
set %name Bob
set #SendHeader Content-Type: , #SPC , application/x-www-form-urlencoded$
send httppost www.example.com /euo/action.php name= , %name
halt
```

Reforged only, with a second line:

```euo
set %name Bob
set #SendHeader Content-Type: , #SPC , application/x-www-form-urlencoded$X-Script: , #SPC , mine$
send post https://example.com/euo/action.php name= , %name
display ok #SendCode
halt
```

Words are only read as variables when they stand alone: `name=%name` sends the text `%name`. Glue a value on
with `,` as above.

## Reforged notes

- `#SendHeader` also applies to the new forms of `send`, which leave out a line without a colon.
- For the original `httppost` form nothing has changed. This page used to say that a value without `$` adds
  nothing: in fact it goes out as one line.
