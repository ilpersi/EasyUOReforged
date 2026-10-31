---
title: The canvas
description: "Adding, selecting, moving, resizing, aligning and snapping components in the MENU Designer."
sidebar:
  order: 2
---

Each tab shows one form at its real size, under a title bar the designer draws. The controls on it are
the real ones the script will make: a button never clicks, a field never takes the keyboard, a combo box
never opens. A thin grey frame marks each [panel](/designer/components/#panel), which is often the
colour of its form.

## Adding

Click a kind of control in the palette, then click the form or a panel. The control goes into the form or
panel you click, at the grid point nearest the click, with its default size and a free name
(`button1`, `button2`, ...). **Esc** cancels.

A new form comes from *Form → New form*. See [Several forms](/designer/forms/).

## Selecting

- **Click** a control to select it. Click empty space on the form to select the form.
- **Shift+click** adds a control to the selection, or takes it out.
- **Drag** on empty space to select every control the rectangle touches.
- **Ctrl+A** selects everything on the form.
- Clicking a name in the **Structure** tree selects it too.

The inspector shows the first selected component.

## Moving and resizing

- **Drag** a control to move it; every selected control moves with it.
- **Drag a handle** to resize. A text fits itself to its words, and an edit's and a combo box's height
  comes from the font: dragging those handles gives the control a fixed size, which the script then sets
  (see [Sizes a control gives itself](/designer/inspector/#sizes-a-control-gives-itself)).
- A form grows from its right and bottom handles.
- **Arrow keys** move the selection by one pixel, **Shift+arrows** by one grid step, and **Ctrl+arrows**
  change its size.
- **Drop** a single control onto a panel, or onto empty space of the form, to move it there.

## Z-order

The script creates controls in their z-order, so the order in the structure tree is the order they are
created in. *Arrange → Bring to front* and *Send to back* move a control to the end or the start of its form
or panel. Windows always draws buttons, fields, lists and panels above texts and images, whatever their
order.

## Aligning

Select two or more controls in the same form or panel, then use the *Arrange* menu or the toolbar. The
first control you selected stays where it is; the others move to it:

- align left, right, top or bottom edges;
- align centres, across or down;
- centre the selection in its form or panel;
- spread across or down, with equal gaps (three or more controls);
- same width, height or size.

## Snapping

While you move or resize, an edge or the centre of the control jumps to:

- an edge or the centre of another control in the same form or panel, or of the form or panel itself,
  when it is within 4 pixels; a pink line shows what it lined up with;
- otherwise, the nearest grid point.

Hold **Alt** to move freely. The *View* menu turns the grid, snapping to the grid and snapping to components
on and off, and sets the grid size (8 pixels to start with). These settings belong to the designer, not to
the file.

## Preview

**F9** (*View → Preview*) runs the whole file and shows its windows as the script will: in their places on
the screen, on top of other windows. Forms set to be shown appear; the others stay hidden, as they would.
The status bar shows [`#MenuButton`](/variables/menubutton/) as you click. Press **F9** again to close them.
