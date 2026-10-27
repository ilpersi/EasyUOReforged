#!/usr/bin/env python3
"""Writes the uo.dll reference pages of the documentation site (website/src/content/docs/dll/).

Reads uo/uowrap.pas: the UOTbl table (every property and method with its kind and parameter masks),
MGet's case labels (what type each property returns) and the Commands table (the generic calls). The
descriptions of the methods and calls are written below by hand, and every hand-written signature is
checked against UOTbl's masks, so a signature that no longer matches the DLL stops the script.

Properties reuse the description of the #variable of the same name, and that variable page gets a
`dll:` line so the two pages link to each other.

Run it again after changing UOTbl; it overwrites the generated pages (not dll/index.mdx).

Usage:  python tools/docs/gen-dll-ref.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WRAP = ROOT / 'uo' / 'uowrap.pas'
DOCS = ROOT / 'website' / 'src' / 'content' / 'docs'
OUT = DOCS / 'dll'

TYPES = {'n': 'number', 's': 'string', 'b': 'boolean', 'p': 'pointer'}

# --------------------------------------------------------------------------------------------- methods
# name: (signatures [(mask, parameter names)], returns [(name, type, meaning)], description, related, notes)
# Parameter meanings are in PARAMS; a returns entry of None means "nothing".
PARAMS = {
    'x': 'X position.', 'y': 'Y position.', 'z': 'Height.', 'id': 'Object ID, as a number.',
    'index': 'Position in the list, counting from 0.', 'text': 'The text.', 'colour': 'Colour (hue) number.',
    'facet': 'Facet number, as in `CursKind`. Default: the current facet.',
    'count': 'How many clicks. Default: 1.', 'left': 'True for the left button, false for the right.',
    'down': 'Press the button.', 'up': 'Release the button.', 'fast': 'Skip the 150 ms pause before each click.',
    'movecursor': 'Move the real mouse cursor there first.', 'container': 'Container ID, or the ID of a stack to add to.',
    'amount': 'How many to take from a stack.', 'font': 'Font number, as for `event ExMsg`.',
    'macro': 'Macro number, as for `event Macro`.', 'parameter': 'Macro parameter.', 'key': 'Key name, as for `key`.',
    'ctrl': 'Hold Ctrl.', 'alt': 'Hold Alt.', 'shift': 'Hold Shift.', 'tolerance': 'Tiles away that count as arrived.',
    'timeout': 'Milliseconds before giving up.', 'switch': 'Drive the new client afterwards.', 'name': 'Name.',
    'kind': 'Gump kind, as `#ContKind`, as a number.', 'skill': 'Skill code, or `all` for `SkillLock`.',
    'lock': '0 up, 1 down, 2 locked.', 'stat': '`str`, `dex` or `int`.', 'layer': 'Which tile, counting from 1.',
    'icon': 'Buff icon ID.', 'visibleonly': 'False to include hidden items.', 'nooverrides': 'Skip `verdata.mul`.',
    'reference': 'Reference returned by the previous call; 0 the first time.', 'packet': 'The packet\'s bytes.',
    'width': 'Width in tiles.', 'height': 'Height in tiles.', 'filter': 'Filter number, see above.',
    'value': 'Filter value.',
    'fromx': 'X position to plan from.', 'fromy': 'Y position to plan from.', 'fromz': 'Height to plan from.',
    'dir': 'Direction of the step, 0 north to 7 north-west, as `CharDir`. Default: 0.',
    'option': 'Option name, as for `path set`.',
    'x2': 'X of the opposite corner, or of the other end.', 'y2': 'Y of the opposite corner, or of the other end.',
    'z2': 'Height of the other end.', 'cost': 'Extra cost, in hundredths of a step.',
    'what': '`blocks`, `avoid`, `links`, `learned` or `all`. Default: `all`.',
}

METHODS = {
    'BlockInfo': ([('nnnnn', 'x y z width height')], [('data', 'string', 'Two bytes per tile, `width × height × 2` bytes in all: '
                   'row by row from `x`, `y`, each a signed 16-bit number, low byte first.')],
        'Reads the client\'s walkability data for an area of up to 32×32 tiles starting at `x`, `y`, `z`. '
        'For each tile it runs the check the client makes before every step: can a character standing at height '
        '`z` on the tile south of it step north onto it? The answer is the height it would land at, or -128 '
        '(`$FF80`) when it can\'t. The client answers from everything it has loaded (house walls and floors '
        'included); a tile it hasn\'t loaded reads as -128. On a client whose function address is unknown, every '
        'byte is 0.', ['event PathFind', 'path check'],
        'EasyUO 1.5 passed the client\'s function five arguments, but `client.exe` 7.0.117.1 takes six: the sixth '
        'points at a byte it writes. Given five, the client wrote that byte to an address near 0, which crashes '
        'it. EasyUO Reforged passes the sixth. The script command '
        '[`path check`](/commands/path/check/) asks the same of the client one step at a time, from any height '
        'and in any direction.'),
    'CliDrag': ([('n', 'id')], [], 'Picks up an item with the client\'s own drag, like `event Drag`.',
        ['event Drag', 'dll:Drag'], None),
    'Click': ([('nn', 'x y'), ('nnn', 'x y count'), ('nnnb', 'x y count left'), ('nnnbbb', 'x y count left down up'),
               ('nnnbbbbb', 'x y count left down up fast movecursor'), ('nnbbbb', 'x y left down up movecursor')], [],
        'Clicks at `x`, `y` in the client window, like `click`. Defaults: 1 click, left button, press and release, '
        'with the 150 ms pause before each click, without moving the real cursor.',
        ['Click'], 'The last form, `x y left down up movecursor`, is kept only for old programs: it always clicks once, fast.'),
    'CloseClient': ([('', '')], [], 'Closes the attached client, like `terminate uo`.', ['Terminate', 'dll:OpenClient'], None),
    'ContTop': ([('n', 'index')], [], 'Brings a gump to the front, counted from the top gump (0), like `event ContTop`.',
        ['event ContTop', 'dll:GetCont'], None),
    'Custom': ([('s', 'packet')], [], 'Sends a raw packet to the server: `packet` holds its bytes, exactly as the server '
        'expects them.', ['dll:Equip'], 'A malformed packet can get you disconnected. Only for people who know the UO protocol.'),
    'Drag': ([('n', 'id'), ('nn', 'id amount')], [], 'Picks up an item through the server, like `exevent Drag`. '
        'Default amount: 1.', ['exevent Drag', 'dll:CliDrag', 'dll:DropC'], None),
    'DropC': ([('n', 'container'), ('nnn', 'container x y')], [], 'Drops the item last dragged into a container, or onto a '
        'stack, like `exevent DropC`. Without `x` and `y` the server chooses the spot.', ['exevent DropC', 'dll:Drag'], None),
    'DropG': ([('nn', 'x y'), ('nnn', 'x y z')], [], 'Drops the item last dragged on the ground, like `exevent DropG`. '
        'Default height: your own.', ['exevent DropG', 'dll:Drag'], None),
    'DropPD': ([('', '')], [], 'Puts the item last dragged with `Drag` on, like `exevent DropPD`.', ['exevent DropPD', 'dll:Drag'], None),
    'Equip': ([('*', 'id…')], [], 'Equips the items with the given IDs in one request, like `exevent Equip`. Anything that '
        'is not a number is skipped.', ['exevent Equip'], None),
    'ExMsg': ([('nnns', 'id font colour text'), ('ns', 'id text')], [], 'Shows a message above an object, like '
        '`event ExMsg`. The short form uses font 3 and colour 0.', ['event ExMsg', 'dll:SysMessage'], None),
    'FilterItems': ([('n', 'filter'), ('nn', 'filter value')], [('count', 'number', 'How many items are left.')],
        'Narrows the list `ScanItems` made, and returns how many items are left. Filters add up until cleared:\n\n'
        '| `filter` | `value` | Keeps |\n|---|---|---|\n'
        '| 0 | | Clears every filter. |\n'
        '| 1 | item ID | Items with that ID; several add up. |\n'
        '| 2 | item type | Items of that type; several add up. |\n'
        '| 3 | container ID | Items in that container; without a value, in any container. |\n'
        '| 4 | distance | Items on the ground within that distance; without a value, anywhere on the ground. |',
        ['FindItem', 'dll:ScanItems', 'dll:GetItem'], None),
    'GetBuff': ([('n', 'index')], [('id', 'number', 'Icon ID.'), ('cliloc', 'number', 'Cliloc number of the title.'),
        ('name', 'string', 'Title.'), ('description', 'string', 'Second tooltip line.'),
        ('seconds', 'number', 'Seconds left; -1 = no timer.')],
        'Reads one buff of the list `ScanBuffs` made. Returns nil (nothing) when there is no such buff.',
        ['ScanBuffs', '#BuffID', 'dll:ScanBuffs'], None),
    'GetCont': ([('n', 'index')], [('name', 'string', 'Gump name, as `#ContName` but with spaces.'), ('x', 'number', 'Left edge, in pixels.'),
        ('y', 'number', 'Top edge, in pixels.'), ('width', 'number', 'In pixels.'), ('height', 'number', 'In pixels.'), ('kind', 'number', 'As `#ContKind`, as a number.'),
        ('id', 'number', 'Item the gump belongs to; 0 for none.'), ('type', 'number', 'Its type.'),
        ('hp', 'number', 'Health in percent, for a health bar.')],
        'Describes one open gump, counted from the top (0), skipping the ignored ones. Returns nil when there is no '
        'such gump.', ['#ContName', 'IgnoreCont', 'dll:ContTop'], None),
    'GetItem': ([('n', 'index')], [('id', 'number', 'Item or character ID.'), ('type', 'number', 'Its type.'), ('kind', 'number', '0 in a container, 1 on the ground, -1 none.'),
        ('container', 'number', 'Container ID; 0 on the ground.'), ('x', 'number', 'X position: in the world, or inside the container gump.'),
        ('y', 'number', 'Y position.'), ('z', 'number', 'Height.'), ('stack', 'number', 'How many in the stack; 0 for characters.'),
        ('notoriety', 'number', 'As `#FindRep`.'), ('colour', 'number', 'Colour (hue).')],
        'Reads one item of the filtered list, like the `#Find…` variables after `finditem`.',
        ['FindItem', '#FindID', 'dll:ScanItems', 'dll:FilterItems'], None),
    'GetJournal': ([('n', 'index')], [('text', 'string', 'The line.'), ('colour', 'number', 'Its colour.')],
        'Reads one journal line of the list `ScanJournal` made: 0 is the newest.', ['ScanJournal', '#Journal', 'dll:ScanJournal'], None),
    'GetPath': ([('nn', 'x y'), ('nnn', 'x y z'), ('nnnnnnn', 'x y z fromx fromy fromz facet')],
        [('state', 'string', '`ok`, or why there is no route: `nopath`, `budget`, `timeout`, `noclient`, `nomap` or '
          '`error: …`, as `#PathState` after `path find`.'),
         ('count', 'number', 'Steps in the route; 0 without one.'),
         ('steps', 'string', 'Six bytes a step: x and y (2 bytes each, low byte first), the height (1 byte, signed) and '
          'the direction (1 byte: 0 north to 7 north-west, 8 a link). Empty without a route.')],
        'Plans a walking route, like `path find`: from your character on its facet, or from `fromx`, `fromy`, `fromz` on '
        '`facet`, to `x`, `y` (with `z`, to the floor nearest that height). It reads the map files of the attached '
        'client and what the client holds around the character. It doesn\'t walk: walk the steps with `Move` or the '
        'walk macro. The options and rules set with `PathSet`, `PathBlock`, `PathAvoid` and `PathLink` apply. They '
        'belong to this uo.dll handle, not to the scripts in the editor.',
        ['path find', 'dll:PathSet', 'dll:PathCheck', 'dll:Move'],
        'Where EasyUO Reforged can\'t read the walls of player houses (every client but `client_beta.exe` '
        '7.0.117.31), a route can run through a house. Before walking a step, `PathCheck` asks the client about it: '
        'the walker of `path go` does the same.'),
    'GetPix': ([('nn', 'x y')], [('colour', 'number', 'In `$BBGGRR` order.')], 'Reads the colour of a pixel of the client window.',
        ['SavePix', '#PixCol'], 'The client window has to be visible.'),
    'GetShop': ([('', '')], [('found', 'boolean', 'False, with nothing after it, when no shop gump is open.'),
        ('position', 'number', 'Position of the entry, counting from 1.'), ('count', 'number', 'Number of entries.'),
        ('id', 'number', 'Item ID, for `SetShop`.'), ('type', 'number', 'Item type.'), ('available', 'number', 'How many the vendor has.'),
        ('price', 'number', 'Price of one.'), ('name', 'string', 'Item name.')],
        'Reads the entry shown at the top of the shop gump, like `getshopinfo`.', ['GetShopInfo', 'dll:SetShop'], None),
    'GetSkill': ([('s', 'skill')], [('value', 'number', 'In tenths, with bonuses.'), ('base', 'number', 'In tenths, without bonuses.'),
        ('cap', 'number', 'In tenths.'), ('lock', 'number', '0 up, 1 down, 2 locked.')],
        'Reads a skill. `skill` is its code, the first four letters of its name (see `chooseskill`).',
        ['ChooseSkill', '#Skill', 'dll:SkillLock'], None),
    'HideItem': ([('n', 'id')], [], 'Hides an item from your screen, like `hideitem`.', ['HideItem'], None),
    'IgnoreCont': ([('s', 'name'), ('n', 'kind')], [], 'Adds a gump to the ignore list, by name or by kind, like `ignorecont`. '
        'With the number `0`, empties the list; with `-1`, restores the default list.', ['IgnoreCont', 'dll:GetCont'], None),
    'Key': ([('s', 'key'), ('sbbb', 'key ctrl alt shift')], [], 'Presses a key in the client, like `key`.', ['Key'], None),
    'Macro': ([('nn', 'macro parameter'), ('nns', 'macro parameter text')], [], 'Runs one of the client\'s macros, like `event Macro`.',
        ['event Macro'], None),
    'Move': ([('nn', 'x y'), ('nnn', 'x y tolerance'), ('nnnn', 'x y tolerance timeout')],
        [('arrived', 'boolean', 'True when the character got there.')],
        'Walks towards a position without pathfinding, like `move`. Default tolerance: 0. `timeout` is in milliseconds; '
        'without it, there is none.', ['Move', 'dll:Pathfind'], None),
    'Msg': ([('s', 'text')], [], 'Types text into the client, like `msg`. Unlike the command, `$` is not Enter: put a '
        'carriage return (character 13) at the end to send it.', ['Msg', 'dll:Macro'], None),
    'OpenClient': ([('b', 'switch')], [('started', 'boolean', 'True when the client was started.')], 'Starts another client, like `uoxl new`. With `switch` '
        'true, the handle then drives the new client.', ['UOXL', 'dll:CloseClient'], None),
    'PathAvoid': ([('nnnnn', 'x y x2 y2 cost'), ('nnnnnn', 'x y x2 y2 cost facet')], [('state', 'string', '`ok`, or `error: …`.')],
        'Marks the rectangle from `x`, `y` to `x2`, `y2` as a place routes should go round if they can, like '
        '`path avoid`. `cost` is what each step in it costs on top.', ['path avoid', 'dll:GetPath'], None),
    'PathBlock': ([('nn', 'x y'), ('nnn', 'x y facet'), ('nnnn', 'x y x2 y2'), ('nnnnn', 'x y x2 y2 facet')], [('state', 'string', '`ok`, or `error: …`.')],
        'Marks a tile, or the rectangle from `x`, `y` to `x2`, `y2`, as a place routes must never use, like '
        '`path block`.', ['path block', 'dll:PathUnblock', 'dll:GetPath'], None),
    'PathCan': ([('nn', 'x y'), ('nnn', 'x y z')],
        [('state', 'string', '`ok`, `blocked`, `noclient`, `nomap` or `error: …`.'),
         ('z', 'number', 'The height a character would stand at, the floor nearest `z`; 0 when it can\'t.')],
        'Says whether a character can stand at `x`, `y`, like `path can`. Default height: your own.',
        ['path can', 'dll:GetPath'], None),
    'PathCheck': ([('nn', 'x y'), ('nnn', 'x y z'), ('nnnn', 'x y z dir')],
        [('state', 'string', '`ok`, `blocked`, `noclient`, or `nocheck` when EasyUO Reforged doesn\'t know this '
          'client\'s check or the client didn\'t answer.'),
         ('z', 'number', 'The height the step lands at; 0 when it is refused.')],
        'Asks the client itself whether the character can step onto `x`, `y` in direction `dir` from the tile behind it, '
        'at height `z`, like `path check`: the check the client makes before every step, with everything it has '
        'loaded. Default height: your own. A tile the client hasn\'t loaded reads as blocked.',
        ['path check', 'dll:BlockInfo', 'dll:GetPath'], None),
    'PathClear': ([('', ''), ('s', 'what')], [('state', 'string', '`ok`, or `error: …`.')],
        'Forgets rules, like `path clear`.', ['path clear', 'dll:GetPath'], None),
    'PathLink': ([('nnnnnn', 'x y z x2 y2 z2'), ('nnnnnnn', 'x y z x2 y2 z2 cost'),
                  ('nnnnnnnn', 'x y z x2 y2 z2 cost facet')], [('state', 'string', '`ok`, or `error: …`.')],
        'Adds a teleporter, gate or ladder routes may use, from `x`, `y`, `z` to `x2`, `y2`, `z2` on the same facet, '
        'like `path link`. Default cost: 100, one step.', ['path link', 'dll:GetPath'], None),
    'PathSet': ([('ss', 'option value'), ('sn', 'option value')], [('state', 'string', '`ok`, or `error: …`.')],
        'Changes a planning option, like `path set`: `accuracy`, `accuracyz`, `maxnodes`, `timeout`, `margin`, '
        '`turncost`, `heuristic`, `doorcost`, `difs`, `mobiles` or `doors`. `value` is a number, or a word for '
        '`difs`, `mobiles` and `doors`. `timeout` is in milliseconds here. The walking options are refused: uo.dll '
        'doesn\'t walk.', ['path set', 'dll:GetPath'], None),
    'PathUnblock': ([('nn', 'x y'), ('nnn', 'x y facet'), ('nnnn', 'x y x2 y2'), ('nnnnn', 'x y x2 y2 facet')], [('state', 'string', '`ok`, or `error: …`.')],
        'Removes the blocks that overlap a tile or a rectangle, like `path unblock`.',
        ['path unblock', 'dll:PathBlock'], None),
    'Pathfind': ([('nn', 'x y'), ('nnn', 'x y z')], [], 'Walks to a nearby position with the client\'s pathfinding, like '
        '`event PathFind`. Default height: your own.', ['event PathFind', 'dll:Move'], None),
    'Popup': ([('n', 'id'), ('nnn', 'id x y')], [], 'Opens the context menu of an object, like `exevent PopUp`. Unlike the '
        'script command, `x` and `y` are used: they position the menu.', ['exevent PopUp'], None),
    'Property': ([('n', 'id')], [('name', 'string', 'First tooltip line.'), ('properties', 'string', 'The other lines.')],
        'Reads the property tooltip of an object, like `event Property`.', ['event Property', '#Property'], None),
    'RenamePet': ([('ns', 'id name')], [], 'Renames a pet, like `exevent RenamePet`.', ['exevent RenamePet'], None),
    'ScanBuffs': ([('', ''), ('n', 'icon')], [('count', 'number', 'How many buffs.')],
        'Reads the buff bar, like `scanbuffs`; with `icon`, only buffs with that icon ID. Read them with `GetBuff`.',
        ['ScanBuffs', 'dll:GetBuff', 'dll:BuffBarOpen'], None),
    'ScanItems': ([('', ''), ('b', 'visibleonly')], [('count', 'number', 'How many items.')],
        'Makes a fresh list of the items and characters the client knows, like the first step of `finditem`. Default: '
        'visible ones only; with `visibleonly` false, hidden ones too (the `A` filter). Narrow it with `FilterItems`, '
        'read it with `GetItem`.', ['FindItem', 'dll:FilterItems', 'dll:GetItem'], None),
    'ScanJournal': ([('n', 'reference')], [('reference', 'number', 'Pass it to the next call.'), ('new', 'number', 'Lines added since `reference`.')],
        'Reads the journal. Start with `reference` 0, then pass the reference each call returns to the next: `new` is how '
        'many lines arrived in between, and `GetJournal` 0 to `new` − 1 reads them.', ['ScanJournal', '#JIndex', 'dll:GetJournal'], None),
    'SetShop': ([('nn', 'id amount')], [('done', 'boolean', 'False when the item is not in the buy list.')], 'Sets how many of an item to buy, like `setshopitem`.',
        ['SetShopItem', 'dll:GetShop'], None),
    'SkillLock': ([('sn', 'skill lock')], [], 'Sets a skill\'s lock, like `exevent SkillLock`: `lock` 0 up, 1 down, 2 locked; '
        '`skill` a skill code or `all`.', ['exevent SkillLock', 'dll:GetSkill'], None),
    'StatBar': ([('n', 'id')], [], 'Opens a character\'s health bar, like `event StatBar`.', ['event StatBar'], None),
    'StatLock': ([('sn', 'stat lock')], [], 'Sets a stat\'s lock, like `exevent StatLock`: `stat` is `str`, `dex` or `int`; '
        '`lock` 0 up, 1 down, 2 locked.', ['exevent StatLock'], None),
    'SysMessage': ([('s', 'text'), ('sn', 'text colour')], [], 'Shows a system message in the client, like `event SysMessage`. '
        'Default colour: 0.', ['event SysMessage', 'dll:ExMsg'], None),
    'TileCnt': ([('nn', 'x y'), ('nnn', 'x y facet')], [('count', 'number', 'Number of tiles there.')], 'Counts the tiles at a map position, like '
        '`tile cnt`. Call `TileInit` first.', ['Tile', 'dll:TileGet'], None),
    'TileGet': ([('nnn', 'x y layer'), ('nnnn', 'x y layer facet')], [('type', 'number', 'Graphic number.'), ('z', 'number', 'Height.'),
        ('name', 'string', 'Name, such as `tree` or `water`.'), ('flags', 'number', 'The flags as one number, one bit each, in the order `#TileFlags` lists.')],
        'Reads one tile at a map position, like `tile get`; `layer` counts from 1.', ['Tile', '#TileFlags', 'dll:TileCnt'], None),
    'TileInit': ([('', ''), ('b', 'nooverrides')], [('done', 'boolean', 'False when the client folder was not found.')],
        'Loads the map files of the attached client, like `tile init`.', ['Tile', 'dll:TileCnt'], None),
}

# --------------------------------------------------------------------------------------------- generic calls
CALLS = {
    'Get': ('execute', 'Get {name}', 'Reads a property: pushes its value.', ['dll:Set', 'dll:Call']),
    'Set': ('execute', 'Set {name} {value}', 'Changes a read/write property.', ['dll:Get']),
    'Call': ('execute', 'Call {name} [parameters…]', 'Runs a method with the parameters that follow; pushes what it returns.',
             ['dll:Get', 'dll:Type']),
    'Type': ('execute', 'Type {name}', 'Describes a member: pushes its kind (1 read-only property, 2 read/write property, '
             '3 method), then one parameter mask per form (`n` number, `s` string, `b` boolean, `*` anything that follows).',
             ['dll:GetKeywords']),
    'Help': ('execute', 'Help {name}', 'Does nothing and returns 0. Kept for compatibility.', []),
    'GetCommands': ('query', 'GetCommands', 'Pushes the names of the `Execute` commands: Call, Get, Help, Set, Type.', ['dll:GetKeywords']),
    'GetKeywords': ('query', 'GetKeywords', 'Pushes the name of every property and method, once each.', ['dll:Type']),
    'GetError': ('query', 'GetError {code}', 'Pushes the name of an error code: `RES_OK`, `ERR_NOTFOUND`, `ERR_WRONGPAR`, '
                 '`ERR_GENERIC`, or `ERR_UNKNOWNERR`.', []),
    'GetFeatures': ('query', 'GetFeatures', 'Pushes `CEIKD`, the feature letters of this API version.', []),
    'GetInit': ('query', 'GetInit', 'Pushes a short Lua script that makes the API available as `UO.Name` in Lua, the way '
                'OpenEUO used it.', []),
    'SetDelay': ('query', 'SetDelay {function} {info}', 'Registers a function the DLL calls whenever a method has to wait '
                 '(two pointers: the function, and a value passed back to it). The function receives the milliseconds to '
                 'wait and the info pointer, and returns false to cancel. Without it, the DLL simply sleeps.', []),
}


def parse():
    src = WRAP.read_text(encoding='utf-8', errors='replace')
    tbl = re.search(r'UOTbl\s*:\s*array\[[^\]]*\]\s*of\s*TItem\s*=\s*\((.*?)\);', src, re.S).group(1)
    rows = re.findall(r"N:\s*'([^']+)'\s*;T:\s*(\w+)\s*;C:\s*(\d+)\s*;P:\s*'([^']*)'", tbl)
    mget = src[src.index('function TUOWrap.MGet'):src.index('function TUOWrap.MSet')]
    pushes = {int(c): t for c, t in re.findall(r'^\s*(\d{3}):\s*Push(\w+)\(', mget, re.M)}
    cmds = re.search(r'Commands\s*:\s*array\[[^\]]*\]\s*of\s*TItem\s*=\s*\((.*?)\);', src, re.S).group(1)
    calls = re.findall(r"N:\s*'([^']+)'\s*;T:\s*(\w+)", cmds)
    return rows, pushes, calls


def frontmatter(path):
    if not path.exists():
        return {}
    m = re.match(r'^---\r?\n(.*?)\r?\n---', path.read_text(encoding='utf-8'), re.S)
    out = {}
    for line in m.group(1).splitlines():
        kv = re.match(r'^([A-Za-z]+):\s*(.*)$', line)
        if kv:
            out[kv.group(1)] = kv.group(2).strip().strip('"')
    return out


def write(slug, title, description, kind, category, syntax, body, related=(), aliases=(), needs=True):
    fm = ['---', f'title: {json.dumps(title)}', f'description: {json.dumps(description, ensure_ascii=False)}',
          f'kind: {kind}', f'category: {category}', f'syntax: {json.dumps(syntax)}', 'needsClient: true' if needs else None]
    fm = [l for l in fm if l]
    for key, values in (('related', related), ('aliases', aliases)):
        if values:
            fm.append(f'{key}: [' + ', '.join(json.dumps(v) for v in values) + ']')
    fm += ['---']
    (OUT / f'{slug.lower()}.md').write_text('\n'.join(fm) + '\n\n' + body.strip() + '\n', encoding='utf-8', newline='\n')


def link_variable(name):
    """Adds `dll: Name` to the #variable page of the same name; returns that page's frontmatter."""
    path = DOCS / 'variables' / f'{name.lower()}.md'
    fm = frontmatter(path)
    if fm and 'dll' not in fm:
        text = path.read_text(encoding='utf-8')
        end = re.match(r'^---\r?\n.*?\r?\n(?=---)', text, re.S).end()     # just before the closing ---
        path.write_text(text[:end] + f'dll: {name}\n' + text[end:], encoding='utf-8', newline='\n')
    return fm


