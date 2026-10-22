---
title: "UOXL"
description: "Start/manage clients."
kind: command
category: client
syntax: "uoXL [{\"new\"} | {\"swap\"}]"
needsClient: true
related: ["terminate", "execute"]
source: wiki
---

The uoXL command starts and swaps between open clients. The system variables #cliNr and #cliCnt are updated accordingly.

| Option | Description              |
|--------|--------------------------|
| new    | Starts a new client      |
| swap   | Swaps to the next client |
