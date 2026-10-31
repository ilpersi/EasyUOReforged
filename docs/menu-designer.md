# MENU Designer: plan

Status: written 2026-10-30; the owner accepted every recommendation in §14 the same day. Built on the
branch `feature/menu-designer`, step by step (§13). It stays in the repository as the reference for the
designer, next to `menu-1.6-analysis.md`.

The MENU Designer is a standalone program, shipped in every release, for laying out EasyUO MENU windows
visually. It writes the matching MENU script for the **EasyUO 1.6 MENU logic** and reads such scripts back,
so a window can be designed, saved as an `.euo` file, pasted from a script, and edited again.

## 1. Requirements in short

- A graphical application: a canvas, a palette, a property inspector, alignment tools, snapping to the grid
  and to other components' edges.
- 1.6 logic only. No 1.5 output and no 1.5 import.
- Bi-directional. Editing the canvas regenerates the syntax. Pasting syntax, or loading an `.euo` file,
  rebuilds the canvas, which stays editable. Only MENU lines are read; everything else is ignored.
- Several forms per document, each saved as its own `sub`. The only file format is a plain `.euo` script.
- Reuse the existing code, never fork it. `EuoMenu16`, `EuoMenu` and `EuoMenuCommon` keep their behaviour,
  and the golden tests stay 23/23.
- Built by CI, shipped in the release zip, documented in a new section of the docs site.
- It keeps up with the 1.6 MENU syntax. A new 1.6 control type upgrades the designer in the same change,
  and an automated check enforces this (§8).

## 2. Findings from reading the code

These shape the design. Three of them correct or refine the brief.

- **`setdef fontname` reads the rest of the line.** The brief and analysis §3.3 say `setdef` reads one
  word (`P[3]`). The 1.6 recording says otherwise: `defaults_stack.euo` runs
  `menu setdef fontname Courier New`, and 1.6 reported `_FNAME=Courier New`. `TMenu16.Run` passes `Rest(3)`,
  so the port is right. The one-word rule holds only for the integer keys, which read `P[3].Int`. This
  changes nothing for the generator, which writes font names with `menu font name` anyway. The §3.3 row
  should be corrected, with the owner's OK.
- **Constant variables are everywhere in real 1.6 code.** Almost every 1.6 example writes
  `menu setprop x visible #true` or `menu check c … #true …`. Taken literally, "lines with variables are
  skipped" would skip the canonical way to show a form. So the importer reads the five *constant* system
  variables as their fixed values: `#true` (-1), `#false` (0), `#spc` (a space), `#smc` (`;`) and
  `#dot` (`.`), all from `TEuoInterpreter.GetVar`. Any other variable makes the line unreadable.
- **ParseLine's `.` glue cannot be separated from variable substitution.** It runs in the same
  right-to-left loop, which is what makes EasyUO's array idiom `%list . %i` work: `%i` is substituted
  first, then glued onto `%list`, and only then is `%list3` substituted. Sharing ParseLine's rules therefore
  means sharing that loop with a substitution hook, not copying it (§3.2).
- **The editor's file format.** `LoadScriptFileAsUTF8` (`easyuo/insthandler.pas`) keeps valid UTF-8 as it is
  and converts anything else from CP1252. A BOM is kept, and CR, LF and CRLF are all accepted.
  `TSynEditLines.SaveToFile` writes UTF-8 with no BOM, CRLF after every line including the last, and trailing
  spaces trimmed.
- **Colours are written two ways at runtime.** `setprop` and `setdef` take Delphi 7 numbers and convert
  them (`ColorFromVcl`). `font color`, `font bgcolor`, `window color`, `shape` and the `image` drawing
  commands go through `SToCol`, which takes a name or a number and does **not** convert. In those, a system
  colour must therefore be written by name (`btnface`): its Delphi number (-16777201) would not be read as
  `clBtnFace`.
- **Placement quirks that a hand-made canvas would get wrong:**
  - A right-aligned `menu text` is created at width 0 and then fitted while keeping its right edge, so its
    `x` is the right edge of the text.
  - A label's size comes from `TMenu16Label.FitText`.
  - An edit's height comes from `FitEdit`, which is private to `EuoMenu16`.
  - A form's size is clamped to Windows' minimum window size.

  This is why the canvas is built by `TMenu16` itself (§7).
- **EUOUpdtr has no version stamp.** `CLAUDE.md` says every target depends on `uocommon`, but EUOUpdtr
  does not. The designer requires `euoparser`, which pulls in `uocommon`, so it gets the version stamp. The
  `CLAUDE.md` line gets corrected with the Build update.
- **Test material.** The site has 55 MENU code blocks on 51 pages, and `tests/fixtures/menu16` has 23 probes.
  No tool runs docs examples yet; `CheckDocsCoverage.ps1` only checks how they end.

## 3. Architecture

### 3.1 Units

The project is root-level `EUOMenuDesigner.lpi`/`.lpr`, with its sources in `tools/EUOMenuDesigner/`. The
GUI is built in code, as in `easyuo/main.pas`.

