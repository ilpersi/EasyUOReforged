---
title: "sql Close"
description: "Closes the database; an open transaction is rolled back."
kind: subcommand
category: data
syntax: "sql close"
origin: reforged
sets: ["#SqlRes", "#SqlCnt"]
related: ["sql open"]
---

`sql close` closes the script tab's database. A transaction you left open (`sql exec BEGIN` without a
`COMMIT`) is rolled back. `#SqlCnt` goes back to `0`.

You rarely need it: the connection is also closed when the script is started again, when another script is
loaded into the tab, and when the tab is closed.
