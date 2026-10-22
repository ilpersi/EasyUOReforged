// TextMate grammar for ```euo code blocks, built at config time.
//
// The command keywords are read straight from easyuo/eusyntax.pas (CommandKeywords), the list
// the editor's own highlighter and autocomplete use, so a new command is highlighted on the site
// as soon as it is highlighted in the editor. #variables are matched by shape (#name) rather than
// by list, so a page about a new variable never shows it unhighlighted.
//
// Token rules follow eusyntax.pas: ';' comments to end of line, "..." strings, % * ! # variables,
// $ hex literals (a lone $ is the line break in msg/display text), red operators and brackets.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const EUSYNTAX = fileURLToPath(new URL('../../easyuo/eusyntax.pas', import.meta.url));

function readCommandKeywords() {
	const src = readFileSync(EUSYNTAX, 'utf8');
	const m = src.match(/CommandKeywords\s*:\s*array\[[^\]]*\]\s*of\s*String\s*=\s*\(([\s\S]*?)\);/i);
	if (!m) throw new Error(`CommandKeywords not found in ${EUSYNTAX}`);
	return [...m[1].matchAll(/'([^']+)'/g)].map((k) => k[1].toLowerCase());
}

export function euoGrammar() {
	const commands = readCommandKeywords().join('|');
	return {
		name: 'euo',
		scopeName: 'source.euo',
		displayName: 'EasyUO',
		aliases: ['easyuo'],
		patterns: [
			{ name: 'comment.line.semicolon.euo', match: ';.*$' },
			{ name: 'string.quoted.double.euo', match: '"[^"]*"' },
			{
				match: '(?i)^\\s*(sub)\\s+([A-Za-z0-9_]+)',
				captures: { 1: { name: 'keyword.control.euo' }, 2: { name: 'entity.name.function.euo' } },
			},
			{
				match: '(?i)\\b(gosub|goto)\\s+([A-Za-z0-9_]+)',
				captures: { 1: { name: 'keyword.control.euo' }, 2: { name: 'entity.name.function.euo' } },
			},
			{ name: 'entity.name.label.euo', match: '^\\s*[A-Za-z0-9_]+:(?=\\s*(;.*)?$)' },
			{ name: 'variable.language.euo', match: '#[A-Za-z0-9_]+' },
			{ name: 'variable.other.euo', match: '[%!][A-Za-z0-9_]+' },
			{ name: 'variable.other.persistent.euo', match: '\\*[A-Za-z0-9_]+' },
			{ name: 'constant.numeric.hex.euo', match: '\\$[0-9A-Fa-f]+\\b' },
			{ name: 'constant.character.escape.euo', match: '\\$' },
			{ name: 'keyword.control.euo', match: `(?i)\\b(${commands})\\b` },
			{ name: 'keyword.operator.word.euo', match: '(?i)\\b(abs|in|notin)\\b' },
			{ name: 'constant.numeric.euo', match: '(?<![A-Za-z_])[+-]?\\d+(?![A-Za-z_])' },
			{ name: 'keyword.operator.euo', match: '<>|<=|>=|=<|=>|&&|\\|\\||[=<>+\\-*/,.]' },
			{ name: 'punctuation.section.euo', match: '[{}()\\[\\]]' },
		],
	};
}
