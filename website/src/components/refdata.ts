// Lookups shared by the Ref* components: the reference entries, name -> link resolution and the
// cross-field frontmatter rules the schema cannot express.

import { getCollection, type CollectionEntry } from 'astro:content';
import { categoriesFor, refSlug, slugHref } from '../reference.mjs';

export type DocsEntry = CollectionEntry<'docs'>;

export async function referenceEntries(): Promise<DocsEntry[]> {
	return getCollection('docs', (e) => !!e.data.kind);
}

export interface RefLink {
	label: string;
	href?: string; // absent when the target page does not exist yet
}

// Display form of a frontmatter reference name: 'dll:ScanItems' -> 'ScanItems'.
function labelOf(name: string): string {
	return name.startsWith('dll:') ? name.slice(4) : name;
}

// Turns a frontmatter name into a link. A name whose page is not written yet renders as plain text
// instead of a broken link; CheckDocsCoverage.ps1 is what reports missing pages.
export function resolveRef(name: string, entries: DocsEntry[]): RefLink {
	const slug = refSlug(name);
	const target = entries.find((e) => e.id === slug);
	return { label: target ? target.data.title : labelOf(name), href: target ? slugHref(slug) : undefined };
}

// Commands whose `sets:` lists this variable, for its "Set by" row.
export function setBy(entry: DocsEntry, entries: DocsEntry[]): RefLink[] {
	const own = entry.data.title.toLowerCase();
	return entries
		.filter((e) => e.data.sets.some((s) => s.toLowerCase() === own))
		.map((e) => ({ label: e.data.title, href: slugHref(e.id) }));
}

// Fails the build with the page id when a reference page breaks a rule the schema cannot check.
export function validateRef(entry: DocsEntry): void {
	const d = entry.data;
	if (!d.kind) return;
	const problems: string[] = [];
	if (!d.category) problems.push('`category` is required');
	else if (!categoriesFor(d.kind).some(([k]: [string, string]) => k === d.category))
		problems.push(`category '${d.category}' does not belong to kind '${d.kind}'`);
	if (d.kind === 'variable') {
		if (!d.access) problems.push('variables need `access: ro|rw`');
		if (!d.type) problems.push('variables need `type`');
		if (!d.title.startsWith('#')) problems.push("variable titles start with '#'");
	}
	if ((d.kind === 'command' || d.kind === 'subcommand') && !d.syntax) problems.push('commands need `syntax`');
	if (!d.description) problems.push('`description` (the one-line summary) is required');
	if (problems.length) throw new Error(`Reference page '${entry.id}': ${problems.join('; ')}`);
}
