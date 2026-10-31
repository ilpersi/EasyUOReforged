---
title: The MENU Designer's code
description: "How the MENU Designer is built, and how to add a new MENU 1.6 control type to it."
sidebar:
  order: 8
---

The [MENU Designer](/designer/) is `EUOMenuDesigner.lpi`, with its sources in `tools/EUOMenuDesigner/`. Its
plan and rules are in `docs/menu-designer.md` in the repository.

## How it is built

It reuses the interpreter's own MENU code instead of a copy of its rules:

- **The canvas, the Preview and the importer all run a real `TMenu16`** (`parser/EuoMenu16.pas`, the 1.6
  MENU logic). The canvas runs each form's generated sub and hosts the form's surface in its tab; the
  importer runs a loaded script's `menu` lines in a hidden `TMenu16` and reads every control back with
  `getprop`.
- **Lines are read with the interpreter's code:** `parser/EuoScriptWords.pas` (the `+` continuation, the
  `.`/`,` glue, `IsVar`), which `TEuoInterpreter.ParseLine` calls too, and `EuoMenuSelect.SplitScriptLine`.
- **The model, the generator, the importer and the files** (`mdmodel`, `mdgenerate`, `mdimport`,
  `mdfile`) have no window of their own, so the test suite runs them (`tests/MenuDesigner*Tests.pas`).
- **The control types are a table**, `MdTypeRows` in `mdtypes.pas`: the palette, the inspector, the
  generator and the importer go by it, and the properties of each type come from `TMenu16`'s own table.

## Adding a control type

When the 1.6 MENU logic gets a new control type (an `MT_*` constant in `EuoMenu16.pas`), the designer gets it
in the same change. `tests/tools/CheckDocsCoverage.ps1`, which `run_tests.ps1` and CI run, fails until it
does:

1. **A row in `MdTypeRows`** (`mdtypes.pas`): its name, its `MT_*` kind, its creating line, how its sizes
   reach the script, its default size and its quirk flags. A new value in `TMdType` names it.
2. **The generator** (`mdgenerate.pas`): anything its creating line cannot say, in `AfterCreate`.
3. **The importer** (`mdimport.pas`): its creating line in `ReadLine`, and what the windows cannot tell
   afterwards (as for shapes and drawings) noted beside the replay.
4. **The inspector** (`mdinspector.pas`) and **the model** (`mdmodel.pas`), if it has values no other type
   has.
5. **Tests:** its lines in `MenuDesignerGenerateTests`, its reading in `MenuDesignerImportTests`; the parity
   and round-trip tests cover it once it is in the rich document of `MenuDesignerRoundTripTests`.
6. **Its section** `## <name>` on [designer/components](/designer/components/).

A new property of `TMenu16`'s table gets a row in `MdProps`, and a new sub-command goes in one of
`MdSubsWritten`, `MdSubsRead` or `MdSubsRuntime`. Whatever is left out on purpose goes in `MdExcluded`, with
the reason as a comment. The 1.5 MENU logic does not count: the designer is for 1.6 only.
