# Adding support for a new UO client version

This guide has moved to the documentation site, in the **Developer guide** section:

**<https://ilpersi.github.io/EasyUOReforged/developers/>**

- [How client support works](https://ilpersi.github.io/EasyUOReforged/developers/client-tables/):
  the `C_` / `E_` / `B_` / `F_` values, fixed-base and relocatable builds, milestones, `ModernBuilds`
  and the runtime scan.
- [Add a new client](https://ilpersi.github.io/EasyUOReforged/developers/adding-a-client/): the
  workflow step by step, including where the snippet goes in `uoclidata.pas` (milestones,
  `VersionIndex`, `ModernBuilds`), the unit test and the self-test.
- [Using EUOMigrate](https://ilpersi.github.io/EasyUOReforged/developers/euomigrate/) and the
  [EUOMigrate reference](https://ilpersi.github.io/EasyUOReforged/developers/euomigrate-reference/).
- [Deriving values by hand](https://ilpersi.github.io/EasyUOReforged/developers/manual-derivation/):
  EUOUpdater, the scan-string format, `{SYSMSGSTR_CHECK}`, relocatable builds, writing signatures and
  [the buff bar](https://ilpersi.github.io/EasyUOReforged/developers/manual-derivation/#the-buff-bar).

The site's source is in [`website/`](../website/).
