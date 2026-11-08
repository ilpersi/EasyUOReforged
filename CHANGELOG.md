# Changelog

What changes for script users in each release of EasyUO Reforged. New entries go under **Unreleased**; `tools/release.ps1` turns that section into the next version's, and the release page on GitHub shows it. Keep each entry on one line, because the release page shows every line break. Everything Reforged adds to EasyUO 1.5 is listed by topic on [What's new in Reforged](https://ilpersi.github.io/EasyUOReforged/reforged/whats-new/).

## Unreleased

### Added

- **`str replace`, `part`, `trim`, `join` and `concat`: work on text without hand-written loops.** `str replace %s _ #SPC` replaces every `_`, or removes it if you leave out what to replace it with. `str part 1_50_00 _ 2` takes the second field (`50`), and a `for` with `str count` goes through all of them. `str trim %s` removes spaces and `_` from both ends, or the characters you name. `str join _ %a %b %c` and `str concat %a %b` put texts together. See [`str`](https://ilpersi.github.io/EasyUOReforged/commands/str/), including how spaces differ between `#Journal` and `#Property`.
- **`findjournal`: search the journal in one line.** For example `findjournal %j * 3s fizzles you_must_wait` looks through every line since you saved `#JIndex` in `%j`, in any colour, for either text, and waits up to 3 seconds. Give a colour instead of `*` to match only lines of that colour, or `*` as the text to match any line. [`#JFound`](https://ilpersi.github.io/EasyUOReforged/variables/jfound/) gives the line's number, and `#Journal` and `#JColor` hold the line, so nothing is missed when lines arrive together and `deletejournal` isn't needed. See [`findjournal`](https://ilpersi.github.io/EasyUOReforged/commands/findjournal/).
- **`waitfor`: wait until a condition is true, or give up after a timeout.** For example `waitfor #ContName = generic_gump 5s`. The condition works like `if`, including `&&`, `||` and nested parentheses, so one line can replace a hand-written polling loop. [`#WaitRes`](https://ilpersi.github.io/EasyUOReforged/variables/waitres/) then says which happened: `#true` if the condition was met, `#false` on timeout. Pressing Pause doesn't use up the timeout, and Stop ends the wait at once. See [`waitfor`](https://ilpersi.github.io/EasyUOReforged/commands/waitfor/).
- **A filter box above the variable inspector**: type part of a name, such as `hits`, and only the matching variables stay in the tree. It takes regular expressions too, like the Find window: `^max` keeps the names that start with `Max`. Esc clears it. See [Your first script](https://ilpersi.github.io/EasyUOReforged/guide/first-script/#the-window).
- **Ctrl+click a sub or label name to jump to it**: hold Ctrl over the name after `gosub` or `goto`, it underlines, and a click takes you to its `sub` line or its `label:` line. **Alt+Left** (*Edit → Go Back*) returns to where you clicked. The jump goes where the script would: to the last `sub` of that name, and to the nearest label, the one below first. A name held in a variable is not a link. See [Editor features](https://ilpersi.github.io/EasyUOReforged/guide/debugging/#editor-features).

### Changed

- **New toolbar and menu icons**, in the same outline style as the MENU Designer, and every toolbar button now shows its name under the icon. Start is green, Pause orange, and Stop and Stop All red, so the script controls stand out; a toolbar button that is switched off turns one even grey. The buttons, their order and their tooltips are unchanged. New Client and Swap To Next Client are now window icons instead of the *CLI NEW* and *CLI SWAP* lettering. See [Your first script](https://ilpersi.github.io/EasyUOReforged/guide/first-script/#the-window).
- **A new application icon**, for the taskbar, the title bar and the executables of EasyUO Reforged and the MENU Designer: the original emblem, glowing on an anvil. It now comes in sizes from 16 to 256 pixels, so it stays sharp instead of being rescaled from one small image.
- **One Find/Replace toolbar button instead of two**: the Find and Replace buttons opened the same window, so they are now a single button. *Edit → Find…* (Ctrl+F) and *Edit → Replace…* (Ctrl+H) are unchanged. See [Find and replace](https://ilpersi.github.io/EasyUOReforged/guide/debugging/#find-and-replace).
- **The Website button** (and *Help → Website*) now opens the [EasyUO Reforged project page](https://github.com/ilpersi/EasyUOReforged) instead of easyuo.com.
- **The variable inspector is regrouped.** Its groups are now the same as the [variable reference](https://ilpersi.github.io/EasyUOReforged/variables/) on the site, and the groups and the variables inside them are in alphabetical order. *Extended Info* and *Miscellaneous* are split into *Cursor & targeting*, *Journal & messages*, *Script*, *Skills* and *Time*. *Status bar* keeps the variables read from the status bar. `#ContSize` and `#CurPath` are now shown too.
- The inspector remembers which groups you left open by their names, so adding a group no longer opens the wrong ones. The groups you had open before this version start closed once.
- `uo.dll`'s [`GetItem`](https://ilpersi.github.io/EasyUOReforged/dll/getitem/) returns the item's equip layer as an 11th value, after its usual ten: the same number as `#FindLayer`, or 0 when nobody wears the item. The separate `GetItemLayer` call that v26.11.02 added is gone; read the layer from `GetItem` instead.

### Fixed

- **The editor colors commands, `#variables` and operators however you write them**: `halt` is now bold like `HALT`, and `#charPosX` is colored like `#CHARPOSX`, as the language itself ignores case.
- **A menu button shows its new caption right away**: after [`menu Set`](https://ilpersi.github.io/EasyUOReforged/commands/menu/set/), or [`menu SetProp`](https://ilpersi.github.io/EasyUOReforged/commands/menu/setprop/) `text` in a 1.6 menu, the button kept showing its old caption until you clicked it or something covered the window.
- **The Reopen toolbar button lists your recent scripts again**: clicking it did nothing; it now drops down the last opened scripts, as in EasyUO 1.5, and picking one opens it.

## v26.11.02 - 2026-11-02

### Added

- **The MENU Designer** (`EUOMenuDesigner.exe`, in the zip): lay out EasyUO 1.6 `menu` windows by drawing them, preview them, and turn them into script lines, or read an existing script's window back in. See [The MENU Designer](https://ilpersi.github.io/EasyUOReforged/designer/).
- **`#MountID`** and **`#MountType`**: the ID and type of the mount your character rides, `N/A` on foot. `uo.dll` gets `MountID` and `MountType` to match.
- **`#FindLayer`**: the layer a character wears the object `FindItem` selected in. `uo.dll` gets `GetItemLayer`.

### Changed

- `path` walking on a mount sends steps fast enough for a full-speed run. The [Running](https://ilpersi.github.io/EasyUOReforged/commands/path/#running) section explains when the client walks and when it runs.
- `FindItem` also fills `#FindLayer`; nothing else it does has changed.
- [`#BuffBarOpen`](https://ilpersi.github.io/EasyUOReforged/variables/buffbaropen/) is `#true` (`-1`) when the buff bar is open, where it used to be `1`, so it can be compared with `#true` and `#false`. A script that compares it with `1` must compare it with `#true` now.
- `uo.dll`'s [`GetBuff`](https://ilpersi.github.io/EasyUOReforged/dll/getbuff/) returns the seconds a buff has left at the moment it is called, like `#BuffTime`, instead of the seconds it had when `ScanBuffs` ran.
- The [`#CharStatus`](https://ilpersi.github.io/EasyUOReforged/variables/charstatus/) page now explains every letter, and how to tell poison from a yellow health bar.

### Fixed

## v26.10.29

Earlier releases have no entries here: see the [GitHub Releases](https://github.com/ilpersi/EasyUOReforged/releases) page.
