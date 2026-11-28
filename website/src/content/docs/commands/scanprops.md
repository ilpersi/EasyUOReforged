---
title: ScanProps
description: "Reads the property tooltip of every item the last finditem found, in one go, for #FindProp."
kind: command
category: client
syntax: scanprops
origin: reforged
needsClient: true
sets: ['#FindProp']
related: ['#FindProp', 'FindItem', 'event Property', '#Property', 'dll:ScanProps', 'dll:GetItem']
dll: ScanProps
aliases: ['properties', 'property', 'tooltip', 'tooltips', 'item properties', 'many items']
---

`ScanProps` reads the property tooltip of every item the last [`FindItem`](/commands/finditem/) found,
all at once. Then [`#FindProp`](/variables/findprop/) shows the text of the item at the current
[`#FindIndex`](/variables/findindex/), in the same format as [`#Property`](/variables/property/).

[`event Property`](/commands/event/property/) asks the client for one item at a time and waits for the
client's next pass each time, so a loop over many items takes a while. The client already keeps every
tooltip it has fetched; `ScanProps` reads them all from there and puts the text together the way the
client does. On a live shard, the 1,175 objects a client knew took under a second this way, against
82 seconds for an `event property` per object.

```euo
finditem * C_ , #BackpackID
scanprops
if #FindCnt > 0
{
  for #FindIndex 1 #FindCnt
  {
    if Exceptional in #FindProp
      log #FindID #FindProp
  }
}
halt
```

## Parameters

None. `ScanProps` reads the items of the last `FindItem`, the same list `#FindIndex` walks through, in the
same order. Items hidden with [`IgnoreItem`](/commands/ignoreitem/) are not in that list.

## Reading the results

`#FindProp` follows `#FindIndex` like [`#FindID`](/variables/findid/): set `#FindIndex`, read
`#FindProp`. It reads `N/A` for an item the last `ScanProps` didn't read: nothing found, an index out of
range, or a `FindItem` since then that found other items.

The text is what the client had when `ScanProps` ran. Run it again to see a changed item (a charge used, a
stack split). `ScanProps` changes nothing else: `#Property`, `#FindIndex` and the other `#Find…`
values stay as they were.

## Items without a tooltip yet

The client fetches a tooltip from the shard when it first needs it, so an item seen for the first time
may have none yet. `ScanProps` asks the shard for all such items at once, the same way the client does.
Then it waits as long as answers keep coming, and stops once a second passes with no new answer, or
after 15 seconds in any case. When the only items left are ones the client had nothing at all for, it
waits half a second instead: the shard never answers for an object without properties. An item that still has no tooltip then reads `$`, as
`#Property` does when `event Property` gets no answer; run `ScanProps` again later.

An item the client has nothing at all for, not even a request in progress, gets one `event Property`
after the wait on the fixed-base clients (`client.exe`). Those clients then name it from the object
itself, as `event Property` does. On the relocated betas (`client_beta.exe`), `event Property` would only
ask the shard again and give `$`, so `ScanProps` stores `$` directly.

## Compare the speed

This script times both ways on the items in your backpack: first one `event property` per item, then one
`scanprops` for all of them. The Output panel shows the two times.

```euo
finditem * C_ , #BackpackID
set %n #FindCnt
if %n > 0
{
  timer start each
  for #FindIndex 1 %n
    event property #FindID
  timer elapsed each
  set %each #TimerRes
  timer start all
  scanprops
  timer elapsed all
  log %n items: event property %each ms, scanprops #TimerRes ms
}
halt
```

On a local shard, 26 items took 1,437 ms with `event property` and under 1 ms with `scanprops`. Items
whose tooltip the client hasn't fetched yet make `scanprops` wait for the shard's answer, so the first
scan of new items can take longer than the next one.

## Notes

- When the shard answers for an item the client had nothing for, `#FindProp` holds the full tooltip
  the shard sent, where `event Property` would have given the object's name only.
- Players can write their own words into items (a book's title, an engraving, a pet's name).
  The client masks swear words in that text with its word filter; `#FindProp` shows the words as
  they are.
- A client set to show English tooltips while its language is another one shows the English text;
  `#FindProp` shows the client language's text.
- The tooltip text is put together as `client.exe` 7.0.108.0 and newer and the betas do it. On older
  clients the text can differ in small ways from what they show: 7.0.29.97 and 7.0.45.89, for one, don't
  capitalise a word after `>`.
- On a client where `ScanProps` can't find the tooltip cache, every item gets one `event Property`:
  the same text, at the speed of an `event Property` loop.
- Like `FindItem`, it does nothing without a client: `#FindProp` then reads `N/A`.

## Reforged notes

New in EasyUO Reforged. A line starting with the word `scanprops` used to be ignored. Its uo.dll method
is [`ScanProps`](/dll/scanprops/); after it, [`GetItem`](/dll/getitem/) returns each stored item's text
as a 12th value. How the cache is read is described in the repository's
`docs/property-cache-analysis.md`.