def main():
    rows, pushes, calls = parse()
    OUT.mkdir(exist_ok=True)
    by_name = {}
    for n, t, c, p in rows:
        by_name.setdefault(n, []).append((t, int(c), p))

    problems = []
    written = 0
    for name, entries in sorted(by_name.items(), key=lambda kv: kv[0].lower()):
        kinds = {t for t, _, _ in entries}
        if kinds <= {'RO', 'RW'}:
            access, code = entries[0][0], entries[0][1]
            vtype = {'Integer': 'number', 'StrVal': 'string', 'Boolean': 'boolean'}.get(pushes.get(code), 'value')
            var = link_variable(name)
            vdesc = var.get('description', '')
            is_id = var.get('type') == 'id'
            syntax = f'Get {name}  →  {vtype}' + (f'\nSet {name} {{{vtype}}}' if access == 'RW' else '')
            lines = [f'`{name}` is {"a read/write" if access == "RW" else "a read-only"} property: '
                     f'the same value as [`#{var.get("title", "#" + name).lstrip("#")}`](/variables/{name.lower()}/)'
                     if var else f'`{name}` is {"a read/write" if access == "RW" else "a read-only"} property.']
            lines[0] += f', returned as a {vtype}.' if var else ''
            if vdesc:
                lines.append('')
                lines.append(vdesc)
            if is_id:
                lines += ['', 'IDs come back as plain numbers, not as the letter codes the `#` variable shows.']
            if name == 'CliNr':
                lines += ['', '**`Set CliNr` attaches the handle to client number n** (1 to `CliCnt`). A program does this '
                          'first, before reading anything else.']
            if name == 'BuffBarOpen':
                lines += ['', 'It is also false on a client whose buff bar cannot be read, where `#BuffBarOpen` reads `N/A`.']
            write(name, name, vdesc or f'The {name} property.', 'dll-property', 'property', syntax, '\n'.join(lines),
                  related=[f'#{name}'] if var else [], aliases=[f'UO.{name}'],
                  needs=var.get('needsClient') == 'true' if var else True)
        else:
            if name not in METHODS:
                problems.append(f'method {name} has no description in METHODS')
                continue
            sigs, returns, desc, related, notes = METHODS[name]
            masks = sorted(p for _, _, p in entries)
            mine = sorted(m for m, _ in sigs)
            if masks != mine:
                problems.append(f'{name}: UOTbl masks {masks} != documented {mine}')
                continue
            for m, params in sigs:
                if m != '*' and len(m) != len(params.split()):
                    problems.append(f'{name}: mask {m} has {len(m)} parameters, names "{params}"')
            syntax = '\n'.join(f'Call {name} {params}'.rstrip() for _, params in sorted(sigs, key=lambda s: len(s[0])))
            body = [desc, '']
            names = []
            for m, params in sigs:
                if m == '*':
                    names.append(('id…', 'numbers'))
                    continue
                for letter, pname in zip(m, params.split()):
                    if pname not in [n for n, _ in names]:
                        names.append((pname, TYPES[letter]))
            if names:
                body += ['## Parameters', '', '| Parameter | Type | Meaning |', '|---|---|---|']
                for pname, ptype in names:
                    body.append(f'| `{pname}` | {ptype} | {PARAMS.get(pname, "")} |')
                body.append('')
            body += ['## Returns', '']
            if returns:
                body += ['In this order, from stack position 1:', '', '| Value | Type | Meaning |', '|---|---|---|']
                body += [f'| `{r}` | {t} | {m} |' for r, t, m in returns]
            else:
                body.append('Nothing.')
            if notes:
                body += ['', f':::note\n{notes}\n:::']
            first = desc.split('. ')[0].rstrip('.') + '.'
            write(name, name, first, 'dll-method', 'method', syntax, '\n'.join(body), related=related, aliases=[f'UO.{name}'])
        written += 1

    for name, kind in calls:
        if name not in CALLS:
            problems.append(f'generic call {name} has no description in CALLS')
            continue
        where, syntax, desc, related = CALLS[name]
        how = ('An `Execute` command: push it, then the name and any values, then call `Execute`.' if where == 'execute'
               else 'A `Query` command: push it and any values, then call `Query`.')
        write(name, name, desc.split('. ')[0].rstrip('.') + '.', 'dll-call', 'call', syntax, f'{desc}\n\n{how}', related=related,
              needs=False)
        written += 1

    for name in METHODS:
        if name not in by_name:
            problems.append(f'METHODS documents {name}, which UOTbl does not have')
    if problems:
        print('\n'.join(problems))
        sys.exit(1)
    print(f'{written} pages written to {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
