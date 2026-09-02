1. start a client and open EUOUpdtr.exe
2. copy&paste the scan strings into the left editor
3. press button
4. get values in the right editor
5. copy them over to the uoclidata.pas file. It is the
only one you need to update to support a new client.

---

Notes added during the Lazarus/FPC migration
=============================================

What the scan strings can and can't cover
------------------------------------------
The scan strings only ever derive the C_* (variable addresses) and E_* (event/
hook addresses) fields you see results for above. They do NOT cover the B_*
(struct-layout byte offsets) or F_* (capability/feature flags) sections of a
version's block in uoclidata.pas -- those are, by long-standing convention,
hand-copied forward from the closest already-known version instead. That's
usually a safe assumption (these change far less often than absolute
addresses), but it's still an assumption, not a verified fact, for every new
version you add this way. If something reads wrong specifically for a stat
layout, packet-format flag, or similar, one of those copied-forward B_*/F_*
fields is the first place to look -- see uoclidata.pas's SysVar701080 comment
block for a real example (client 7.0.108.0 needed a genuinely different
B_SYSMSGSTR/F_SYSMSGDIRECT pair, discovered only via live disassembly, not by
running this tool).

The {SYSMSGSTR_CHECK} diagnostic line
--------------------------------------
"EUO Updtr Strings 6062 and newer.txt" has one line that isn't like the
others: {SYSMSGSTR_CHECK}. It's a diagnostic for exactly the B_SYSMSGSTR/
F_SYSMSGDIRECT gap above, not a value to paste straight into uoclidata.pas.
It reads back the byte-copy offset the client's "add system message" routine
uses to store message text:
  - $00000100 -> old layout: B_SYSMSGSTR=$100, F_SYSMSGDIRECT=0 (text lives
    behind a SECOND pointer at that offset).
  - $00000800 -> new layout: B_SYSMSGSTR=$800, F_SYSMSGDIRECT=1 (text is
    embedded directly at that offset, no second pointer).
  - anything else -> this struct layout has changed again; needs fresh live
    disassembly of the "add system message" routine the same way 7.0.108.0's
    did, not a guess.
Confirmed reading $00000800 (the NEW layout) on both 7.0.108.0 (live
disassembly) and 7.0.99.1 (static PE analysis of a downloaded, not-yet-run
client.exe -- these clients load at a fixed, non-relocated base, so the
on-disk section bytes match what a live process would show at the same
address, no need to actually launch an unfamiliar client just to check this).
7.0.99.1 sits in the untouched gap between the closest known older version
(7.0.47.0, whose B_SYSMSGSTR=$100 was itself never independently verified,
only carried forward by convention) and 7.0.108.0 -- so the direct-embed
layout was already in place at least that early, not something 7.0.108.0
introduced. In other words: don't treat $00000100 as the safe default anymore
just because it's what's already in the table. Nothing has actually confirmed
it correct for any real client yet; run this diagnostic for real on whatever
version you're adding rather than assuming.
