# The EasyUO 1.6 MENU system: analysis and porting plan

Status: analysis done and checked in depth (§9: runtime tests in the real 1.6 binary, a scan of 125
real scripts, an LCL prototype). Design decided on 2026-10-28: two separate MENU implementations,
1.5 and 1.6, chosen per script (§6, §7). Nothing implemented yet. Branch `feature/menu-v16`.

Users report that MENU code written for the last closed EasyUO does not work in Reforged. Reforged's
MENU is a port of the last *open* source (`parser\menu.pas`, the pre-2015 single-window menu). Cheffe
rewrote the menu system after that, in closed builds only. This document records what the closed
version does, how it differs from the open source and from Reforged, and how to bring the new
features into Reforged without breaking old scripts.

## 1. Sources

| Source | What it is | Reliability |
|---|---|---|
| `D:\Tmp\EUO_Original\close_bin\easyuo.exe` | Last closed build, version string **EasyUO 1.6.0.337**, Delphi 7, x86, SHA-256 `8921e689eeefa3f066b37d4a849dcba6fa662d6f5bd78fbd40872dd3feaf04df` | Authoritative. Everything in §3 is read from it (REA/Ghidra decompilation plus capstone disassembly). |
| `D:\Tmp\EUO_Original\src\parser\menu.pas`, `parser.pas` (`MenuProc`) | Last open source | Authoritative for the old system; Reforged's `EuoMenu.pas` is a near-verbatim port of it. |
| easyuo.com, CoE forum, "TID005 Menu Enhancements - Discussion", t=52250 (3 pages, Apr–Oct 2015) | Cheffe's design discussion and alpha builds (`coe001`, `easyuo292coe_a1`) | Design intent. Some alpha features never shipped (see §3.9). |
| ScriptUO, "New Menu Code and how to adapt old scripts", topic 15596 (Gaderian, 2020) | User tutorial for the shipped system | Useful, but several claims are wrong against the binary (see §5). |
| Probe scripts run in the real 1.6 binary (§9.1) | Behaviour observed at runtime, read back through window captions | Confirms §3; two corrections came from it. |
| 417 script attachments from ScriptUO threads active since 2017, 125 distinct scripts using MENU (§9.2) | What real scripts depend on | Basis for the differences table (§6.6) and the detection check (§7). |

## 2. Summary

- EasyUO 1.6 replaced the old `TMenuObj` (one form, a `TStringList` of controls) with a new
  `TMenu2Obj`: a name registry (`TObjMgr`), any number of top-level **forms**, **panels** as
  containers, a **parent** for every control, a **default** object (`TDefault`) that holds the
  font/colour/alignment/parent new controls get, and a generic **property** interface
  (`getprop`/`setprop`/`getdef`/`setdef`) backed by a fixed table.
- New sub-commands: `form`, `panel`, `radio`, `getprop`, `setprop`, `getdef`, `setdef`, `pushdef`,
  `popdef`. Removed: `hideeuo`, `image pixline`, `font transparent`, `test`.
