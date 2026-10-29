---
title: "MENU: EasyUO 1.5 and 1.6"
description: "The two MENU systems Reforged runs, how it picks one for a script, how to choose it yourself, and every difference between them."
credits: ['scriptuo']
---

EasyUO has two different `menu` systems, and EasyUO Reforged runs both. Each script runs under one of them,
the **1.5 logic** or the **1.6 logic**, chosen when the script starts.

## Why there are two

- **EasyUO 1.5** is the version whose source code was published. Its `menu` builds one window with
  controls in it. Reforged is a port of that source, so this is the `menu` most scripts were written for.
- **EasyUO 1.6** came later, around 2017, as closed builds. Its author rewrote `menu`: any number of
  windows ([`menu Form`](/commands/menu/form/)), containers ([`menu Panel`](/commands/menu/panel/)),
  radio buttons, and reading and changing any property of any control
  ([`menu GetProp`](/commands/menu/getprop/), [`menu SetProp`](/commands/menu/setprop/)). The rewrite also
  changed how the old sub-commands behave in places: names, [`#MenuButton`](/variables/menubutton/), what
  happens when a script starts.

Neither is a superset of the other. A script written for 1.6 shows nothing under 1.5, and some scripts
written for 1.5 misbehave under 1.6. Reforged's 1.6 logic is a port of what EasyUO 1.6.0.337 does, checked
against the real program; the few places where it differs on purpose are on
[Known limitations](/reforged/known-limitations/).

## How Reforged picks one

When a stopped script starts, Reforged reads its text once:

1. A [`menu Reforge Mode`](/commands/menu/reforge/mode/) line decides: `1.5` or `1.6`.
2. Otherwise, a `menu` line using any of the nine sub-commands only 1.6 has selects the 1.6 logic:
   [`Form`](/commands/menu/form/), [`Panel`](/commands/menu/panel/), [`Radio`](/commands/menu/radio/),
   [`GetProp`](/commands/menu/getprop/), [`SetProp`](/commands/menu/setprop/),
   [`GetDef`](/commands/menu/getdef/), [`SetDef`](/commands/menu/setdef/),
   [`PushDef`](/commands/menu/pushdef/) and [`PopDef`](/commands/menu/popdef/).
3. Otherwise, the 1.5 logic.

```euo
menu Form main 300 200 260 50 My tool   ; 1.6-only: this script runs under the 1.6 logic
menu Text t 10 10 Built with menu Form.
menu SetProp main visible #true
halt
```

```euo
menu Clear
menu Text status 10 10 Waiting...       ; only sub-commands both have: the 1.5 logic
menu Show
halt
```

Only real `menu` lines count: a sub-command in a comment does not, and neither does one that comes from a
variable (`menu %what ...`), which is only known once the line runs. Files the script pulls in with
[`call`](/commands/call/) are not read, unless the script says
[`menu Reforge IncludeCall #true`](/commands/menu/reforge/includecall/).

The editor's status bar shows which logic the script runs, or ran last: `MENU 1.5`, `MENU 1.6`, or
`MENU 1.6 (forced)` when `menu Reforge Mode` chose it. If a 1.6-only sub-command does run under a 1.5 logic
that was chosen for you, Reforged says so once per run, in a message box, and tells you which line to add.
The script keeps running; under 1.5 that line does nothing.

## Choosing it yourself

Put a `menu Reforge Mode` line in the main script, usually at the top:

```euo
menu Reforge Mode 1.6
set %make Form
set %change SetProp
menu %make main 300 200 260 50 Chosen by menu Reforge Mode
menu Text t 10 10 Form and SetProp come from variables.
menu %change main visible #true
halt
```

It is read before the script runs, wherever it is, so it works even in a script whose 1.6 sub-commands all
come from variables or from called files. The value must be written as `1.5` or `1.6`; a variable is not
read. EasyUO 1.5 and 1.6 themselves ignore the line, so a script that has it still runs there.

[`menu Reforge IncludeCall #true`](/commands/menu/reforge/includecall/) makes the automatic choice read
the files the script calls too.

## One logic for the whole run

The choice holds for the whole run, for the main script and every file it calls, as in EasyUO, where one
version ran everything. The two logics cannot be mixed: a window built by one is unknown to the other. To
change logic, stop the script and start it again; the windows of the old logic are taken down first.

## Which sub-commands each has

**Differs** links to how the sub-command behaves differently in the two.

