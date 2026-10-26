// Shared vocabulary for the reference pages: used by astro.config.mjs (sidebar),
// src/content.config.ts (frontmatter schema) and the Ref* components, so the
// category lists and the name -> page mapping exist in exactly one place.

export const SITE = 'https://ilpersi.github.io';
export const BASE = '/EasyUOReforged';
export const REPO = 'https://github.com/ilpersi/EasyUOReforged';

// [key, label] in sidebar order. Keys are what pages put in `category:`.
export const COMMAND_CATEGORIES = [
	['flow', 'Flow control'],
	['client', 'Client'],
	['event', 'Event'],
	['exevent', 'ExEvent'],
	['menu', 'Menu'],
	['namespace', 'Namespace'],
	['data', 'Data (SQL)'],
	['path', 'Pathfinding'],
	['misc', 'Miscellaneous'],
	['obsolete', 'Obsolete'],
];

export const VARIABLE_CATEGORIES = [
	['character', 'Character'],
	['status', 'Status'],
	['container', 'Container'],
	['lastaction', 'Last action'],
	['finditem', 'FindItem'],
	['buffs', 'Buffs'],
	['shop', 'Shop'],
	['extended', 'Extended'],
	['client', 'Client'],
	['combat', 'Combat'],
	['namespace', 'Namespace'],
	['sql', 'SQL'],
	['path', 'Pathfinding'],
	['misc', 'Miscellaneous'],
	['result', 'Result'],
	['tile', 'Tile'],
	['constant', 'Constants'],
];

export const DLL_CATEGORIES = [
	['property', 'Properties'],
	['method', 'Methods'],
	['call', 'Generic calls'],
];

export const ALL_CATEGORY_KEYS = [
	...new Set([...COMMAND_CATEGORIES, ...VARIABLE_CATEGORIES, ...DLL_CATEGORIES].map(([key]) => key)),
];

export const KINDS = ['command', 'subcommand', 'variable', 'dll-property', 'dll-method', 'dll-call'];

export function categoriesFor(kind) {
	if (kind === 'variable') return VARIABLE_CATEGORIES;
	if (kind?.startsWith('dll-')) return DLL_CATEGORIES;
	return COMMAND_CATEGORIES;
}

export function categoryLabel(kind, key) {
	return categoriesFor(kind).find(([k]) => k === key)?.[1] ?? key;
}

// Maps a reference name, as written in frontmatter (`sets:`, `related:`), to a page slug:
//   '#FindID'      -> 'variables/findid'
//   'FindItem'     -> 'commands/finditem'
//   'event macro'  -> 'commands/event/macro'
//   'dll:ScanItems'-> 'dll/scanitems'
export function refSlug(name) {
	const n = name.trim().toLowerCase();
	if (n.startsWith('#')) return `variables/${n.slice(1)}`;
	if (n.startsWith('dll:')) return `dll/${n.slice(4)}`;
	return `commands/${n.split(/\s+/).join('/')}`;
}

// Root-relative href for a slug, with the deploy base in front.
export function slugHref(slug) {
	return `${BASE}/${slug}/`;
}