- The old window is now a named control, `form0`, created at script start.
- **Names became unique.** A control created with a name already in use is created and shown but
  never registered: `menu delete`, `menu set`, clicks (#MenuButton) and every other by-name command
  ignore it. This is the "my buttons stop responding" breakage the ScriptUO tutorial describes, and
  the main incompatibility with old scripts.
- Everything else the old commands do is close to the open source, with a list of small differences
  (§4).
- Reforged today has none of the new features (§4.2).
- Plan (§6): keep today's MENU as the **1.5 logic** and add a faithful port of the 1.6 MENU as a
  separate **1.6 logic**. Reforged picks one per script when it starts: 1.6 when the script uses a
  1.6-only sub-command, 1.5 otherwise. `menu reforge mode 1.5|1.6` forces either one, and
  `menu reforge includecall #true` makes the detection also look inside the files the script
  `call`s. The detection was checked against 125 real scripts (§7).

## 3. The EasyUO 1.6 MENU system (from the binary)

Addresses are virtual addresses in `easyuo.exe` (image base `0x400000`).

### 3.1 Objects

- `TOldParser.MenuProc` at `0x4c120c` is the dispatcher. The parser owns `#MenuRes`
  (`[parser+0x2f64]`); the menu object owns the name of the last clicked/closed control
  (`[TMenu2Obj+0x10]`).
- `TObjMgr` (registry, `0x4ae364`): two sorted `TList`s of `TItem{ptr, name}`, one by pointer, one
  by name (ordinal compare), plus a *protected* pointer used by `menu clear`.
  - Names are stored **lower-cased**.
  - `Add` (`0x4ae420`) refuses a nil control, an empty name, a control already registered, **and a
    name already registered**. The refused control is not freed: it stays on screen, unreachable.
  - Removing an item (`0x4ae4fc`): if the control is a `TWinControl`, every child is detached
    (`Parent:=nil`) and removed recursively; then the control is freed unless it is the protected one.
    An unregistered child is only detached (it disappears and leaks).
- `TDefault` (`0x4ae7ac`): a `TControl` descendant with published `Alignment`, `Color`, `Font`,
  `Parent`. New controls copy their font, colour, alignment and parent from it. Being a `TControl`
  with a parent, it is itself a child of the current default container, so deleting that container
  also resets the default parent to nil.
- Control types (table at `0x4cd958`; type bit used by the property table):

  | Name | Class | Bit |
  |---|---|---|
  | form | `TForm` | `0x001` |
  | panel | `TPanel` | `0x002` |
  | text | `TLabel` | `0x004` |
  | button | `TBitBtnWithColor` | `0x008` |
  | edit | `TEdit` | `0x010` |
  | check | `TCheckBox` | `0x020` |
  | radio | `TRadioButton` | `0x040` |
  | combo | `TComboBox` | `0x080` |
  | list | `TListBox` | `0x100` |
  | image | `TImage` | `0x200` |
  | (default) | `TDefault` | `0x400` |

### 3.2 Lifecycle

- **Parser creation and every script start** (`TOldParser.Clear`, `0x4bc914`, called when a stopped
  script is played): the menu object is cleared with nothing protected, so **every window, form0
  included, is destroyed**; then a fresh hidden `form0` is created with `Left=100 Top=100
  ClientWidth=295 ClientHeight=170 Caption='EUO Menu'` (it ends up 305×180, see next item).
  `#MenuRes` becomes empty. `#MenuButton` becomes empty. Stopping a script leaves every window as
  it is. (All verified at runtime.)
- **Every form** (`FormCreate`, `0x4af564`), form0 included: `TForm.CreateNew(nil)`, then the
  client size, then `BorderStyle=bsSingle` (not resizable), `BorderIcons=[biSystemMenu,biMinimize]`
  (no maximize), `FormStyle=fsStayOnTop`, `ShowHint=True`, `GWL_HWNDPARENT=0` (own taskbar
  button), hidden. Because the client size is set while the form still has a sizeable frame and VCL
  keeps the outer size when the frame changes, **the client area grows by the difference between
  the two frames: 10 px each way on Windows 10/11** (`menu form f 0 0 200 100` gives 210×110). A
  later `setprop … width`/`height` or `menu window size` sets the exact value.
  `OnClose` sets `CloseAction:=caHide` and records the form's name as the last clicked control.
  The default parent becomes the new form.
- **Defaults after a clear** (`0x4af344`): font Arial 10, no style, black; colour `clBtnFace`;
  alignment left; parent nil (the dispatcher then sets form0). The `pushdef` stack is emptied.

### 3.3 Sub-commands

`P[n]` is the n-th word of the line (`P[0]`=`menu`, `P[1]`=the sub-command). *Int* = `IntValid`,
*Card* = `CardValid` (non-negative). "count" is the number of words including `menu`. A failed check
ends the command silently. Sub-commands are matched as independent `if`s, not `else if`, in the
order below; this changes nothing observable.

| Sub-command | Checks | Effect |
|---|---|---|
| `getprop c p` | `c` registered | Property `p` of `c` (§3.4) into `#MenuRes`: string as is, integer as decimal, boolean as `-1`/`0`. Unknown control or property: `#MenuRes` unchanged. |
| `setprop c p v...` | `c` registered | Sets `p`. The type comes from the table. String: rest of line from word 4. Integer: `P[4].Int` **without validity check** (`red` → 0, so colour names give black). Boolean: `P[4].Int<>0`. Extra words are ignored. |
| `pushdef` | – | Copies font, colour and parent of the current default and appends the copy to a list. |
| `popdef` | list not empty | Frees the current default and takes **the first** element of the list (see §3.8). |
| `getdef k` | – | Like `getprop` on the default object. |
| `setdef k v` | – | Like `setprop` on the default object; the value is `P[3]`. |
| `show [x y]` | form0 registered | If count≥4 and both Int: `Left`/`Top`. `Visible:=True`, `SetWindowPos(HWND_TOPMOST, NOMOVE or NOSIZE)`. |
| `hide` | form0 registered | `Visible:=False`. **Does not** set `#MenuButton` to `CLOSED` (the old code called `Close`, which did). |
| `clear` | – | form0 is protected; everything else (other forms, panels, controls) is freed; defaults reset; form0 re-registered; default parent := form0. form0 keeps its position, size, caption and colour. `#MenuButton` becomes empty. |
| `delete n` | count>2 | Removes `n` and, recursively, its registered children. `delete form0` is allowed and destroys form0 until the next script start (`clear` cannot bring it back). |
| `activate n` | count>2, `n` registered | A form: `SetForegroundWindow`. Any other control: walks up to its form, `SetForegroundWindow`, `ActiveControl:=n`. |
| `get n` | count>2 | `#MenuRes:='N/A'`, then Edit `Text`; Combo `Tag+1`; List `ItemIndex+1`; Check and **Radio** `-1`/`0`. |
| `getnum n d` | count≥3 | `get`; if the result is not a number and count>3, `#MenuRes:=d`. |
| `set n v...` | count>2 | Edit `Text`, Text and Button `Caption`, Check and **Radio** `Checked:=StrToIntDef(v,0)<>0`. Only the registered control. |
| `window size w h` | form0; count≥5; Card | form0 `ClientWidth`/`ClientHeight`. |
| `window color c` | form0; count≥4 | Colour by name or number. |
| `window title t...` | form0; count≥3 | Caption (empty when no text is given, as before). |
| `window transparent p` | form0; count>3; Card; p<101 | `AlphaBlendValue:=p*235 div 100+20`, `AlphaBlend:=True`. |
| `font name n...` | count>3 | Default font name. |
| `font align left\|right\|center` | count≥4 | Default alignment 0/1/2. |
| `font size s` | count>3; Card | Default font size. |
| `font color c` / `font bgcolor c` | count≥4 | Default font colour / default colour (names allowed). |
| `font style bius` | – | Clears the style first (even with no argument), then adds the letters found. |
| `font transparent` | – | **Removed** (no effect). Labels are always opaque. |
| `form n x y w h [title...]` | count≥7; Int 3–6 | New hidden form; client area `w+10 × h+10` (see §3.2). Becomes the default parent, **even when the name is already taken** (the form is then an unreachable hidden orphan and everything created next goes into it). Show it with `setprop n visible #true`. |
| `panel n x y w h` | count≥7; Int 3–6 | `TPanel`, `BevelOuter=bvNone`, colour = default colour, parent = default parent. Becomes the default parent. |
| `text n x y t...` | count≥5; Int 3–4 | `TLabel`; `$` → CR LF; font, colour, alignment, parent from the default; `Width:=0` (autosize). |
| `button n x y w h t...` | count≥7; Int 3–4; Card 5–6 | `TBitBtnWithColor`; a click records `n`. |
| `edit n x y w t...` | count≥6; Int 3–4; Card 5 | `TEdit` (width only, no height). |
| `check n x y w h c t...` | count≥8; Int 3–4; Card 5–6; Int 7 | `TCheckBox`, `WordWrap`, alignment inverted as before. |
| `radio n x y w h c t...` | as `check` | `TRadioButton`; `Checked` set after parenting, so it unchecks the other radios **with the same parent**. |
| `list create n x y w h` | count≥8; Int 4–5; Card 6–7 | `TListBox`. |
| `combo create n x y w` | count≥7; Int 4–5; Card 6 | `TComboBox`, `csDropDownList`, `Tag=-1`. |
| `combo\|list add n t...` / `clear n` / `select n i` | count≥4 (select: count>4, Int 4) | As before, but on the registered control only. |
| `shape n x y w h st lt lw lc ft fc` | count≥13; Int 3–4; **Card 5–9, 11**; colours valid | **Emulated with an image** (parser `0x4c10ac`): circle/square types squeeze the box to a square, centred; a filled ellipse or rectangle in `fc` if `ft=7`; an outline in `lc`, width `lw`, if `lt<>1`. Dashed lines, hatch fills and rounded corners are gone; any `ft` other than 7 means no fill (old: everything except 1–6 and 8 was solid). The shape is an `image` and can be drawn on and changed with `setprop`. |
| `image create n x y w h` | count≥8; Int 4–5; **Card 6–7** | `TImage`, transparent colour key `$FEEEED`, 32 bpp. |
| `image pos n x y [w h]` | count≥6; Int 4–5; `n` registered | `Left/Top`; with `w h` (count≥8, Card) also `Width/Height` and `Stretch:=True`. (Old: `Stretch` also for the 2-argument form.) |
| `image pix\|floodfill n x y c` | count≥7; colour valid | As before. |
| `image file n x y f` | count≥7 | `TOleGraphic` (BMP/JPG/GIF/ICO/WMF). |
| `image line n x1 y1 x2 y2 c [w]` | count≥9; **Card 6–7**; colour valid | `w` used if count>9 and Card, else 1. (Old: an invalid `w` drew nothing.) |
| `image ellipse\|rectangle n x1 y1 x2 y2 c fill [w]` | count≥10; Card 6–7 | **Corners, as before** (not width/height). `w` if count>10 and Card, else 1. |
| `image pixline` | – | **Removed.** |
| `image *` on a name that is not an image | – | Not checked: the binary calls `TImage.Canvas` on whatever control has the name (memory corruption). |
| `hideeuo`, `test` | – | **Removed.** |

### 3.4 Properties (`getprop`/`setprop`/`getdef`/`setdef`)

Table at `0x4cd9d0`; the first row whose name matches and whose mask contains the control's type
wins. Names are case-insensitive.

| Property | Maps to | Type | Applies to |
|---|---|---|---|
| `alignment` | `Alignment` (inverted 0↔1 for **check boxes only**, not radios) | int 0/1/2 | text, check, radio, default |
| `checked` | `Checked` | bool | check, radio |
| `color` | `Color` | int | all except image; default |
| `enabled` | `Enabled` | bool | all ten types |
| `fontcolor` / `fontname` / `fontsize` / `fontstyle` | `Font.Color` / `.Name` / `.Size` / `.Style` (bits: 1 bold, 2 italic, 4 underline, 8 strike-out) | int / string / int / int | text, button, edit, check, radio, combo, list, default |
| `height` / `width` | `ClientHeight` / `ClientWidth` for a form, `Height` / `Width` otherwise | int | all ten types |
| `left` / `top` | `Left` / `Top` | int | all ten types |
| `parent` | name of the parent; setting reparents to a registered `TWinControl` | string | all except form; default |
| `text` | `Caption` (form, text, button, check, radio) or `Text` (edit) | string | those six |
| `tooltip` | `Hint` (`ShowHint` is on for every control) | string | all ten types |
| `visible` | `Visible` | bool | all ten types |

`getdef`/`setdef` keys are therefore `alignment`, `color`, `fontcolor`, `fontname`, `fontsize`,
`fontstyle`, `parent`. `getprop x parent` on a control whose parent is not registered leaves
`#MenuRes` holding the previous string result.

### 3.5 `#MenuButton` and `#MenuRes`

- Reading `#MenuButton` (`0x4bda63`): the last recorded name, except that the exact string `form0`
  reads as `CLOSED`. Recorded names are lower-case: `button1`, `form2`, `CLOSED` for form0.
- A click on a button records its name. Closing a form with its × records the form's name. Only
  registered controls record anything.
- `set #MenuButton v` stores `v` verbatim; `set #MenuRes v` likewise.
- Initial value and after `menu clear`: empty (the old code never cleared it).

### 3.6 Coordinates and parents

Coordinates are relative to the parent's client area. A control created after `menu form` or
`menu panel` goes into that form or panel until another one is created, `setdef parent` changes it,
`popdef` restores an older default, or `menu clear` resets it to form0. `setprop c parent p` moves a
control at any time.

### 3.7 Threading

`MenuProc` runs synchronised on the main thread, as in the open source.

### 3.8 Bugs and quirks in 1.6

The 1.6 logic reproduces all of these (§6.5) except item 4, which can crash.

1. `pushdef` appends to the list and `popdef` takes the **first** element: nested push/pop restore in
   the wrong order (FIFO). One push/pop pair works.
2. `pushdef` does not copy the alignment; after `popdef` the alignment is always left.
3. Duplicate names leave orphan controls (on screen, not addressable, buttons dead).
4. `image *` on a non-image control corrupts memory. (1.6 logic: ignored instead.)
5. Colour names in `setprop`/`setdef` silently become 0 (black).
6. `getprop` on a parent that is not registered returns a stale value.
7. `alignment` inversion is applied to check boxes but not to radio buttons in `getprop`/`setprop`,
   although `radio` creation inverts it.
8. The shape outline is drawn from `(lw div 2, lw div 2)` to `(w-2*(lw div 2), h-2*(lw div 2))`:
   off-centre by half a pen width.

### 3.9 Alpha-only features that never shipped

`menu state` (coe001), `getcontrols`/`getcontroltype`/`getfields`/`getfieldtype` (a1),
`bringtofront`/`sendtoback`, `memo`, the `list` command and `#listres`. None of these strings are
in build 337. (Reforged already has its own `menu memo`.)

## 4. Differences

### 4.1 EasyUO 1.6 compared with the open source

| Area | Open source (≈ Reforged today) | EasyUO 1.6 |
|---|---|---|
| Windows | One form | form0 plus any number of `menu form` |
| Containers | None | `menu panel`; every control has a parent |
| Names | Duplicates allowed; `set`, `delete`, `combo/list add/select/clear`, `image *` act on **all** controls with the name; `get`, `activate` on the first | Unique; a duplicate is unregistered and unreachable |
| `#MenuButton` | Name in upper case; `CLOSED` on × or `menu hide`; never reset, not even between runs | Lower case; `CLOSED` only for form0's ×; other forms give their name; emptied by `clear` and at script start |
| `#MenuRes` | Kept between runs | Emptied at script start |
| `menu hide` | `Close` (sets `CLOSED`, restores EasyUO) | `Visible:=False` only |
| Script start | Controls freed, window kept as it was | All windows destroyed, new hidden form0 at 100,100, 305×180 client |
| form0 frame | Sizeable, all border icons, 10,10, 200×100 outer | Single border, no maximize, 100,100, 305×180 client |
| `menu form` size | – | Client area 10 px larger each way than asked (§3.2) |
| Properties | None | `getprop`/`setprop`/`getdef`/`setdef` |
| Defaults | Implicit fields set by `menu font` | Readable and writable; `pushdef`/`popdef` |
| Radio buttons | None | `menu radio`, grouped by parent; `get`/`set` support them |
| Tooltips | None | `setprop c tooltip ...` |
| `menu activate` | Focus inside form0, some control types | Any control; brings its form to the front |
| `menu shape` | `TShape`, all pen/brush styles, rounded corners | Image; solid or nothing |
| Removed | – | `hideeuo`, `image pixline`, `font transparent`, `test` |
| Validation | `image create` w/h, `image line/ellipse/rectangle` x2/y2, `shape` w/h accept negatives; an invalid `image line` width draws nothing | Negatives rejected; an invalid width draws with width 1 |
| Colour names | `font color`, `window color`… accept Delphi colour names | Same list (`ltgray`, `dkgray`, `orange` unknown in both). `setprop`/`setdef` take numbers only. System colours read back in Delphi encoding (`btnface` = -16777201). |

### 4.2 Reforged compared with EasyUO 1.6

Reforged = open source plus its own changes (`menu memo`, Symbol-font remapping, repaint bursts,
stay-on-top fixes, own taskbar button, 24 bpp images, `TEuoMenuButton` instead of
`TBitBtnWithColor`). Against 1.6 it is missing everything in the right-hand column of §4.1, and in
particular:

- `form`, `panel`, `radio`, `getprop`, `setprop`, `getdef`, `setdef`, `pushdef`, `popdef` are
  unknown sub-commands and do nothing. A 1.6 script that builds its window with `menu form` and
  shows it with `menu setprop … visible #true` shows nothing at all.
- `form0` is not a name: `menu setprop form0 …`, `menu delete form0`, `setdef parent form0` do
  nothing.
- Closing a secondary form cannot report its name in `#MenuButton` (there are no secondary forms).
- `menu get`/`set` ignore radio buttons.

## 5. Claims in the ScriptUO tutorial checked against the binary

| Claim | Verdict |
|---|---|
| "Each element must have a unique name" | True for anything addressed by name (§3.1). Its later softening (delete + recreate works) is also true. |
| "New forms are 10 px larger than `menu window size`" | True (measured: 210×110 for 200×100). Both set the client size, but `menu form` sets it before switching the frame to a single border, and the frame change adds the difference (§3.2). |
| `menu edit … left top width height` | Wrong: still `x y width text`. |
| `menu image ellipse/rectangle … left top width height` | Wrong: still corners `x1 y1 x2 y2`; only negative `x2/y2` are now rejected. |
| `menu panel … left top height width` | Wrong order: `x y width height`. |
| `menu clear` "deletes all forms except form0" | True. Part 2's "deletes all forms" is wrong. |
| `menu clear` sets `#MenuButton` to nothing | True. |
| Window × gives `CLOSED` for form0, the form name for others | True (names in lower case). |
| `menu shape` without dashes/rounded corners | True (emulated as an image). |
| `menu font transparent` / `menu transparent` only for old code | `font transparent` does nothing at all in 1.6; `window transparent` works on form0. |
| Pascal colour names do not work in new menus | They do in `font color`, `font bgcolor`, `window color`, `shape`, `image` (same names as before, verified); they do not in `setprop`/`setdef` (§3.8 item 5). |
| `setdef alignment left` → 0 | True: `setdef` takes numbers only. |
| `menu image pixline`, `menu hideeuo` gone | True. |

## 6. Plan

### 6.1 Decision (2026-10-28)

Reforged gets **two separate MENU implementations**, one per EasyUO version, and picks one per
script when the script starts:

- **1.5 logic**: the MENU Reforged has today (the open-source port, with Reforged's own fixes and
  `menu memo`), unchanged.
- **1.6 logic**: a faithful port of the MENU of EasyUO 1.6.0.337 (§3), behaviour for behaviour,
  quirks included.
- Reforged chooses automatically (§6.2); the script can force either one, or widen the detection
  to the files it `call`s, with `menu reforge` (§6.3).

This replaces the superset studied in §9. The reasons are below; the evidence is in §7.

- **No regression risk for existing scripts.** The field-tested 1.5 code stays as it is.
- **Exact 1.6 fidelity.** It can be checked against the real binary with recorded golden values.
- **Simpler fixes.** A bug is fixed in the version it belongs to, without weighing both families
  of scripts at once.

The price:
- **More code.** Roughly a third to half more than the superset.
- **A mode concept in the documentation.**
- **The switch is all or nothing per script.** Adding one 1.6-only command to an old script puts
  the whole script under 1.6 rules. Real EasyUO behaved the same way (one version for everything),
  and the documentation must say it plainly.

### 6.2 Choosing the logic

- **When:** once, when a stopped script is started (`TEuoInterpreter.Clear`, the point where
  Reforged resets a script today). The choice holds for the whole run. An `EXIT` restart keeps it.
  It is never changed mid-run: controls built under one naming model cannot be translated into
  the other, and behaviour would depend on which branch ran first.
- **Rule, in this order:**
  1. A `menu reforge mode 1.5` or `menu reforge mode 1.6` line in the main script (§6.3)
     decides.
  2. Otherwise, if any scanned line is `menu` followed by one of the nine 1.6-only sub-commands
     (`form`, `panel`, `radio`, `getprop`, `setprop`, `getdef`, `setdef`, `pushdef`, `popdef`), the
     script gets **1.6 logic**. The scanned lines are the main script's, plus, when the main
     script contains `menu reforge includecall #true`, those of the files it calls (next items).
  3. Otherwise it gets **1.5 logic**.
- **Only real code counts.** Comments are skipped with the interpreter's own line rules (3 of the
  125 scanned scripts mention 1.6 commands only in comments). A sub-command taken from a variable
  (`menu %x …`) cannot be seen; in the corpus this only ever selects `list` or `combo`.
