# Changelog

What changes for script users in each release of EasyUO Reforged. New entries go under **Unreleased**; `tools/release.ps1` turns that section into the next version's, and the release page on GitHub shows it. Keep each entry on one line, because the release page shows every line break. Everything Reforged adds to EasyUO 1.5 is listed by topic on [What's new in Reforged](https://ilpersi.github.io/EasyUOReforged/reforged/whats-new/).

## Unreleased

### Added

- **A filter box above the variable inspector**: type part of a name, such as `hits`, and only the matching variables stay in the tree. It takes regular expressions too, like the Find window: `^max` keeps the names that start with `Max`. Esc clears it. See [Your first script](https://ilpersi.github.io/EasyUOReforged/guide/first-script/#the-window).
- **Ctrl+click a sub or label name to jump to it**: hold Ctrl over the name after `gosub` or `goto`, it underlines, and a click takes you to its `sub` line or its `label:` line. **Alt+Left** (*Edit → Go Back*) returns to where you clicked. The jump goes where the script would: to the last `sub` of that name, and to the nearest label, the one below first. A name held in a variable is not a link. See [Editor features](https://ilpersi.github.io/EasyUOReforged/guide/debugging/#editor-features).

### Changed

- **New toolbar and menu icons**, in the same outline style as the MENU Designer, and every toolbar button now shows its name under the icon. Start is green, Pause orange, and Stop and Stop All red, so the script controls stand out; a toolbar button that is switched off turns one even grey. The buttons, their order and their tooltips are unchanged. New Client and Swap To Next Client are now window icons instead of the *CLI NEW* and *CLI SWAP* lettering. See [Your first script](https://ilpersi.github.io/EasyUOReforged/guide/first-script/#the-window).
- **A new application icon**, for the taskbar, the title bar and the executables of EasyUO Reforged and the MENU Designer: the original emblem, glowing on an anvil. It now comes in sizes from 16 to 256 pixels, so it stays sharp instead of being rescaled from one small image.
- **The Website button** (and *Help → Website*) now opens the [EasyUO Reforged project page](https://github.com/ilpersi/EasyUOReforged) instead of easyuo.com.
- **The variable inspector is regrouped.** Its groups are now the same as the [variable reference](https://ilpersi.github.io/EasyUOReforged/variables/) on the site, and the groups and the variables inside them are in alphabetical order. *Extended Info* and *Miscellaneous* are split into *Cursor & targeting*, *Journal & messages*, *Script*, *Skills* and *Time*. *Status bar* keeps the variables read from the status bar. `#ContSize` and `#CurPath` are now shown too.
- The inspector remembers which groups you left open by their names, so adding a group no longer opens the wrong ones. The groups you had open before this version start closed once.
- `uo.dll`'s [`GetItem`](https://ilpersi.github.io/EasyUOReforged/dll/getitem/) returns the item's equip layer as an 11th value, after its usual ten: the same number as `#FindLayer`, or 0 when nobody wears the item. The separate `GetItemLayer` call that v26.11.02 added is gone; read the layer from `GetItem` instead.

### Fixed

- **The editor colors commands, `#variables` and operators however you write them**: `halt` is now bold like `HALT`, and `#charPosX` is colored like `#CHARPOSX`, as the language itself ignores case.

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