| Unit | GUI | Contents |
|---|---|---|
| `mdtypes.pas` | no | The control-type table and the designer's property table (§3.4), plus the commented exclusion list (§8). |
| `mdmodel.pas` | no | The document, forms and components (§3.3): name rules, containment, radio groups, deep copy for undo. |
| `mdgenerate.pas` | no | Model → script: the whole file, one form's sub, caption checks, warnings (§5). |
| `mdimport.pas` | no¹ | Script → model, plus the load report (§6). |
| `mdfile.pas` | no | Reads and writes files as the editor does, and finds foreign lines for the overwrite warning (§4.4). |
| `mdgeometry.pas` | no | Snapping, alignment and distribution as pure rectangle math (§9.2). |
| `mdscript.pas` | ¹ | Reads script lines with the interpreter's own code and runs MENU lines through a `TMenu16` (§3.2, §6). |
| `mdengine.pas` | ¹ | A `TMenu16` driven by generated lines: the canvas engine and the Preview (§7). |
| `mdcanvas.pas` | yes | Each form's surface hosted in its tab, input capture, handles and guides (§7). |
| `mdinspector.pas` | yes | The property grid and its editors (§9). |
| `mdmain.pas` | yes | The main window: menus, toolbar, palette, structure tree, tabs, syntax pane, messages, status bar. |

¹ No designer window, but real hidden LCL controls, because it runs `TMenu16`. The FPCUnit suite already
creates real MENU windows (`EuoMenu16GoldenTests`, `EuoMenuWindowTests`), so these run there too.

The GUI-free units go on `tests/RunTests.lpi`'s `OtherUnitFiles` (`..\tools\EUOMenuDesigner`), the way
`..\easyuo` is there now.

### 3.2 Reuse, and the small changes it needs in existing code

| Need | Reused | Change to existing code |
|---|---|---|
| 1.6 semantics, the canvas, the Preview, the importer's replay | `TMenu16` (`parser/EuoMenu16.pas`), run through its public `Run` | Read-only accessors, with no behaviour change: the registry (`RegistryCount`, `RegistryItem(i)` → name, kind, control) and the property table (`Menu16PropCount`, `Menu16PropRow(i)` → name, type, mask). |
| The properties each type has | The `Props` masks, through that accessor | None |
| Window, button, images, colours | `EuoMenuCommon` (`TEuoMenuForm`, `TEuoMenuButton`, `ColorToVcl`/`ColorFromVcl`), all through `TMenu16` | None |
| Splitting a line | `EuoMenuSelect.SplitScriptLine` | None |
| `+` continuation, `.`/`,` glue, `IsVar`, words → `TParList` | ParseLine's own code | ParseLine's pieces move verbatim into a new `parser/EuoScriptWords.pas`: `IsVar`, the continuation join, `GlueWords(Words, Subst)` (the two glue loops, with substitution as a hook) and the words → `TParList` loop. `ParseLine` calls them. Same behaviour, pinned by the interpreter's glue tests, the golden corpus and the perf bench. |
| Which logic a text gets (the 1.5 warning) | `EuoMenuSelect.ChooseMenuLogic` | None |
| Numbers and colour names | `EuoConversion` (`SToI64Def`, `SToCol`, `IsNumber`), `EuoTokens.TParList` | None |
| Syntax pane | `TSynEdit` + `TSynEUOSyn` (`easyuo/eufoldsyn.pas`, `eusyntax.pas`), used by path like the tests do | None |
| Loading a file as the editor does | `LoadScriptFileAsUTF8` | Moves verbatim from `insthandler.pas` into a GUI-free `easyuo/scriptfile.pas`, which `insthandler.pas` then uses. |
| Version | `ReforgedVersion.REFORGED_VERSION`, through the `euoparser` → `uocommon` requirement | None |

Packages: `euoparser`, `LCL`, `SynEdit` and `SynUni`, all already used by the editor. Nothing third-party.

### 3.3 The model

- **Document:** an ordered list of forms. Form0 is always first. The order is the tab order and the order of
  the subs.
- **Form:** `name`, `left`, `top`, `width`/`height` (the client area as the script really produces it),
  `text` (the title), `color`, `visible`, `enabled`, `tooltip`, and its child components.
  - Form0 also has a `transparency` (none, or 0–100 as in `menu window transparent`).
  - Form0's position is its show position.
- **Component:** `kind` (a row of the type table), `name`, its parent (the form or a panel), `left`/`top`,
  and `width`/`height`, each with an *auto* flag where the type sizes itself (§3.4).
  - The 1.6 properties its kind has in `Props`: `text`, `tooltip`, `enabled`, `visible`, `checked`,
    `color`, `fontname`/`fontsize`/`fontstyle`/`fontcolor`, `alignment`.
  - Values that only creation lines carry: combo and list items and selection; shape style, line on/off,
    line width, line colour, fill on/off, fill colour; an image's bitmap size, its `stretch` flag, and its
    drawing operations (`line`, `ellipse`, `rectangle`, `pix`, `floodfill`, `file`, in order).
