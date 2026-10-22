import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { ALL_CATEGORY_KEYS, KINDS } from './reference.mjs';

// Extra frontmatter for reference pages (commands, #variables, uo.dll members). Prose pages
// leave `kind` out and none of these fields apply. Rules that span several fields (a variable
// needs `access`, a command needs `syntax`, the category must belong to the kind) are checked in
// src/components/refdata.ts, because Starlight's schema merge does not keep Zod refinements.
const reference = z.object({
	// command | subcommand | variable | dll-property | dll-method | dll-call
	kind: z.enum(KINDS as [string, ...string[]]).optional(),
	// key from src/reference.mjs, e.g. 'client', 'finditem'
	category: z.enum(ALL_CATEGORY_KEYS as [string, ...string[]]).optional(),
	// one-line usage, shown highlighted under the title
	syntax: z.string().optional(),
	// 'reforged' = added by this port; 'original' = existed in EasyUO 1.5
	origin: z.enum(['original', 'reforged']).default('original'),
	// true when Reforged behaves differently from EasyUO 1.5; the page then needs a "Reforged notes" section
	changed: z.boolean().default(false),
	obsolete: z.boolean().default(false),
	// variables: read-only or read/write
	access: z.enum(['ro', 'rw']).optional(),
	// variables: what the value looks like
	type: z.enum(['number', 'string', 'boolean', 'id']).optional(),
	// works only with a client attached
	needsClient: z.boolean().default(false),
	// commands: the #variables this command fills ('#FindID', ...)
	sets: z.array(z.string()).default([]),
	// names for "See also": 'IgnoreItem', '#FindIndex', 'event macro', 'dll:ScanItems'
	related: z.array(z.string()).default([]),
	// matching uo.dll member, if any
	dll: z.string().optional(),
	// extra search terms
	aliases: z.array(z.string()).default([]),
	// 'wiki' = text derived from the EasyUO wiki (GFDL 1.2); shows the licence notice
	source: z.enum(['wiki', 'new']).default('new'),
});

export const collections = {
	docs: defineCollection({ loader: docsLoader(), schema: docsSchema({ extend: reference }) }),
};
