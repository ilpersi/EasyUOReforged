# Changelog

What changes for script users in each release of EasyUO Reforged. New entries go under
**Unreleased**; `tools/release.ps1` turns that section into the next version's, and the release
page on GitHub shows it. Everything Reforged adds to EasyUO 1.5 is listed by topic on
[What's new in Reforged](https://ilpersi.github.io/EasyUOReforged/reforged/whats-new/).

## Unreleased

### Added

- **The MENU Designer** (`EUOMenuDesigner.exe`, in the zip): lay out EasyUO 1.6 `menu` windows by
  drawing them, preview them, and turn them into script lines, or read an existing script's window
  back in. See [The MENU Designer](https://ilpersi.github.io/EasyUOReforged/designer/).
- **`#MountID`** and **`#MountType`**: the ID and type of the mount your character rides, `N/A` on
  foot. `uo.dll` gets `MountID` and `MountType` to match.
- **`#FindLayer`**: the layer a character wears the object `FindItem` selected in. `uo.dll` gets
  `GetItemLayer`.

### Changed

- `path` walking on a mount sends steps fast enough for a full-speed run. The
  [Running](https://ilpersi.github.io/EasyUOReforged/commands/path/#running) section explains when
  the client walks and when it runs.
- `FindItem` also fills `#FindLayer`; nothing else it does has changed.
- The [`#CharStatus`](https://ilpersi.github.io/EasyUOReforged/variables/charstatus/) page now
  explains every letter, and how to tell poison from a yellow health bar.

### Fixed

## v26.10.29

Earlier releases have no entries here: see the
[GitHub Releases](https://github.com/ilpersi/EasyUOReforged/releases) page.