| Sub-command | 1.5 | 1.6 | |
|---|:-:|:-:|---|
| [menu Activate](/commands/menu/activate/) | ✓ | ✓ | [Differs](/commands/menu/activate/#15-and-16) |
| [menu Button](/commands/menu/button/) | ✓ | ✓ | [Differs](/commands/menu/button/#15-and-16) |
| [menu Check](/commands/menu/check/) | ✓ | ✓ | [Differs](/commands/menu/check/#15-and-16) |
| [menu Clear](/commands/menu/clear/) | ✓ | ✓ | [Differs](/commands/menu/clear/#15-and-16) |
| [menu Combo](/commands/menu/combo/) (Create, Add, Select, Clear) | ✓ | ✓ | [Differs](/commands/menu/combo/#15-and-16) |
| [menu Delete](/commands/menu/delete/) | ✓ | ✓ | [Differs](/commands/menu/delete/#15-and-16) |
| [menu Edit](/commands/menu/edit/) | ✓ | ✓ | [Differs](/commands/menu/edit/#15-and-16) |
| [menu Font Align](/commands/menu/font/align/), [BgColor](/commands/menu/font/bgcolor/), [Color](/commands/menu/font/color/), [Name](/commands/menu/font/name/), [Size](/commands/menu/font/size/), [Style](/commands/menu/font/style/) | ✓ | ✓ | |
| [menu Font Transparent](/commands/menu/font/transparent/) | ✓ | | ignored by 1.6 |
| [menu Form](/commands/menu/form/) | | ✓ | |
| [menu Get](/commands/menu/get/) | ✓ | ✓ | [Differs](/commands/menu/get/#15-and-16) |
| [menu GetDef](/commands/menu/getdef/) | | ✓ | |
| [menu GetNum](/commands/menu/getnum/) | ✓ | ✓ | [Differs](/commands/menu/getnum/#15-and-16) |
| [menu GetProp](/commands/menu/getprop/) | | ✓ | |
| [menu Hide](/commands/menu/hide/) | ✓ | ✓ | [Differs](/commands/menu/hide/#15-and-16) |
| [menu HideEUO](/commands/menu/hideeuo/) | ✓ | | ignored by 1.6 |
| [menu Image Create](/commands/menu/image/create/) | ✓ | ✓ | [Differs](/commands/menu/image/create/#15-and-16) |
| [menu Image Ellipse](/commands/menu/image/ellipse/), [Line](/commands/menu/image/line/), [Rectangle](/commands/menu/image/rectangle/) | ✓ | ✓ | [Differs](/commands/menu/image/line/#15-and-16) |
| [menu Image File](/commands/menu/image/file/), [FloodFill](/commands/menu/image/floodfill/), [Pix](/commands/menu/image/pix/) | ✓ | ✓ | |
| [menu Image PixLine](/commands/menu/image/pixline/) | ✓ | | ignored by 1.6 |
| [menu Image Pos](/commands/menu/image/pos/) | ✓ | ✓ | [Differs](/commands/menu/image/pos/#15-and-16) |
| [menu List](/commands/menu/list/) (Create, Add, Select, Clear) | ✓ | ✓ | [Differs](/commands/menu/list/#15-and-16) |
| [menu Memo](/commands/menu/memo/) (Reforged) | ✓ | ✓ | [Differs](/commands/menu/memo/#15-and-16) |
| [menu Panel](/commands/menu/panel/) | | ✓ | |
| [menu PopDef](/commands/menu/popdef/), [menu PushDef](/commands/menu/pushdef/) | | ✓ | |
| [menu Radio](/commands/menu/radio/) | | ✓ | |
| [menu Reforge Mode](/commands/menu/reforge/mode/), [IncludeCall](/commands/menu/reforge/includecall/) (Reforged) | ✓ | ✓ | |
| [menu Set](/commands/menu/set/) | ✓ | ✓ | [Differs](/commands/menu/set/#15-and-16) |
| [menu SetDef](/commands/menu/setdef/) | | ✓ | |
| [menu SetProp](/commands/menu/setprop/) | | ✓ | |
| [menu Shape](/commands/menu/shape/) | ✓ | ✓ | [Differs](/commands/menu/shape/#15-and-16) |
| [menu Show](/commands/menu/show/) | ✓ | ✓ | [Differs](/commands/menu/show/#15-and-16) |
| [menu Text](/commands/menu/text/) | ✓ | ✓ | [Differs](/commands/menu/text/#15-and-16) |
| [menu Window Color](/commands/menu/window/color/), [Size](/commands/menu/window/size/), [Title](/commands/menu/window/title/), [Transparent](/commands/menu/window/transparent/) | ✓ | ✓ | |

## The differences in detail

### Names

- **1.5:** several controls may share a name. [`menu Set`](/commands/menu/set/),
  [`menu Delete`](/commands/menu/delete/), `combo`/`list` `Add`, `Select` and `Clear`, and the
  `menu Image` drawing commands act on **all** of them; [`menu Get`](/commands/menu/get/) and
  [`menu Activate`](/commands/menu/activate/) use the first.
- **1.6:** a name belongs to one control. A second control created with a taken name still appears, but no
  command can reach it: `menu Set` changes the first, `menu Delete` removes only the first, and a click on
  the second button records nothing. Names are not case-sensitive and are kept in lower case.

```euo
menu Clear
menu Window Size 200 70
menu Text status 10 10 one
menu Text status 10 30 two
menu Set status three       ; 1.5: both labels say "three". 1.6: only the first does.
menu Show
halt
```

### #MenuButton and #MenuRes

| | 1.5 | 1.6 |
|---|---|---|
| A button click | the button's name in capitals | the button's name in lower case |
| The window's × | `CLOSED` | `CLOSED` for the main window; another [`menu Form`](/commands/menu/form/) gives its own name |
| [`menu Hide`](/commands/menu/hide/) | `CLOSED` | unchanged |
| [`menu Clear`](/commands/menu/clear/) | unchanged | emptied |
| A script starting | unchanged: the last run's value | `#MenuButton` and `#MenuRes` emptied |

In 1.6, `set #MenuButton form0` reads back as `CLOSED`.

### Starting and stopping

- **1.5:** starting a script frees its controls but leaves the window as it was, shown or hidden.
- **1.6:** starting a script destroys every menu window, then creates a new, hidden main window at 100,100
  with a 305 × 180 inside.

Stopping a script leaves every window as it is in both.

### The main window

In 1.6 the main window is a control called `form0`: [`menu GetProp`](/commands/menu/getprop/) and
[`menu SetProp`](/commands/menu/setprop/) work on it, `menu SetDef parent form0` puts new controls back in
it, and `menu Delete form0` destroys it until the next start. It has a fixed frame without a maximize button.
In 1.5 it is a resizable window that no command can name.

### Shapes

In 1.5 [`menu Shape`](/commands/menu/shape/) is a real shape: dashed lines, hatched fills, rounded
corners. In 1.6 it is drawn into an image: the line is solid or absent, the inside is filled only with fill
type 7, rounded corners are square, and types 1, 5 and 6 shrink the box to a centred square. Because it is
an image, `menu Image` commands can draw on it.

### Labels and the removed sub-commands

1.6 ignores [`menu Font Transparent`](/commands/menu/font/transparent/): its labels always have a
background, in the colour set by [`menu Font BgColor`](/commands/menu/font/bgcolor/). It also ignores
[`menu HideEUO`](/commands/menu/hideeuo/) and [`menu Image PixLine`](/commands/menu/image/pixline/).

### Checks on numbers

1.6 refuses a negative width or height in [`menu Image Create`](/commands/menu/image/create/) and
[`menu Shape`](/commands/menu/shape/), and a negative second corner in `menu Image Line`, `Ellipse` and
`Rectangle`. An invalid line width draws a 1-pixel line in 1.6 and nothing in 1.5.

### Other sub-commands

- [`menu Activate`](/commands/menu/activate/) works on any control in 1.6 and brings its window to the front.
- [`menu Get`](/commands/menu/get/) and [`menu Set`](/commands/menu/set/) also work on radio buttons in 1.6.
- [`menu Image Pos`](/commands/menu/image/pos/) moves any control in 1.6, and stretches an image only when a
  size is given.
- [`menu Show`](/commands/menu/show/) also puts the window on top in 1.6.

## Moving a script from 1.5 to 1.6

- Give every control its own name, at least those the script changes, reads or deletes later.
- Set `#MenuButton` to `N/A` before waiting for a click. (Its case changes, from `OK` to `ok`, but `=`
  ignores case.)
- Don't wait for `CLOSED` after `menu Hide`: in 1.6 hiding is silent.
- Instead of `menu Font Transparent`, give labels the colour of what is behind them.
- Check shapes that use dashed lines, hatching or rounded corners.
- Add `menu Reforge Mode 1.6` at the top, so Reforged does not depend on detecting it.

## Moving a script from 1.6 to 1.5

The nine 1.6-only sub-commands do nothing in 1.5. Build a single window with
[`menu Window`](/commands/menu/window/size/) and [`menu Show`](/commands/menu/show/) instead of forms, place
controls directly instead of in panels, use check boxes instead of radio buttons, and read values with
[`menu Get`](/commands/menu/get/) instead of `menu GetProp`.