- **Colours** are stored as Delphi 7 numbers, as `getprop` reads them.
- **Font style** is stored as the 1.6 bits (1 bold, 2 italic, 4 underline, 8 strike-out).
- **Check and radio alignment** is stored as *text on the left / text on the right*. The type table maps it
  to the inverted `setdef alignment` value at creation, and to the different `getprop` values of check and
  radio.
- **Rules the model enforces:**
  - Names are one word, lower-cased (as 1.6 stores them and `#MenuButton` reports them), unique across all
    forms, and never a variable (`IsVar`) or a word starting with `;`.
  - `form0` is reserved.
  - At most one checked radio per parent.
  - Containers are forms and panels; panels may nest.

### 3.4 The type table (`mdtypes.pas`)

Each row has these columns:
- the palette label and the `MT_*` kind;
- the creating line;
- the size fields that line carries, and which of the others `setprop` can fix;
- the default size;
- the quirk flags;
- the docs anchor.

The table drives the palette, the inspector, the generator, the importer and the docs check. Adding a type
is mostly a new row plus its tests.

| Type | Kind | Created by | Size on the line | Notes |
|---|---|---|---|---|
| form | `MT_FORM` | `menu form n x y w h title` (form0: exists at start) | w h, then exact via `setprop` | Form0 uses `menu window …` |
| panel | `MT_PANEL` | `menu panel n x y w h` | w h | Colour taken from the default colour |
| text | `MT_TEXT` | `menu text n x y text` | none: auto, width/height can be fixed | `$` is a line break |
| button | `MT_BUTTON` | `menu button n x y w h text` | w h | `$` is literal |
| edit | `MT_EDIT` | `menu edit n x y w text` | w; height auto, can be fixed | `$` is literal |
| memo | `MT_MEMO` | `menu memo n x y w h text` | w h | Reforged only (§14); `$` is a line break |
| check | `MT_CHECK` | `menu check n x y w h c text` | w h | Alignment inverted on create and in getprop |
| radio | `MT_RADIO` | `menu radio n x y w h c text` | w h | Inverted on create only; one checked per parent |
| combo | `MT_COMBO` | `menu combo create n x y w` + `add` + `select` | w; height auto | `select i` stores i-1 |
| list | `MT_LIST` | `menu list create n x y w h` + `add` + `select` | w h | Out-of-range select leaves it alone |
| image | `MT_IMAGE` | `menu image create n x y w h` + drawing ops + `image pos` | w h | Ellipse and rectangle take corners |
| shape | `MT_IMAGE` | `menu shape n x y w h st lt lw lc ft fc` | w h | An image at runtime; types 1, 5, 6 are kept square |

## 4. The saved file

### 4.1 Layout

- **Header:**
  - a comment with the designer's version;
  - `menu reforge mode 1.6`;
  - one `gosub` per form, in tab order;
  - a `#MenuButton` wait loop;
  - `halt`.

  The file therefore runs as it is and never falls through into a sub.
- **One sub per form**, form0 included, named `menu_<formname>`.
- **Each sub is self-contained.** Defaults are global, so the sub sets every one it relies on, and builds the
  same form whichever subs ran before it, in any order. It never emits `menu clear`, which would free every
  other form. Each sub:
  1. **Deletes what it is about to build**, so calling it again rebuilds the form instead of leaving
     unreachable duplicates:
     - another form: `menu delete <form>`, which removes the form with everything in it;
     - form0: `menu delete` for each of its top-level children (form0 itself must stay).

     Deleting a name that does not exist does nothing.
  2. **Creates the container:**
     - another form: `menu form …`, then `menu setprop <form> width` / `height` for the exact size (§14);
     - form0: `menu window title`, `menu window size`, `menu window color` and, if set,
       `menu window transparent`, then `menu setdef parent form0`.
  3. **Resets every default:**
     - `menu font name …`, which handles multi-word names;
     - `menu font color` and `menu font bgcolor`, by name (`Black`, `BtnFace`);
     - `menu setdef fontsize`, `fontstyle` and `alignment`, as numbers.
  4. **Creates the components depth-first, in z-order:**
     - before each one, a `setdef` line for every default whose value differs from the current one;
     - after a panel's children, `menu setdef parent <container>`;
     - after creation, the `setprop` lines for what defaults cannot carry: `tooltip`, `enabled #false`,
       `visible #false`, and fixed sizes of auto-sized types.
  5. **Shows the form if it is marked visible:** form0 with `menu show x y`, any other form with
     `menu setprop <form> visible #true`.