- **Called files, by default:** not pre-scanned. Only the main script is read. Whatever the
  detection decides, called files run under the main script's logic, as in real EasyUO, where one
  version ran everything.
- **Called files with `menu reforge includecall #true`:**
  - The detection also reads every file the script calls with a literal name, resolved the way
    `call` resolves it at runtime: a relative name is taken from `#CurPath` (EasyUO's own folder,
    not the script's), then `.txt` and `.euo` are tried when the name as given does not exist.
  - The scan is recursive (files called by called files) and visits each file once, so a call
    cycle cannot loop.
  - A name built at runtime (`call %lib`) cannot be resolved in advance and is skipped; so is a
    file that does not exist. In the corpus, 17 of the 23 scripts that use `call` build the name
    at runtime.
- **A 1.6 command reached in 1.5 logic** does nothing, as in real EasyUO 1.5. Reforged also tells
  the user once per run, without stopping the script, that the script needs
  `menu reforge mode 1.6` (or `menu reforge includecall #true`, when the command came from a
  called file). This covers the cases the scan cannot see.
- **Changing logic between runs:** if a tab's script starts with a different logic than its
  previous run, the previous logic's windows are taken down first: the 1.5 window is hidden
  (not closed, so its `#MenuButton` is left alone) and emptied, the 1.6 windows are destroyed.
- **Cost:** one pass over the script text at start (the largest scanned script has about 5,000
  lines), plus reading the called files when `includecall` is on, plus one indirect call per MENU
  command. Every MENU command already pays a hop to the main thread, which costs far more.
- **Visible to the user:** the editor shows the logic in use for the running script, e.g. in the
  status bar (exact place to be chosen when implementing).

### 6.3 Script settings: `menu reforge`

`menu reforge` is a Reforged sub-command that holds MENU settings for the script. It has two
settings:

| Line | Values | Effect |
|---|---|---|
| `menu reforge mode {logic}` | `1.5` or `1.6` | Forces that logic for the whole run; automatic selection is skipped. |
| `menu reforge includecall {flag}` | `#true` or `#false` (also `true`/`false`, `1`/`-1`/`0`) | `#true`: the automatic selection also scans the files the script calls (§6.2). `#false` (the default): only the main script is scanned. |

Common rules:
- **Read before the run.** Both settings are read from the main script's text before it starts, so
  their position does not matter; the top of the script is the conventional place. For each
  setting, the first line with a valid value wins; commented-out lines are not read. A forced `mode` makes `includecall`
  irrelevant.
- **Literal values only.** The value must be written literally. A variable (`menu reforge mode %m`)
  cannot be read before the run and is ignored, as is any value outside the lists above;
  automatic selection then applies.
- **Main script only.** In a called file the lines have no effect; the documentation says so.
- **At runtime** the lines do nothing, in both logics. Real EasyUO 1.5 and 1.6 ignore unknown
  `menu` sub-commands, so a script that contains them still runs there.
- **Why script lines** and not editor settings: the choice travels with the script, works for
  everyone who runs it, and stays visible in the source. Highlighting and autocomplete offer them
  like any other sub-command. The `reforge` word groups present and future Reforged-only MENU
  settings under one name.

### 6.4 Code structure

| Layer | Unit (working names) | Contents |
|---|---|---|
| Shared platform layer | `parser/EuoMenuCommon.pas` (moved out of `EuoMenu.pas`) | `TEuoMenuForm` (stay-on-top, own taskbar button, keyboard shortcuts, `Surface` panel), `TEuoMenuButton`, Symbol-font remapping, 24 bpp image setup and mask invalidation, image file loading, image drawing primitives, repaint bursts generalised to several forms, colour parsing and Delphi ↔ LCL system-colour conversion. Everything that exists because of LCL/Windows rather than because of EasyUO. |
| 1.5 logic | `parser/EuoMenu.pas` (today's `TMenuObj`) + today's `MenuProcSync` dispatcher | Unchanged behaviour. The only edit is using the moved classes from the shared unit. |
| 1.6 logic | `parser/EuoMenu16.pas` | Registry with unique lower-case names and the protected form0; the defaults object and the `pushdef` list; the property table; form, panel, radio and the other controls; lifecycle (start, `clear`, `delete`); `#MenuButton`/`#MenuRes` semantics; and its own dispatcher, a port of `TOldParser.MenuProc` at `0x4c120c` with the same argument checks and sub-command order. |
| Selection | `parser/EuoInterpreter.pas` | Holds the menu as an abstract `TMenuSystem` with a 1.5 and a 1.6 subclass. The interpreter runs the detection (§6.2) and delegates `menu …`, `#MenuButton` and `#MenuRes` to the chosen implementation. |

Each new unit gets the usual header comment: what it ports, from where, and every deliberate
deviation. `EuoInterpreter.pas`'s list of must-preserve behaviours gets the 1.6 ones.

### 6.5 What each logic does

**1.5 logic** is exactly today's Reforged MENU: duplicate names act on all; `menu hide` sets
`CLOSED`; `menu clear` keeps `#MenuButton`; the window survives a restart; `font transparent`,
`hideeuo`, `image pixline` and `TShape` shapes work. `#MenuButton`/`#MenuRes` keep their value
between runs, as in 1.5. The nine 1.6-only sub-commands do nothing, apart from the notice in §6.2.

**1.6 logic** is EasyUO 1.6.0.337 as described in §3 and checked at runtime in §9.1. In
particular:
- **Names:** unique and stored lower-case; a duplicate is shown but unreachable; a duplicate form
  becomes a hidden orphan that still receives the following controls.
- **`#MenuButton`:** lower-case names; `form0` reads back as `CLOSED`; closing any other form gives
  its name; emptied by `menu clear` and at script start. `#MenuRes` is also emptied at start.
- **`menu hide` / `menu show`:** hide only hides. Show sets the window topmost. Both do nothing
  once form0 has been deleted.
- **Windows:** script start destroys every menu window and creates a hidden form0 at 100,100,
  305×180. `menu form` adds the frame difference to the client size (10 px on Windows 10/11).
- **Defaults:** `pushdef`/`popdef` in 1.6's FIFO order, with alignment lost; colour names in
  `setprop`/`setdef` give 0; `getprop … parent` on an unregistered parent returns the previous
  string result.
- **Shapes:** emulated as images; the line is solid or absent, and only fill type 7 is solid.
- **Ignored commands:** `font transparent`, `hideeuo`, `image pixline` and `test`.
- **Validation:** negative widths and corners are rejected, and an invalid line width draws
  width 1.

Deliberate deviations, each listed on `reforged/known-limitations.md`:
- `image …` on a control that is not an image is ignored. In 1.6 it writes into the wrong object
  and can crash.
- The button is `TEuoMenuButton` and images are 24 bpp, as in 1.5 logic (platform reasons
  already documented in `EuoMenu.pas`).
- Anything LCL cannot reproduce, found while implementing. One example to check:
  `setprop … parent` into a button or a radio button, which 1.6 allows.

Reforged additions in 1.6 logic:
- **`menu memo`:** included, with the same syntax as in 1.5 logic. It is a control type with the
  same properties as `edit`; `text` converts `$` to and from line breaks, as `menu get`/`menu set`
  do. It follows the 1.6 rules for names and parents like every other control.
- **`menu reforge`:** both its settings work the same in both logics.
- **Shared layer:** Symbol-font remapping and repaint bursts belong to it and apply to both logics.

### 6.6 Where 1.5 and 1.6 differ

This table is the source for the documentation's comparison page (§6.8). Evidence refers to §9.

| Behaviour | 1.5 logic | 1.6 logic | Notes |
|---|---|---|---|
| Duplicate names | All controls with the name act; `get`/`activate` use the first | Only the first is reachable; `delete` removes only it, the rest stay on screen | Mining Radar F002 needs 1.5; 1.6 scripts give interactive controls unique names |
| `#MenuButton` | Upper-case name; `CLOSED` on × and on `menu hide`; kept by `clear` and between runs | Lower-case name; `CLOSED` only for form0's ×, other forms give their name; emptied by `clear` and at start | Hort-o-Matic 2.0 tests `CLOSED` after `clear`: needs 1.5 |
| `#MenuRes` | Kept between runs | Emptied at start | |
| Script start | Controls freed, window kept as it was | Every window destroyed, hidden form0 at 100,100, 305×180 | Stopping keeps windows in both |
| form0 | Not a name; sizeable frame, 10,10, 200×100 outer | A control named `form0`; single frame, no maximize; can be deleted | |
| Forms, panels, radio buttons, properties, defaults | — | `form`, `panel`, `radio`, `getprop`, `setprop`, `getdef`, `setdef`, `pushdef`, `popdef` | `menu form` client area +10 px each way |
| `menu activate` | Edit, button, combo, list, check on form0 | Any control; brings its form to the front | |
| `menu get` / `menu set` | Edit, combo, list, check (+ text, button for `set`; memo) | Also radio buttons | |
| `menu shape` | `TShape`: dashed lines, hatch fills, rounded corners | Image: solid line or none, fill only with type 7; can be drawn on | |
| `font transparent` | Works | Ignored, labels always opaque | Used by 108 of 125 scripts |
| `hideeuo`, `image pixline` | Work | Ignored | |
| Validation | Negatives accepted; invalid line width draws nothing | Negatives rejected; invalid width draws width 1 | |
| `menu memo` | Reforged addition | Reforged addition (same syntax; 1.6 naming and parents) | |
| `menu reforge mode`, `menu reforge includecall` | Reforged settings | Same | Read before the run (§6.3) |

### 6.7 Tests

- **1.5 logic:** the existing MENU tests run unchanged and must keep passing. That is the proof
  that the 1.5 path did not move.
- **Selection:**
  - scripts with and without 1.6 sub-commands;
  - 1.6 words in comments only;
  - `menu reforge mode` in both directions, invalid and variable values, and in a called file;
  - `menu reforge includecall`:
    - off by default;
    - with `#true`, a 1.6 command only in a called file selects 1.6;
    - recursive calls and a call cycle;
    - `.txt`/`.euo` resolution;
    - a missing file;
    - a runtime-built name, which is skipped;
    - a forced `mode` taking precedence;
  - a sub-command taken from a variable;
  - the choice fixed for the whole run;
  - windows destroyed when the logic changes between runs;
  - the notice for a 1.6 command in 1.5 logic.
- **1.6 logic against golden values:**
  - Add `tests/tools/Record16MenuGolden.py`: the probe harness used in §9.1, which needs the
    closed `easyuo.exe` passed explicitly (`-Exe`), like `VerifyCstDbData.ps1 -OrigFile`.
  - It writes the observed values to `tests/fixtures/menu16/`.
  - The FPCUnit tests assert Reforged's 1.6 logic against that fixture without needing the binary.
- **Hand tests** (`.euo`, each ending with `halt`):
  - Cheffe's alpha demo adapted to 1.6;
  - Gaderian's tutorial examples;
  - local copies of real scripts in both logics: Mining Radar F002 (1.5) and the BOD Filler
    `form`/`setprop` code (1.6).

### 6.8 Documentation

All in `website/`, in the same change as the code. The commands are documented as follows.

1. **A dedicated comparison page:** `commands/menu/versions.md` ("MENU: EasyUO 1.5 and 1.6"). It
   is a prose page with no `kind`, so the coverage check does not treat it as a reference page.
   Contents:
   - why there are two systems (open source vs the closed 1.6 builds, about 2017);
   - how Reforged picks one, with examples;
   - how to force one with `menu reforge mode`, and how `menu reforge includecall` extends the
     detection to called files;
   - what "all or nothing per script" means, and that `call`ed files follow the main script;
   - **a table of every MENU sub-command** (including `font …`, `image …`, `window …`) with its
     availability, *1.5 only / 1.6 only / both*, and a "differs" mark linking to the explanation;
   - the differences in detail (§6.6), with short examples;
   - tips for moving a script from one logic to the other.

   The MENU index links to it at the top.
2. **Availability on every sub-command page:**
   - **A new frontmatter field**, e.g. `menuLogic: ['1.5', '1.6']`, on every page under
     `commands/menu/`. It goes in `src/content.config.ts`, and `src/components/refdata.ts` makes it
     required for MENU pages.
   - **Badges:** `RefHeader.astro` shows *1.5 only*, *1.6 only* or *1.5 and 1.6*, plus *Differs
     between 1.5 and 1.6* when `menuDiffers: true`.
   - **Explanation:** pages available in both logics that behave differently get a "1.5 and 1.6"
     section explaining exactly how. `tests/tools/CheckDocsCoverage.ps1` checks that the section
     exists whenever `menuDiffers` is set.
   - **Pages to add or change:**
     - nine new pages for the 1.6 sub-commands;
     - `commands/menu/reforge/mode.md` and `commands/menu/reforge/includecall.md`, laid out like
       `commands/menu/font/*.md`, with `origin: reforged` and available in both logics;
     - 1.5-only pages (`hideeuo`, `font transparent`, `image pixline`) say what 1.6 logic does
       with them;
     - `memo` is marked available in both, with a "1.5 and 1.6" section on naming and parents.
3. **How to force a logic and include called files:**
   - the two `menu reforge` pages: syntax, values, literal-only values, placement, portability,
     no effect in called files; for `includecall`, how names are resolved, what cannot be
     scanned, and that a forced `mode` wins;
   - a section on the comparison page;
   - a short paragraph near the top of the MENU index.
4. **Related pages:**
   - `#MenuButton` and `#MenuRes` get "1.5 and 1.6" sections;
   - `reforged/whats-new.md` lists the 1.6 MENU and `menu reforge`;
   - `reforged/known-limitations.md` lists the 1.6 deviations (§6.5) and the all-or-nothing switch.
5. **Credit to the ScriptUO community**, alongside the existing credit to the EasyUO wiki. No
   ScriptUO text is copied, so there is no licence to carry; this is an acknowledgement.
   - **Footer:** a frontmatter flag (e.g. `credits: ['scriptuo']`) makes `MarkdownContent.astro`
     add a line at the bottom of the page, next to where the wiki's GFDL notice goes today. For
     example: *"The EasyUO 1.6 behaviour on this page was researched with help from the ScriptUO
     community: Gaderian's tutorial 'New Menu Code and how to adapt old scripts' and the scripts
     its members share at scriptuo.com."*
   - **Where the footer goes:** the comparison page, the nine 1.6 pages, every page with a
     "1.5 and 1.6" section, and the `#MenuButton`/`#MenuRes` pages.
   - **Repository files:** `NOTICE` gets an "Acknowledgements" paragraph after "Documentation":
     ScriptUO (scriptuo.com), Gaderian's tutorial, the script authors whose public scripts were
     studied, and the EasyUO forum's menu-enhancement discussion. `README.md` gets one line next
     to the wiki line.
6. **Tooling:**
   - `tests/tools/EuoNames.ps1` reads the sub-command names from both dispatchers, including
     `reforge`;
   - `easyuo/eusyntax.pas` (highlighting) and `easyuo/eucomplete.pas` (autocomplete) learn the new
     words, including `menu reforge mode` and `menu reforge includecall`.
7. **Origin of the 1.6 commands:** the `origin` field only knows `original` (1.5) and `reforged`.
   Proposed: keep `origin` for "who added it" and let `menuLogic` carry the EasyUO version, so the
   1.6 sub-commands stay `origin: original`. The schema comment is updated to say so.
8. `npm run build` in `website/` must pass.

### 6.9 This document

`docs/menu-1.6-analysis.md` stays in the repository, next to `sql.md` and `pathfinding.md`, as the
reference for the 1.6 logic and for later reviews.
- `docs/architecture.md` links it where it describes `EuoMenu`.
- `EuoMenu16.pas`'s header links it, and is in turn referenced by `CLAUDE.md`'s architecture notes.
- It was committed on its own, before implementation started. §3 is corrected whenever the
  implementation finds something new.

### 6.10 Order of work

1. Move the platform classes into the shared unit, with no behaviour change; all tests green.
2. `TMenuSystem`, the selection, `menu reforge mode`/`includecall` and the notice, with 1.6 as an
   empty stub; selection tests.
3. Record the 1.6 golden values; the recorder script goes in `tests/tools/`.
4. The 1.6 logic: registry, defaults, properties, controls, lifecycle, dispatcher; golden tests.
5. Editor: logic indicator, highlighting, autocomplete.
6. Documentation (§6.8) and coverage tooling.
7. Hand tests with real scripts in both logics.
8. `docs/architecture.md`, `CLAUDE.md` notes, `NOTICE`/`README.md` acknowledgements, memory.

## 7. Why separate implementations, and is the detection reliable?

A global setting was rejected first: users run old and new scripts side by side, so a single
choice breaks one family. Between the superset (§9) and per-script separation, separation was
chosen (§6.1). Its weak point is the detection, which was checked on the same 125 real scripts
(ScriptUO, 2026-10-28):

| Check | Result |
|---|---|
| Scripts using a 1.6-only sub-command | 8, and all 8 need 1.6 (4 also contain 1.5-only commands, which 1.6 ignores, exactly as their authors saw it) |
| 1.6-era scripts using only old commands | About 15; every relevant case examined works as well or better under 1.5 logic (Mining Radar F002, Hort-o-Matic 2.0 need it) |
| 1.6 words only in comments | 3 scripts, hence comments are skipped |
| Sub-command from a variable | 8 scripts, all the same snippet choosing `list` or `combo`; never a 1.6 command |
| `call` | 23 scripts with MENU use it, 17 with a runtime file name; no real case of a 1.5 script calling a 1.6 library (one apparent hit was a file-name collision) |

The guarantee is therefore:
- every script that uses the 1.6 commands gets 1.6 logic;
- every other script gets exactly today's behaviour;
- `menu reforge mode` covers the rest; `menu reforge includecall #true` covers 1.6 libraries
  called by name; the runtime notice points users to both.

## 8. Decisions still open

Settled by the owner on 2026-10-28:
- The `menu reforge mode` / `menu reforge includecall` syntax (§6.3).
- Called files are not scanned by default.
- `menu memo` is part of the 1.6 logic.
- ScriptUO is credited in the documentation (§6.8 item 5).

Still open, each with a recommendation; none blocks starting at step 1 of §6.10:
1. **The notice for a 1.6 command in 1.5 logic:** recommended once per run, in the editor's
   output/status area. The exact channel is chosen when implementing.
2. **Where the editor shows the logic in use:** status bar (recommended) or tab caption.
3. **Frontmatter names for the docs** (`menuLogic`, `menuDiffers`, `credits`): as proposed in §6.8.
4. **`setprop … parent` into non-container controls:** keep 1.6's permissive behaviour if LCL
   handles it, otherwise restrict it and list it as a deviation.
5. **Exact wording of the ScriptUO acknowledgement:** a draft is in §6.8 item 5.

## 9. Deep review of the superset (2026-10-28)

The superset reviewed here was the first design; it was replaced by separate implementations (§6.1).
The runtime checks, the corpus and the prototype below remain the evidence base for the 1.6 logic and
for the detection (§7).

### 9.1 Runtime checks in the real binary

The 1.6 exe was run unelevated (`__COMPAT_LAYER=RunAsInvoker`; MENU needs no elevation) with probe
scripts that report through form captions, driven from a throwaway Python harness (window
enumeration, `BM_CLICK`, `WM_CLOSE`, Start/Stop through `WM_COMMAND`, `PrintWindow` screenshots).
`HKCU\Software\EasyUO` was backed up first; only its Reopen list changed. A script passed on the
command line is loaded but not started.

Confirmed: form0 defaults (100,100, 305×180, hidden, `EUO Menu`) and defaults (Arial 10, black,
`clBtnFace`, left, parent form0); duplicates (first one acts, `delete` removes only it, the second
label stays visible, a click on the second button changes nothing, the name is free again after
the delete); `menu hide` leaves `#MenuButton`; `menu clear` empties it and keeps form0's size and
visibility; FIFO `popdef` and lost alignment; colour names give 0 in `setprop`/`setdef`;
non-numbers give 0 or `#true`; unknown properties leave `#MenuRes`; a duplicate form is a hidden
orphan that becomes the default parent; closing form `f2` gives `f2`, form0 gives `CLOSED`, and
`set #MenuButton form0` reads back `CLOSED`; radio groups per parent; `setprop parent` works, even
into a radio button; deleting a panel deletes its children; deleting the default-parent panel leaves
later controls parentless; `delete form0` survives `menu clear`; Stop keeps all windows, Start
destroys them and rebuilds form0; shapes as images (dashed → solid, hatch and type 0 → no fill,
rounded → square, drawing on a shape works); `font transparent` ignored; negative `x2` not drawn;
invalid line width → 1; a popup sub called twice shows only the first popup.

Corrected by it: forms are 10 px larger than asked (§3.2), and `window title` with no text clears the
title as before.

### 9.2 Real scripts

ScriptUO (logged in): every thread active since 2017 in the EasyUO script boards (408 threads, 417
`.txt`/`.euo` attachments, 232 using MENU, 125 distinct scripts when keeping the latest file per
thread, 23 posted since 2017), plus five scripts already on this machine. Read in the browser and
scanned statically; nothing was executed.

- 1.6 commands in 8 of 125 scripts: `form` (5), `setprop` (8), `setdef` (2). No `panel`, `radio`,
  `getprop`, `getdef`, `pushdef`, `popdef`.
- The typical 1.6-era script is an old form0 menu, sometimes with `setprop … visible` toggles
  (BOD Filler 2021) and fixed to give *interactive* controls unique names; decorative duplicates
  remain (Mining Radar F002).
- Per-behaviour findings are in the Notes column of §6.6. For the superset they were per-conflict
  evidence:
  - no script compares `#MenuButton` with `CLOSED` after a `menu hide` without resetting it first;
  - Hort-o-Matic 2.0 needs `menu clear` to keep `#MenuButton`;
  - 47 scripts read `#MenuButton` before setting it;
  - no recent script re-creates a transparent label over itself;
  - 26 scripts address a name they created more than once.

Limits: only ScriptUO; scripts on the easyuo.com forum were not scanned. The analysis is static,
so control flow is approximated (every flagged case was checked by hand).

### 9.3 LCL prototype

A standalone LCL program (scratchpad, not in the repo) built and run with the project's Lazarus
3.6 / FPC 3.2.2. All checks passed:
- several `TEuoMenuForm`-style forms (stay-on-top, own `Surface`);
- `bsSingle` client size;
- panels and nested panels with relative coordinates;
- moving a self-painted button and a label between forms;
- radio groups per parent;
- `Alignment` on check and radio boxes;
- hints and visibility on graphic controls;
- font style bits;
- Delphi-encoded system colours painting correctly;
- repaint holds on two forms at once;
- closing and re-showing a secondary form;
- children of a hidden form getting handles when it is shown.

Two facts that shape the code:
- `TWinControl.Destroy` detaches children without freeing them, so recursive delete frees them itself.
- Switching a form to `bsSingle` keeps its client size in LCL, so 1.6's +10 px must be added
  explicitly.

### 9.4 Verdict

The superset works.
- **Old scripts:** they behave exactly as today, except that `#MenuButton` and `#MenuRes` start
  empty on each run.
- **1.6 scripts:** they get the 1.6 behaviour everywhere except:
  - where 1.6 itself is broken (§3.8);
  - where the corpus shows scripts depending on the old behaviour (`menu hide`, `menu clear`,
    `font transparent`, shapes).

Remaining risks:
- A script outside the scanned corpus that relies on a 1.6-only quirk.
- Differences between 1.6 builds (337 analysed; Mining Radar F002 was tested on 335).
- Visual details of fonts and buttons, which were not compared.
