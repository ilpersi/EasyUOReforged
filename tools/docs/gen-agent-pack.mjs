#!/usr/bin/env node
// Writes the agent pack: what a coding agent (Claude Code, Codex, Cursor, ...) reads to write and
// change EasyUO scripts. See docs/agent-support.md, phase 1.
//
// The pack is the hand-written files of agent/ (copied as they are) plus, generated here from the
// documentation site's pages (website/src/content/docs) and their frontmatter:
//
//   euo-script/language.md      the rules of the language, patterns and probes: three pages of the
//                               site (RULES below) in one file, which an agent reads in full
//   euo-script/commands.md      every command and sub-command on one line: syntax, summary, flags
//   euo-script/variables.md     every #variable, by category
//   euo-script/reference.json   the same data for tools
//   euo-script/reference/**     one clean markdown file per page (commands, variables, language, guides)
//
// Pages derived from the EasyUO wiki (source: wiki) are under the GFDL 1.2: each keeps the notice
// the site shows, and the licence text is copied into the pack.
//
// and, for the site, llms.txt (an index of those files) and llms-full.txt (all of them in one).
//
// Nothing generated is committed. The release workflow writes the pack into the zip, and the
// site's build (astro.config.mjs) writes it under /agent/ with the two llms files at the root.
//
// Usage:
//   node tools/docs/gen-agent-pack.mjs --out <dir> [--version v26.11.09]   the pack, as <dir>/...
//   node tools/docs/gen-agent-pack.mjs --site <dist dir> [--version ...]   <dist>/agent/..., llms*.txt
//   node tools/docs/gen-agent-pack.mjs --check                             build it, write nothing
//
// It needs Node only (no npm install), so the release workflow can run it without the site's
// dependencies. It stops with an error on a page it cannot read, so a page is never left out
// silently.