- **No `pushdef`/`popdef`.** Their FIFO order and lost alignment make nesting unsafe.
- **Booleans** are written `#true`/`#false`, as the 1.6 docs write them.
- **Colours:**
  - by name where EasyUO 1.6 (Delphi 7) and Reforged (LCL) both know one: the Windows system
    colours and the 20 standard colours (`Red`, `Silver`, `MoneyGreen`, …); otherwise a decimal number;
  - names go to the commands that read a name or a number (`font color`, `font bgcolor`,
    `window color`, `shape`, `image`), so the defaults' colours are set with `menu font color` /
    `menu font bgcolor` (changed from `setdef` numbers at the owner's request after hand test 1);
  - `setprop` gets Delphi 7 numbers, as it must: a name there silently becomes black. A system
    colour without a shared name goes to the defaults with `setdef`'s number, since the other
    commands would not read a system colour's number as one.
- **Encoding:** UTF-8, no BOM, CRLF after every line, no trailing spaces. These are the bytes the editor
  writes, so a designer file opens unchanged in EasyUO Reforged.

### 4.2 Example: form0 and one more form

```euo
; MENU windows made with the EasyUO Reforged MENU Designer 26.10.30.1a2b3c4
menu reforge mode 1.6
gosub menu_form0
gosub menu_opts
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
halt

sub menu_form0
  menu delete title
  menu delete loot
  menu delete bag
  menu delete ok
  menu window title Loot settings
  menu window size 260 120
  menu window color btnface
  menu setdef parent form0
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu setdef fontstyle 1
  menu text title 10 10 Choose what to loot
  menu setdef fontstyle 0
  menu check loot 10 35 150 20 #true Loot corpses
  menu combo create bag 10 60 150
  menu combo add bag Backpack
  menu combo add bag Bank box
  menu combo select bag 1
  menu button ok 170 85 80 25 OK
  menu setprop ok tooltip Save and close
  menu show 100 100
return

sub menu_opts
  menu delete opts
  menu form opts 400 200 200 110 Options
  menu setprop opts width 200
  menu setprop opts height 110
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu panel speed 10 10 180 50
  menu radio fast 5 5 80 20 #true Fast
  menu radio safe 5 25 80 20 #false Safe
  menu setdef parent opts
  menu edit delay 10 70 60 250
  menu button close 110 70 80 25 Close
return
```

### 4.3 Using it from another script

The `menu reforge mode 1.6` line only works in the main script.
- A script that pastes the subs in needs the line itself.
- So does a script that runs them in a file it calls, or else `menu reforge includecall #true`.

The docs page says so (§11), with a whole example that ends with `halt`.

### 4.4 Loading over, and saving over

- **Foreign lines.** A loaded file's *foreign lines* are those that are none of these:
  - a MENU line;
  - a blank line or a comment;
  - a line of the designer's own layout (§4.1) for the forms read.
- **Saving over such a file** would delete its foreign lines, and any MENU lines the designer could not
  model. The designer warns before it overwrites the file: it gives the counts and the first lines, and
  offers *Save As*.
- **Saving over a designer file** (no foreign lines, nothing unmodelled) does not warn.

## 5. The generator (`mdgenerate.pas`)

- Output is a `TStringList`, for the whole file or for one form's sub (the canvas engine uses the latter).
- **Sizes:**
  - Form sizes are exact through `setprop` (§14).
  - Auto sizes are emitted only when fixed: text `width`/`height`, edit `height`.
  - Shape types 1, 5 and 6 are kept square in the model, so the box shown is the box drawn.
- **Captions, tooltips and titles must survive tokenising.** Each is checked with the shared tokeniser
  (§3.2): put it on a line, split and glue it as ParseLine would, and compare with the value. It fails when:
  - spaces would collapse: leading, trailing or doubled spaces, or tabs;
  - a word is a variable (`%x`, `#x`, `!x`, `*x` by `IsVar`'s rule);
  - a word starts with `;`;
  - a standalone `.` or `,` word would glue (a `,` as the last word is safe);
  - a `$` would become a line break where it should stay literal (text and memo);
  - a line break appears where `$` is literal (button, check, radio, edit, tooltip, title).

  A failing value gets a warning in the Messages list, and the inspector field turns red. The line is still
  written as typed, and the warning says what will appear instead.
- **Defaults are tracked within a sub**, so only changes are written. Each sub starts from the full reset
  (§4.1).
- **Radios:** at most one is checked per parent, so the creation order cannot uncheck the wrong one.
- **Not offered:** `hideeuo`, `font transparent`, `image pixline` and `test` (removed in 1.6); `pushdef` and
  `popdef`; `get`, `getprop` and `activate` (runtime).

## 6. The importer (`mdimport.pas`)

- **Input:** a `TStrings` from a file (read as the editor reads it) or from pasted text. Both take the
  same path.
- **Reading lines.** Lines are taken in file order, whatever control flow surrounds them; a line inside a
  loop is read once.
  - `+` continuation lines are joined as ParseLine joins them, and reported at their first line.
  - Each line is split with `SplitScriptLine`.
  - A line whose first word is not `menu` is ignored silently: `sub`, `gosub`, `if`, loops, `set` and so on.
- **Variables.** In a MENU line, the five constants of §2 are substituted through the `GlueWords` hook. Any
  other variable puts the line in the report. Then `.`/`,` glue runs exactly as in ParseLine, and the words
  become a `TParList`.
- **Replay through a private, hidden `TMenu16`.** The importer starts it with `ScriptStart` and runs each
  readable line through `TMenu16.Run`. The default and parent state machine is therefore replayed exactly,
  because it *is* `TMenu16.Run`: default parent, `pushdef`/`popdef` FIFO and lost alignment, `clear`,
  `delete`, duplicates becoming orphans, check and radio inversion, combo `select`. Forms are identified from
  the MENU lines (form0 and each `menu form`), not from sub boundaries, so scripts the designer did not write
  load too.
- **Lines the importer handles itself:**
  - `menu show [x y]` and `setprop <form> visible`: they set the form's `visible` (and form0's position)
    in the model, but are not run, so no window appears.
  - `menu hide`: the same, for hiding.
  - `menu reforge …`: skipped silently.
  - `get`, `getnum`, `getprop`, `getdef` and `activate`: reported as runtime commands.
  - `hideeuo`, `font transparent`, `image pixline` and `test`: reported as removed in 1.6.
  - `menu delete form0`: reported, and not run.
  - Unknown sub-commands: reported.
- **Lines tracked beside the replay,** keyed by the control the name resolved to at that moment:
  - shape lines and image drawing operations, which become pixels at runtime;
  - `image pos` stretch;
  - form0's `window transparent`;
  - whether a text's or an edit's size was fixed after its last refit.
- **Read-back.** At the end, each registered control is read back through `Run`:
  - `getprop` for every property its kind has in `Props`;
  - `menu get` for the combo and list selection;
  - the items from the control itself.

  Children are taken in their parent's z-order. The result is the model.
- **Load report.** Every line not read is listed with its line number and the reason:
  - a variable;
  - a runtime command;
  - a command removed in 1.6;
  - an unknown sub-command;
  - a create line that did nothing (failed 1.6's argument checks);
  - a duplicate name (1.6 shows it, unreachable);
  - a control with no parent, or a parent that is not a form or a panel;
  - a shape or image resized after drawing.

  The report goes to the Messages list, and line numbers jump into the syntax pane.
- **1.5 warning.** When `ChooseMenuLogic` would pick 1.5 for the loaded text, the report says so: in Reforged
  the script would run under the 1.5 logic, the designer read it as 1.6, and the saved file starts with
  `menu reforge mode 1.6`.
- **Round trips.**
  - `load(save(model)) = model`.
  - `save(load(text))` builds the same windows as `text`, apart from the reported lines.
  - Both follow from the read-back: the importer reads the windows the script really builds.

## 7. The canvas engine and the Preview

- **The canvas is built by `TMenu16` itself.** `mdengine.pas` keeps one `TMenu16` for the document; names
  are global in 1.6, as in the file.
  - When a form changes, the engine runs that form's generated sub, which deletes and rebuilds it.
  - During that canvas run, `visible #false` lines are left out, so hidden components still show; the
    overlay marks them.
  - Every edit therefore shows what the script will show, by construction: label autosize, edit heights,
    right-aligned text, clamped form sizes, shape squeezing, drawings, fonts and colours. It is also a
    continuous test of the generator.
- **Hosting.** Each form's `Surface` panel is shown in the form's tab, under a title bar the designer draws.
  The `TEuoMenuForm` itself stays hidden. The engine sizes the surface to the form's client size and copies
  the form's colour onto it.
- **Design input.** Every window on a hosted surface answers `WM_NCHITTEST` with `HTTRANSPARENT`, through
  a window procedure put in front of LCL's. Windows then hands the mouse to the canvas itself, which
  hit-tests the components by their bounds, graphic controls (labels, images) included. Buttons never
  click, edits never focus, combos never drop down. Selection handles, snap guides and the marquee are
  small windowed controls above the surface, so they draw over native controls, and are hit-test
  transparent too. (The plan said a thread-local `WH_MOUSE` hook; the spike showed the window procedure
  needs no global hook and can be checked with `WindowFromPoint`: all twelve types gave the mouse to the
  canvas.)
- **Dragging** moves the real control live with `SetBounds`. On mouse-up, the change goes into the model and
  the form is regenerated.
- **An outline and its handles are one window**, shaped with a region to draw only those. Hand test 2
  found dragging with Alt (no snapping, so a move on every pixel) laggy: twelve small windows moved per
  mouse move cost about 14 ms, against 10 ms between moves. As one shaped window it is about 3 ms.
- **The spike** (step 8 of §13) passed: all twelve types rendered on a hosted surface, every one gave the
  mouse to the canvas, and handles drew over a native edit. The snapshot fallback was not needed.
- **Preview** runs the whole generated file's MENU lines through a separate `TMenu16`, in the order the
  header calls the subs, and shows the real windows: floating, always on top, closable. Clicks show
  `#MenuButton` in the status bar. *Stop preview* destroys them.

## 8. Keeping up with the MENU syntax (the upgrade check)

- **Where it runs.** It reads the source, extending `tests/tools/EuoNames.ps1`, and runs as a new check in
  `CheckDocsCoverage.ps1`, so `run_tests.ps1` and CI gate on it with no new wiring.
- **What it reads:**
  - the `MT_*` constants in `EuoMenu16.pas`'s interface, minus `MT_DEFAULT`. A new control type cannot avoid
    one, because the registry and `Props` need it;
  - the `Props` rows' property names;
  - the 1.6 dispatcher's sub-commands (already read today);
  - the designer's type table, property table and exclusion list in `mdtypes.pas`;
  - the designer's docs page `designer/components.md`.
- **It fails when:**
  - an `MT_*` kind is in no type row and not excluded;
  - a `Props` name is not in the designer's property table and not excluded;
  - a 1.6 sub-command is neither generated or read by the designer, nor on the importer's explicit list of
    runtime, removed and settings sub-commands;
  - a type row has no `## <type>` section on `components.md`.
- **Exclusions** are a commented const list in `mdtypes.pas`: one entry per type, property or sub-command,
  each with its reason. Leaving something out is then a visible decision in a diff.
- **The FPCUnit side.** For every type row, the default component's create line runs through `TMenu16`, and
  the test checks that a control of that kind and name is registered. Every `Props` row for that kind must
  also have an editor in the inspector table.
- **Proof.** Add `MT_FAKE = $1000;` to `EuoMenu16.pas` locally, run the check, show that it fails naming
  `FAKE`, and revert.
- **The rule goes into `CLAUDE.md`**, next to the MENU bullet and the docs-site rule: *a new MENU 1.6 control
  type upgrades the MENU designer in the same change (palette and model, inspector and canvas, generator and
  importer, tests, the designer's docs pages); the check in `CheckDocsCoverage.ps1` enforces it.*
- **The 1.5 logic is not read.**

## 9. UI

### 9.1 Layout (built in code, like `easyuo/main.pas`)

- **Title bar:** `EasyUO Reforged MENU Designer <REFORGED_VERSION>`, plus the file name and `*` when
  modified.
- **Menu and toolbar:**
  - File: New design, Open, Save, Save As, Paste script, Exit.
  - Edit: Undo, Redo, Delete, Select all.
  - Form: New form, Rename, Delete form, Move left/right.
  - Arrange: align, distribute, same size, bring to front, send to back.
  - View: Grid, Snap to grid, Snap to components, Grid size…, Preview.
  - Help: Help (opens the docs section), About.
  - Icons on both, the toolbar's above their captions, from Lazarus' CC0 images (Roland Hahn): the
    general_purpose outline set, the designer's z-order icons, and drawn in that set's style where it has
    none (Select all, the Arrange commands). `make_icons.py` writes them into `mdicons.pas`; the View
    toggles have none, so their check shows.
- **Left:** the palette (one button per type row, table-driven, in alphabetical order, each with the
  Lazarus component icon of its control) above the structure tree.
  - The tree shows forms → panels → controls, with name and type; hidden ones are dimmed.
  - Dragging in the tree reparents or reorders.
- **Centre:** one tab per form, form0 first, with a `+` tab for a new form. Each tab is a scrollable,
  gridded area with the form at 1:1.
- **Right:** the inspector, a two-column grid.
  - Its rows come from the type table, and the 1.6 properties from `Props` through the accessor. They are
    in alphabetical order of their captions.
  - Editors: inline text and numbers; drop-downs for enums (alignment, text side, shape style); check boxes
    for booleans; `…` buttons for colour (a colour dialog plus the system colours), font, items (a list
    dialog) and drawing operations (an ordered list dialog).
  - Auto sizes show the real size, greyed, with an *auto* tick box.
- **Bottom:** the syntax pane (`TSynEdit` + `TSynEUOSyn`) and a Messages list.
  - The syntax pane can be edited. **Apply** (Ctrl+Enter) rebuilds the canvas through the importer and then
    rewrites the text in the designer's layout.
  - After a load, a paste or an Apply with a load report, the pane keeps the text as read, so the report's
    line numbers can be found in it (double-click a message); the next change rewrites it.
  - The Messages list holds generator warnings and the load report.
  - The inspector shows and edits the first selected component.
- **Status bar:** the selection's position and size, the snapping state, `MENU 1.6`, and `#MenuButton` while
  previewing.

### 9.2 Moving, resizing, aligning, snapping

- **Mouse:** click to select, Shift+click to add or remove, drag on empty space for a marquee. Drag to move,
  drag a handle to resize. Dropping onto a panel or the form reparents.
- **Keyboard:** arrows move 1 px, Shift+arrows one grid step, Ctrl+arrows resize, Del deletes.
- **Alignment, within one parent, relative to the first selected:** left, right, top and bottom edges;
  horizontal and vertical centres; centre in the parent; distribute horizontally and vertically; same width,
  height or size.
- **Snapping, while moving and resizing:**
  - to the grid (default 8 px);
  - to siblings' and the parent's edges and centre lines, within 4 px, with guide lines shown.

  Alt held suspends it.
- **The math lives in `mdgeometry.pas`**, GUI-free and tested. The canvas gives it the real rectangles,
  including auto sizes.

## 10. Tests (FPCUnit, in `tests/RunTests.lpi`)

| Unit | Covers |
|---|---|
| `EuoScriptWordsTests` | The extracted pieces: continuation, `.`/`,` glue with and without a hook, the array idiom, `IsVar`, `TParList` fields. The interpreter's existing glue tests and the corpus pin ParseLine. |
| `MenuDesignerModelTests` | Name rules, uniqueness across forms (a clash is refused), radio groups, containment, deep copy; snapping and alignment math. |
| `MenuDesignerGenerateTests` | Each type's lines. Each quirk: edit without height, text autosize and `$`, check/radio inversion, radio groups, `combo select` i-1, shape squeeze, image corners, colours by name or number, multi-word font names, exact form size, the minimum window size. Caption warnings, one test per failure kind. File layout. |
| `MenuDesignerImportTests` | Each sub-command, including default parent, `pushdef`/`popdef` FIFO and lost alignment, `clear` and `delete`. Non-MENU lines ignored. Constants read. Unreadable lines reported with the right line numbers, continuation lines included. The 1.5 warning. Foreign-line detection. |
| `MenuDesignerRoundTripTests` | *Parity:* the generated script run through `TMenu16`, every property read back with `getprop` and compared with the model (position, size including frame growth, font, colour, text, parent). *Order:* for three forms, every sub alone and in all six orders gives identical read-backs. `load(save(m)) = m`. *Corpus:* every MENU example on the docs site and every `menu16` probe imports, with every reported line in an allowed category, and `load(save(load(t))) = load(t)`. *Files:* save → load gives the same model; a saved file loaded and saved by the editor's path (`LoadScriptFileAsUTF8` into a `TSynEdit`, `SaveToFile`) is byte-identical. *Type table:* each row registers its kind. |

- The docs examples are found relative to the test executable (`..\website\src\content\docs`), as the
  fixtures are.
- The upgrade check (§8) runs in `CheckDocsCoverage.ps1`, and the proof is shown once by hand.
- **GUI hand tests** with the owner, one at a time, each waiting for the result. Every `.euo` handed over
  ends with `halt`.
  1. First form from the palette.
  2. Move, resize and snap.
  3. Alignment tools.
  4. The inspector, per type.
  5. Several forms.
  6. Paste script, and the load report.
  7. Overwrite warning.
  8. A saved file opened and run in EasyUO Reforged.
  9. Preview.
  10. Undo and redo.

## 11. Docs section

The section is a new folder, `website/src/content/docs/designer/`, added to the sidebar with
`...folderGroup('MENU Designer', 'designer')` after *Guides*. Its pages are prose: no `kind`, so no schema
change is needed.

| Page | Contents |
|---|---|
| `index.md` | What it is, getting it (in the release zip, next to `EasyUOReforged.exe`), and a first form step by step. |
| `canvas.md` | Adding, selecting, moving, resizing, aligning, snapping, the structure tree, z-order. |
| `inspector.md` | Properties and what each becomes in the script (`setdef`, `setprop`, creation values); colours, fonts, items, drawings. |
| `components.md` | One `## <type>` section per type, with its quirks; memo marked Reforged only. The upgrade check reads it. |
| `forms.md` | Several forms, form0's window settings, names unique across forms, the subs they become, exact sizes. |
| `files.md` | Saving, loading, pasting: what is ignored, the load report, the 1.5 warning, the overwrite warning, the encoding. |
| `scripts.md` | Using the saved file in a script: `menu reforge mode 1.6`, `gosub`, reading `#MenuButton`, `call` with `includecall`. |
| `limitations.md` | What it cannot read or model. |

- **Examples** are whole scripts that run as pasted and end with `halt`.
- **Links:**
  - a tip on `commands/menu/index.md` near *Building big menus quickly*;
  - a line under *Choosing it yourself* on `versions.md`;
  - an entry on `reforged/whats-new.md`;
  - an entry on `reforged/known-limitations.md` for what the importer cannot read.
- **Contributors:** `developers/menu-designer.md`, on adding a control type.
- **Other changes:**
  - `developers/building.md` gets the fourth program: the table, the build lines, the "three" sentences, the
    CI section;
  - `README.md` gets at most one line.
- `npm run build` must pass.

## 12. Build, CI, release

- **`EUOMenuDesigner.lpi`**, modelled on `EasyUOReforged.lpi`:
  - modes Default and Release, with lib dirs `lib\$(TargetCPU)-$(TargetOS)-menudesigner` and
    `…-menudesigner-release`, used by no other target;
  - required packages `euoparser`, `LCL`, `SynEdit`, `SynUni`;
  - `OtherUnitFiles` `tools\EUOMenuDesigner;easyuo`.
- **`.github/workflows/ci.yml`:** the project is added to the build loop and to the artifact paths.
- **`release.yml`:** the build loop, the `Copy-Item` line, and the "Zip contents" line of the release notes.
- **`CLAUDE.md` Build section:** a fourth `lazbuild` line, and the corrected `uocommon` sentence.

## 13. Order of work

Each step runs the full suite (`pwsh ./tests/run_tests.ps1`) before the next one starts. Commits happen
only when the owner says so.

1. **Shared pieces, no behaviour change:**
   - `parser/EuoScriptWords.pas`, used by `ParseLine`;
   - `easyuo/scriptfile.pas`, used by `insthandler.pas`;
   - the read-only accessors on `TMenu16` and `Props`.

   Tests: `EuoScriptWordsTests`, everything green, golden 23/23, the perf bench unchanged.
2. **Project skeleton:** `.lpi`/`.lpr`, own lib dirs, an empty window with the version title and About. CI,
   release, `CLAUDE.md` Build and `building.md` are updated. Test: it builds with lazbuild in both modes.
3. **Type table and model.** Tests: `MenuDesignerModelTests`.
4. **Generator.** Tests: `MenuDesignerGenerateTests`, plus the parity and order tests.
5. **Importer.** Tests: `MenuDesignerImportTests`, round trips, and the docs and probe corpus.
6. **Files and overwrite detection.** Tests: the file round trip and the byte-identical editor check.
7. **Upgrade check:** `EuoNames.ps1`, `CheckDocsCoverage.ps1`, the exclusion list and the `CLAUDE.md` rule.
   The docs part becomes active in step 11. Proof with a fake `MT_*`.
8. **Canvas spike, then the canvas engine:** hosting, hook, selection, move and resize, snapping, alignment.
   Tests: geometry math. Hand tests 1–3.
9. **Inspector, palette, structure tree, syntax pane with Apply, Messages.** Hand tests 4 and 6.
10. **Tabs for several forms, Preview, undo and redo.** Hand tests 5, 7, 8, 9 and 10.
11. **Docs section and links,** with `npm run build`.
12. **`docs/architecture.md`, `CLAUDE.md` architecture note, memory.**

**Status (2026-10-31):** steps 1 to 12 are built on `feature/menu-designer`, with the full suite green, and
the owner passed all ten hand tests (§10). What they found is fixed, each with a test: typed inspector values
were lost (LCL never calls `TValueListEditor.OnValidate`), the Alt-drag lagged (an outline with its handles
is now one window), the text/items/drawing dialog had its buttons off its edge, a shortcut freed the canvas
view still handling its key (every command now runs from the message loop, pinned by
`MenuDesignerMainTests`), and New design, Open and Paste script kept the old undo history. Colours are
written by name, and the toolbar's New is *New design*.

## 14. Decisions

Settled by the owner on 2026-10-30: every recommendation below was accepted.

1. **Names.** Recommended:
   - exe `EUOMenuDesigner.exe` (project `EUOMenuDesigner.lpi`), matching the `EUOUpdtr`/`EUOMigrate`
     family;
   - sources in `tools/EUOMenuDesigner/`;
   - docs folder `designer/`, labelled *MENU Designer*;
   - branch `feature/menu-designer`.
2. **Sub names and the top of the file.** Recommended:
   - subs named `menu_<formname>`;
   - the header of §4.1: version comment, `menu reforge mode 1.6`, a gosub per form, a
     `set #MenuButton N/A` / `while #MenuButton = N/A` / `wait 1` loop, `halt`;
   - each sub deleting what it builds first, so it can be called again;
   - forms marked visible shown at the end of their sub.

   Alternative: show form0 only in the header, and keep subs build-only.
3. **Reaching the designed form size.** Recommended: `menu form` with the designed size, then
   `setprop width/height` for the exact value, which is right on any Windows build and DPI. Subtracting the
   frame growth bakes in the designer machine's 10 px, and breaks below 10.
4. **Designer-only state.** Recommended: not in the file, so it stays pure MENU syntax. The grid size and
   snap settings are program preferences, kept in the registry under the designer's own key; form order is
   file order.
5. **Scope.** Recommended, all three in:
   - `memo`, marked *Reforged only*, because the Reforged 1.6 logic has it and real EasyUO 1.6 ignores it;
   - `image file`, with a literal path drawn on the canvas when found;
   - image drawing operations, as an ordered list per image, rendered by `TMenu16` itself, so the drawing
     code costs nothing.

   No freehand drawing.
6. **How the upgrade check finds the 1.6 types.** Recommended: from source, through `EuoNames.ps1`, reading
   `MT_*`, the `Props` names and the sub-commands (§8). A table exposed by `EuoMenu16` would have to be kept in
   step by hand, which is the thing the check exists to prevent.
7. **Undo/redo.** Recommended in. It is snapshot-based: every committed edit pushes a deep copy of the
   model; it is cheap and exact.
8. **Canvas.** Recommended: real controls built by a live `TMenu16`, hosted in the tab, with input captured
   by a mouse hook and handles drawn as small windows on top (§7), after a spike. Fallback: snapshots on a
   self-painted canvas. Fully self-painted was rejected: it would need copies of `TMenu16`'s sizing rules.
9. **Several forms in the UI.** Recommended: tabs, one form per tab at 1:1. One shared canvas would need
   designer-only layout state and gains little.
10. **(Not in the brief) Sharing ParseLine's rules.** Recommended: move ParseLine's continuation, glue,
    `IsVar` and `TParList` pieces verbatim into `parser/EuoScriptWords.pas` and have `ParseLine` call them
    (§3.2). The alternative, a mirror in the designer checked against ParseLine, is the kind of copy the brief
    rules out. The same goes for moving `LoadScriptFileAsUTF8` out of `insthandler.pas`.