import { execFileSync } from 'node:child_process';
import { mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, posix, relative, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {
	SITE,
	BASE,
	COMMAND_CATEGORIES,
	VARIABLE_CATEGORIES,
	refSlug,
} from '../../website/src/reference.mjs';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const DOCS = join(ROOT, 'website', 'src', 'content', 'docs');
const AGENT = join(ROOT, 'agent');
const SITE_URL = `${SITE}${BASE}`;
const SKILL = 'euo-script'; // the skill folder inside the pack
const PACK_URL = `${SITE_URL}/agent`;
const GFDL = 'LICENSE-GFDL-1.2.txt'; // copied into the skill folder from website/

// Sections of the site that go into the pack, in reading order. The uo.dll pages, the MENU
// Designer's and the developers' are left out: they are not about writing scripts.
const SECTIONS = [
	['language', 'Language'],
	['commands', 'Commands'],
	['variables', 'Variables'],
	['guides', 'Guides'],
	['guide', 'Using EasyUO Reforged'],
	['reforged', 'What Reforged adds and changes'],
];
// Pages left out of the pack: this one describes the pack itself.
const SKIP = new Set(['guide/agents']);
// The pages that make up euo-script/language.md, in this order: what an agent reads in full before
// it writes a script. They are ordinary pages of the site, written for people too, so the rules
// exist once. In the pack they are in language.md only, not under reference/.
const RULES = ['language/common-mistakes', 'guides/patterns', 'guides/finding-ids'];

// ------------------------------------------------------------------------------------ frontmatter
// The subset of YAML the reference pages use: `key: value` lines with plain, single- or
// double-quoted scalars and one-line [a, 'b', "c"] lists, plus the indented `sidebar:` block.
function parseScalar(raw, where) {
	const s = raw.trim();
	if (s === '') return '';
	if (s.startsWith('"')) {
		try {
			return JSON.parse(s);
		} catch {
			throw new Error(`${where}: cannot read the double-quoted value ${s}`);
		}
	}
	if (s.startsWith("'")) {
		if (!s.endsWith("'") || s.length < 2) throw new Error(`${where}: unclosed quote in ${s}`);
		return s.slice(1, -1).replace(/''/g, "'");
	}
	if (s === 'true') return true;
	if (s === 'false') return false;
	return s;
}

function parseList(raw, where) {
	const items = [];
	let i = 1; // after '['
	const end = raw.lastIndexOf(']');
	while (i < end) {
		while (i < end && /[\s,]/.test(raw[i])) i++;
		if (i >= end) break;
		let j = i;
		if (raw[i] === '"' || raw[i] === "'") {
			const q = raw[i];
			j = i + 1;
			while (j < end && (raw[j] !== q || (q === "'" && raw[j + 1] === "'") || (q === '"' && raw[j - 1] === '\\'))) {
				if (q === "'" && raw[j] === "'" && raw[j + 1] === "'") j++;
				j++;
			}
			if (j >= end) throw new Error(`${where}: unclosed quote in the list ${raw}`);
			j++;
		} else {
			while (j < end && raw[j] !== ',') j++;
		}
		items.push(parseScalar(raw.slice(i, j), where));
		i = j;
	}
	return items;
}

function parsePage(file) {
	const text = readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
	const m = text.match(/^---\n([\s\S]*?)\n---\n?/);
	if (!m) throw new Error(`${file}: no frontmatter`);
	const data = {};
	let block = null;
	for (const line of m[1].split('\n')) {
		if (!line.trim()) continue;
		const kv = line.match(/^(\s*)([A-Za-z]+):\s*(.*)$/);
		if (!kv) throw new Error(`${file}: cannot read the frontmatter line "${line}"`);
		const [, indent, key, raw] = kv;
		const where = `${file} (${key})`;
		if (indent) {
			if (!block) throw new Error(`${file}: indented frontmatter line "${line}" outside a block`);
			data[block][key] = parseScalar(raw, where);
			continue;
		}
		block = null;
		const value = raw.trim();
		if (value === '') {
			data[key] = {};
			block = key;
		} else if (value.startsWith('[')) {
			if (!value.endsWith(']')) throw new Error(`${where}: a list has to be on one line`);
			data[key] = parseList(value, where);
		} else data[key] = parseScalar(value, where);
	}
	return { data, body: text.slice(m[0].length) };
}

// -------------------------------------------------------------------------------------- the pages
function walk(dir) {
	let files = [];
	for (const name of readdirSync(dir).sort()) {
		const full = join(dir, name);
		if (statSync(full).isDirectory()) files = files.concat(walk(full));
		else files.push(full);
	}
	return files;
}

function slugOf(file) {
	return relative(DOCS, file)
		.split(sep)
		.join('/')
		.replace(/\.md$/, '')
		.replace(/\/index$/, '')
		.toLowerCase();
}

function loadPages() {
	const pages = [];
	for (const [section] of SECTIONS) {
		for (const file of walk(join(DOCS, section))) {
			if (!file.endsWith('.md')) continue; // .mdx pages are the generated A-Z lists
			const slug = slugOf(file);
			if (SKIP.has(slug)) continue;
			const { data, body } = parsePage(file);
			if (!data.title || !data.description) throw new Error(`${file}: title and description are required`);
			const page = { slug, section, file: `reference/${slug}.md`, data, body };
			if (RULES.includes(slug)) {
				page.file = 'language.md';
				page.anchor = anchorOf(data.title);
			}
			pages.push(page);
		}
	}
	for (const slug of RULES) {
		if (!pages.some((p) => p.slug === slug)) throw new Error(`the rules page ${slug} (RULES) does not exist`);
	}
	return pages;
}

// The anchor a markdown viewer gives a heading: 'Common mistakes' -> 'common-mistakes'.
function anchorOf(title) {
	return title
		.toLowerCase()
		.replace(/[^a-z0-9 -]/g, '')
		.trim()
		.replace(/\s+/g, '-');
}

const isRule = (p) => p.file === 'language.md';

const list = (v) => (Array.isArray(v) ? v : []);
const isCommand = (p) => p.data.kind === 'command' || p.data.kind === 'subcommand';
const isVariable = (p) => p.data.kind === 'variable';
// The name a script writes: 'finditem', 'event macro', 'menu font align', '#FindID'.
const nameOf = (p) => (isVariable(p) ? p.data.title : p.slug.split('/').slice(1).join(' '));

// ------------------------------------------------------------------------------- markdown rewriting
// Root-relative links ("/commands/if/#x") become, inside the pack, relative paths to the file of
// that page; a link to a page the pack does not hold, and every link in llms-full.txt, becomes the
// page's address on the site.
function rewriteLinks(md, bySlug, fromFile) {
	return md.replace(/\]\((\/[^)\s]*)\)/g, (whole, target) => {
		const [, path, rest] = target.match(/^([^?#]*)(.*)$/);
		const slug = path.replace(/^\/|\/$/g, '').toLowerCase();
		const page = bySlug.get(slug);
		if (fromFile && page && !rest.startsWith('?')) {
			const rel = posix.relative(posix.dirname(fromFile), page.file);
			// A rules page is a section of language.md: without an anchor of its own, link to its heading.
			return `](${rel}${rest || (page.anchor ? `#${page.anchor}` : '')})`;
		}
		return `](${SITE_URL}${target})`;
	});
}

// Starlight asides (:::note ... :::) become block quotes.
function rewriteAsides(md) {
	const out = [];
	let inFence = false;
	let inAside = false;
	for (const line of md.split('\n')) {
		if (/^\s*```/.test(line)) inFence = !inFence;
		const open = !inFence && line.match(/^:::(\w+)(?:\[(.*)\])?\s*$/);
		if (open) {
			const kind = open[1][0].toUpperCase() + open[1].slice(1);
			out.push(open[2] ? `> **${kind}: ${open[2]}**` : `> **${kind}**`, '>');
			inAside = true;
		} else if (!inFence && inAside && /^:::\s*$/.test(line)) inAside = false;
		else out.push(inAside ? `> ${line}`.trimEnd() : line);
	}
	return out.join('\n');
}

function syntaxLines(p) {
	return String(p.data.syntax ?? '')
		.split('\n')
		.filter((s) => s.trim());
}

function flagsOf(p) {
	const d = p.data;
	const flags = [];
	if (isVariable(p) && d.access === 'rw') flags.push('rw');
	if (d.needsClient === true) flags.push('client');
	if (d.origin === 'reforged') flags.push('new');
	if (d.changed === true) flags.push('changed');
	if (d.obsolete === true || d.category === 'obsolete') flags.push('obsolete');
	if (d.category === 'menu' && list(d.menuLogic).length === 1) flags.push(`menu ${d.menuLogic[0]} only`);
	return flags;
}

// The header that replaces a reference page's frontmatter.
function headerOf(p, pages) {
	const d = p.data;
	const lines = [`# ${d.title}`, '', `> ${d.description}`, ''];
	if (isCommand(p)) {
		const syn = syntaxLines(p);
		if (syn.length === 1) lines.push(`- **Syntax:** \`${syn[0]}\``);
		else if (syn.length > 1) lines.push('- **Syntax:**', '', '  ```', ...syn.map((s) => `  ${s}`), '  ```');
	}
	if (isVariable(p)) {
		lines.push(`- **Access:** ${d.access === 'rw' ? 'read / write' : 'read-only'}`);
		lines.push(`- **Type:** ${d.type}`);
	}
	if (d.kind) lines.push(`- **Needs a client:** ${d.needsClient === true ? 'yes' : 'no'}`);
	if (d.origin === 'reforged') lines.push('- **New in Reforged:** EasyUO 1.5 does not have it.');
	if (d.changed === true) lines.push('- **Changed in Reforged:** see "Reforged notes" below.');
	if (d.obsolete === true || d.category === 'obsolete') lines.push('- **Obsolete.**');
	if (list(d.menuLogic).length) lines.push(`- **MENU logic:** ${d.menuLogic.join(', ')}`);
	if (list(d.sets).length) lines.push(`- **Sets:** ${d.sets.join(', ')}`);
	if (isVariable(p)) {
		const own = d.title.toLowerCase();
		const by = pages.filter((q) => list(q.data.sets).some((s) => s.toLowerCase() === own)).map((q) => q.data.title);
		if (by.length) lines.push(`- **Set by:** ${by.join(', ')}`);
	}
	const related = list(d.related).filter((r) => !r.startsWith('dll:'));
	if (related.length) lines.push(`- **Related:** ${related.join(', ')}`);
	lines.push(`- **Online:** ${SITE_URL}/${p.slug}/`, '');
	return lines.join('\n');
}

// The notices the site shows at the foot of a page (website/src/components/MarkdownContent.astro):
// text derived from the EasyUO wiki is under the GFDL 1.2, and travels with that notice.
const WIKI_NOTICE =
	'*Based on the [EasyUO wiki](https://github.com/ilpersi/easyuo-wiki-archive), edited for EasyUO Reforged. ' +
	'This text is available under the [GNU Free Documentation License 1.2]' +
	`(https://www.gnu.org/licenses/old-licenses/fdl-1.2.html) (\`${GFDL}\` in this pack).*`;
const SCRIPTUO_NOTICE =
	'*The EasyUO 1.6 behaviour on this page was researched with help from the [ScriptUO](https://www.scriptuo.com/) ' +
	"community: Gaderian's tutorial [New Menu Code and how to adapt old scripts]" +
	'(https://www.scriptuo.com/index.php?topic=15596.0) and the scripts its members share at scriptuo.com.*';
const LIST_NOTICE = [
	'## Licence',
	'',
	'The summaries come from the reference pages. Those of pages based on the EasyUO wiki are available',
	`under the GNU Free Documentation License 1.2 (\`${GFDL}\`), like the pages; the rest is under the`,
	'BSD 2-Clause licence of EasyUO Reforged.',
	'',
];

function renderPage(p, pages, bySlug, fromFile) {
	const body = rewriteAsides(rewriteLinks(p.body, bySlug, fromFile)).trim();
	const notices = [];
	if (p.data.source === 'wiki') notices.push(WIKI_NOTICE);
	if (list(p.data.credits).includes('scriptuo')) notices.push(SCRIPTUO_NOTICE);
	return `${headerOf(p, pages)}\n${body}\n${notices.map((n) => `\n${n}\n`).join('')}`;
}

// ---------------------------------------------------------------------------------- the two lists
// Rows such as "| `str len {text}` | The number of characters. |" on a command's page: the forms
// of a command whose operations have no page of their own. A row without a {parameter} is an
// example, not a form. Links in the description are reduced to their text.
function formsOf(p) {
	const name = nameOf(p);
	const forms = [];
	for (const line of p.body.split('\n')) {
		const m = line.match(/^\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|\s*$/);
		if (m && m[1].includes('{') && m[1].toLowerCase().startsWith(`${name} `))
			forms.push([m[1], m[2].replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')]);
	}
	return forms;
}

const tag = (flags) => (flags.length ? ` [${flags.join('] [')}]` : '');

function commandsMd(pages, version) {
	const cmds = pages.filter(isCommand);
	const out = [
		'# Commands',
		'',
		`Every script command of EasyUO Reforged ${version}, generated from its documentation. One line each:`,
		'the syntax, what it does, and flags.',
		'',
		'- `{x}` is a parameter you fill in, `[x]` is optional, `a|b` is a choice.',
		'- `[client]` works only with a UO client attached; without one the line does nothing.',
		'- `[new]` was added by EasyUO Reforged: the original EasyUO 1.5 ignores the line.',
		'- `[changed]` behaves differently from EasyUO 1.5: read its "Reforged notes".',
		'- `[menu 1.5 only]` / `[menu 1.6 only]` exists in only one of the two MENU logics (see `reference/commands/menu/versions.md`).',
		'',
		'The details of a command are in `reference/commands/<name>.md`, with spaces in the name as folders:',
		'`finditem` is `reference/commands/finditem.md`, `event macro` is `reference/commands/event/macro.md`.',
		'Read that file before you use a command for the first time. A word that is not in this list is not a',
		'command: the interpreter ignores the line without an error.',
		'',
	];
	for (const [key, label] of COMMAND_CATEGORIES) {
		const inCat = cmds
			.filter((p) => p.data.category === key)
			.sort((a, b) => a.slug.split('/').length - b.slug.split('/').length || a.slug.localeCompare(b.slug));
		if (!inCat.length) continue;
		out.push(`## ${label}`, '');
		for (const p of inCat) {
			const syn = syntaxLines(p).map((s) => `\`${s}\``).join(' / ');
			const where = refSlug(p.data.title) === p.slug ? '' : ` (\`${p.file}\`)`;
			out.push(`- ${syn}: ${p.data.description}${tag(flagsOf(p))}${where}`);
			for (const [form, what] of formsOf(p)) out.push(`  - \`${form}\`: ${what}`);
		}
		out.push('');
	}
	return out.concat(LIST_NOTICE).join('\n');
}

function variablesMd(pages, version) {
	const vars = pages.filter(isVariable);
	const out = [
		'# Variables',
		'',
		`Every system variable (\`#name\`) of EasyUO Reforged ${version}, generated from its documentation.`,
		'',
		'- The word in parentheses is the kind of value: `number`, `string`, `boolean` (`-1` or `0`) or `id`',
		'  (an object ID or type, written in letters, such as `YKLMNOP` or `POF`).',
		'- `[rw]` can be set with `set`; every other variable is read-only.',
		'- `[client]` needs a UO client attached; without one it reads `N/A`.',
		'- `[new]` was added by EasyUO Reforged: the original EasyUO 1.5 does not have it.',
		'',
		'The details of `#Name` are in `reference/variables/name.md` (lower case, without the `#`). A `#name`',
		'that is not in this list does not exist. The `%`, `!` and `*` variables are the script\'s own: see',
		'`language.md`.',
		'',
	];
	for (const [key, label] of VARIABLE_CATEGORIES) {
		const inCat = vars.filter((p) => p.data.category === key).sort((a, b) => a.slug.localeCompare(b.slug));
		if (!inCat.length) continue;
		out.push(`## ${label}`, '');
		for (const p of inCat) out.push(`- \`${p.data.title}\` (${p.data.type}): ${p.data.description}${tag(flagsOf(p))}`);
		out.push('');
	}
	return out.concat(LIST_NOTICE).join('\n');
}

function referenceJson(pages, version) {
	const common = (p) => ({
		name: nameOf(p),
		title: p.data.title,
		kind: p.data.kind,
		category: p.data.category,
		description: p.data.description,
		needsClient: p.data.needsClient === true,
		origin: p.data.origin ?? 'original',
		changed: p.data.changed === true,
		obsolete: p.data.obsolete === true || p.data.category === 'obsolete',
		related: list(p.data.related),
		aliases: list(p.data.aliases),
		file: p.file,
		url: `${SITE_URL}/${p.slug}/`,
	});
	return {
		generator: 'tools/docs/gen-agent-pack.mjs',
		version,
		site: `${SITE_URL}/`,
		commands: pages.filter(isCommand).map((p) => ({
			...common(p),
			syntax: syntaxLines(p),
			forms: formsOf(p).map(([syntax, description]) => ({ syntax, description })),
			sets: list(p.data.sets),
			menuLogic: list(p.data.menuLogic),
		})),
		variables: pages.filter(isVariable).map((p) => ({
			...common(p),
			access: p.data.access,
			type: p.data.type,
		})),
		pages: pages.filter((p) => !p.data.kind).map((p) => ({
			title: p.data.title,
			description: p.data.description,
			file: p.file,
			url: `${SITE_URL}/${p.slug}/`,
		})),
	};
}

// ------------------------------------------------------------------------------------ language.md
// The rules pages (RULES) one after the other, each under its title, with its headings one level
// down. fromFile is 'language.md' for the pack, or null for llms-full.txt (links to the site).
function languageMd(pages, bySlug, version, fromFile) {
	const out = [
		'# EasyUO language rules',
		'',
		'What you need to know before writing or changing an EasyUO script (`.euo`): the rules scripts break',
		'most often, the patterns that work, and how to get the values only the game knows. EasyUO is a small',
		'language of its own. It looks like BASIC but its rules are different, and **it reports no errors**: a',
		'line it can\'t understand is skipped, and the script goes on. Follow these rules exactly.',
		'',
		`Generated from the documentation of EasyUO Reforged ${version}. Command names are in`,
		'[commands.md](commands.md), `#variables` in [variables.md](variables.md), and the details of each in',
		'`reference/`.',
		'',
	];
	for (const slug of RULES) {
		const p = bySlug.get(slug);
		const body = rewriteAsides(rewriteLinks(p.body, bySlug, fromFile)).trim();
		let inFence = false;
		const lower = body.split('\n').map((line) => {
			if (/^\s*```/.test(line)) inFence = !inFence;
			return !inFence && /^#{1,5} /.test(line) ? `#${line}` : line;
		});
		out.push(`## ${p.data.title}`, '', ...lower, '');
	}
	return out.join('\n');
}

// --------------------------------------------------------------------------------- the hand-written
function handWritten() {
	const files = new Map();
	for (const full of walk(AGENT)) {
		const rel = relative(AGENT, full).split(sep).join('/');
		files.set(rel, readFileSync(full, 'utf8').replace(/\r\n/g, '\n'));
	}
	for (const need of ['README.md', 'AGENTS.md', `${SKILL}/SKILL.md`]) {
		if (!files.has(need)) throw new Error(`agent/${need} is missing`);
	}
	for (const made of ['language.md', 'commands.md', 'variables.md', 'reference.json']) {
		if (files.has(`${SKILL}/${made}`))
			throw new Error(`agent/${SKILL}/${made} is generated: remove the file (language.md comes from the pages in RULES)`);
	}
	return files;
}

// Every euo example of a hand-written file is a whole script, as on the site: it ends with halt or
// stop (subs may follow), or with a goto back into an endless main loop.
function checkExamples(files) {
	const problems = [];
	const headers = ['if', 'else', 'while', 'for', 'onhotkey', 'cmppix'];
	for (const [name, text] of files) {
		let n = 0;
		for (const m of text.matchAll(/```euo[^\n]*\n([\s\S]*?)```/g)) {
			n++;
			const words = m[1]
				.split('\n')
				.map((l) => l.split(';')[0].trim())
				.filter(Boolean)
				.map((l) => l.split(/\s+/)[0].toLowerCase());
			const ends = (i) => i >= 0 && ['halt', 'stop', 'goto'].includes(words[i]) && !headers.includes(words[i - 1]);
			let ok = ends(words.length - 1);
			for (let i = 1; !ok && i < words.length; i++) if (words[i] === 'sub') ok = ends(i - 1);
			if (!ok) problems.push(`agent/${name}, euo example ${n}: does not end with halt or stop`);
		}
	}
	if (problems.length) throw new Error(problems.join('\n'));
}

// ------------------------------------------------------------------------------------- the pack
function gitVersion() {
	try {
		return execFileSync('git', ['describe', '--tags', '--always'], { cwd: ROOT, encoding: 'utf8' }).trim();
	} catch {
		return 'unknown';
	}
}

export function buildPack(version = gitVersion()) {
	const pages = loadPages();
	const bySlug = new Map(pages.map((p) => [p.slug, p]));
	// The site's A-Z lists are the pack's two lists.
	bySlug.set('commands', { file: 'commands.md' });
	bySlug.set('variables', { file: 'variables.md' });
	const hand = handWritten();
	checkExamples(hand);

	const files = new Map(hand);
	files.set(`${SKILL}/language.md`, languageMd(pages, bySlug, version, 'language.md'));
	files.set(`${SKILL}/commands.md`, commandsMd(pages, version));
	files.set(`${SKILL}/variables.md`, variablesMd(pages, version));
	files.set(`${SKILL}/reference.json`, `${JSON.stringify(referenceJson(pages, version), null, 1)}\n`);
	for (const p of pages) if (!isRule(p)) files.set(`${SKILL}/${p.file}`, renderPage(p, pages, bySlug, p.file));
	files.set(`${SKILL}/VERSION`, `${version}\n`);
	files.set(`${SKILL}/${GFDL}`, readFileSync(join(ROOT, 'website', GFDL), 'utf8'));

	// Every reference page is on both lists, so nothing can be in the pack and not be findable.
	const cmdList = files.get(`${SKILL}/commands.md`);
	const varList = files.get(`${SKILL}/variables.md`);
	for (const p of pages) {
		if (isVariable(p) && !varList.includes(`\`${p.data.title}\``)) throw new Error(`${p.slug} is missing from variables.md`);
		if (isCommand(p) && !syntaxLines(p).length) throw new Error(`${p.slug}: a command needs a syntax`);
		if (isCommand(p) && !cmdList.includes(p.data.description)) throw new Error(`${p.slug} is missing from commands.md`);
	}

	// llms.txt: the index. llms-full.txt: the language rules, the two lists and every page.
	const hold = (p) => `${PACK_URL}/${SKILL}/${p.file}`;
	const llms = [
		'# EasyUO Reforged',
		'',
		'> EasyUO Reforged runs EasyUO scripts (.euo), which automate the Ultima Online client. These files',
		'> are its documentation as plain markdown, for AI agents that write or change such scripts.',
		'',
		`Generated from EasyUO Reforged ${version}. EasyUO is a small language of its own with unusual rules:`,
		'read the language rules before writing a script, and take every command and variable name from the',
		'two lists. An unknown command is ignored without an error.',
		'',
		'Pages based on the EasyUO wiki say so at their foot and are available under the GNU Free',
		`Documentation License 1.2 (${PACK_URL}/${SKILL}/${GFDL}).`,
		'',
		'## Start here',
		'',
		`- [Language rules](${PACK_URL}/${SKILL}/language.md): the rules scripts break most often, and patterns that work`,
		`- [Commands](${PACK_URL}/${SKILL}/commands.md): every command and sub-command on one line`,
		`- [Variables](${PACK_URL}/${SKILL}/variables.md): every #variable on one line`,
		`- [reference.json](${PACK_URL}/${SKILL}/reference.json): the same data for tools`,
		`- [Everything in one file](${SITE_URL}/llms-full.txt)`,
		'',
	];
	for (const [section, label] of SECTIONS) {
		llms.push(`## ${label}`, '');
		// The rules pages are "Language rules" above, not pages of their own.
		for (const p of pages.filter((q) => q.section === section && !isRule(q)))
			llms.push(`- [${p.data.title}](${hold(p)}): ${p.data.description}`);
		llms.push('');
	}

	const full = [
		`# EasyUO Reforged ${version}: documentation for AI agents`,
		'',
		'Pages based on the EasyUO wiki say so at their foot and are available under the GNU Free',
		`Documentation License 1.2 (${PACK_URL}/${SKILL}/${GFDL}).`,
		'',
		languageMd(pages, bySlug, version, null),
		cmdList,
		varList,
	];
	for (const p of pages) if (!isRule(p)) full.push(`\n---\n\n${renderPage(p, pages, bySlug, null)}`);

	return { files, llms: llms.join('\n'), llmsFull: full.join('\n'), pages, version };
}

function writeTree(dir, files) {
	rmSync(dir, { recursive: true, force: true });
	for (const [rel, text] of files) {
		const full = join(dir, ...rel.split('/'));
		mkdirSync(dirname(full), { recursive: true });
		writeFileSync(full, text);
	}
}

export function writePack(outDir, version) {
	const pack = buildPack(version);
	writeTree(outDir, pack.files);
	return pack;
}

// For the site: <dist>/agent/... plus llms.txt and llms-full.txt at its root.
export function writeSite(distDir, version) {
	const pack = buildPack(version);
	writeTree(join(distDir, 'agent'), pack.files);
	writeFileSync(join(distDir, 'llms.txt'), pack.llms);
	writeFileSync(join(distDir, 'llms-full.txt'), pack.llmsFull);
	return pack;
}

// ------------------------------------------------------------------------------------------- CLI
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	const args = process.argv.slice(2);
	const opt = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
	try {
		const version = opt('--version');
		let pack;
		if (args.includes('--check')) pack = buildPack(version);
		else if (opt('--out')) pack = writePack(opt('--out'), version);
		else if (opt('--site')) pack = writeSite(opt('--site'), version);
		else {
			console.error('Usage: node tools/docs/gen-agent-pack.mjs (--out <dir> | --site <dist dir> | --check) [--version <v>]');
			process.exit(2);
		}
		const cmds = pack.pages.filter(isCommand).length;
		const vars = pack.pages.filter(isVariable).length;
		const kb = Math.round([...pack.files.values()].reduce((n, t) => n + Buffer.byteLength(t), 0) / 1024);
		console.log(`Agent pack ${pack.version}: ${pack.files.size} files, ${kb} KB (${cmds} commands, ${vars} variables, ${pack.pages.length - cmds - vars} other pages).`);
	} catch (e) {
		console.error(`gen-agent-pack: ${e.message}`);
		process.exit(1);
	}
}
