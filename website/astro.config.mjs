// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { satteri } from '@astrojs/markdown-satteri';
import starlightLinksValidator from 'starlight-links-validator';
import { SITE, BASE, REPO } from './src/reference.mjs';
import { referenceSidebar, folderGroup } from './src/sidebar.mjs';
import { euoGrammar } from './src/euo-grammar.mjs';

// Pages link to each other root-relative ("/variables/findid/"); this puts the GitHub Pages
// base ("/EasyUOReforged") in front at build time, so no page has to spell it out. It runs as an
// mdast plugin, before the links validator (a hast plugin) sees the links.
const baseLinks = {
	name: 'base-links',
	/** @param {{ url: string }} node @param {any} ctx */
	link(node, ctx) {
		const url = node.url;
		if (url.startsWith('/') && !url.startsWith('//') && !url.startsWith(`${BASE}/`))
			ctx.setProperty(node, 'url', `${BASE}${url}`);
	},
};

export default defineConfig({
	site: SITE,
	base: BASE,
	trailingSlash: 'always',
	// Node resolves "localhost" to the IPv6 loopback only, which some browsers don't try;
	// an explicit IPv4 address works everywhere.
	server: { host: '127.0.0.1', port: 4321 },
	markdown: {
		processor: satteri({ mdastPlugins: [baseLinks] }),
	},
	integrations: [
		starlight({
			title: 'EasyUO Reforged',
			description:
				'Reference and guides for EasyUO Reforged: every script command, every #variable and the uo.dll API.',
			favicon: '/favicon.ico',
			social: [{ icon: 'github', label: 'GitHub', href: REPO }],
			editLink: { baseUrl: `${REPO}/edit/main/website/` },
			lastUpdated: true,
			customCss: ['./src/styles/custom.css'],
			components: {
				PageTitle: './src/components/PageTitle.astro',
				MarkdownContent: './src/components/MarkdownContent.astro',
			},
			expressiveCode: {
				shiki: { langs: [euoGrammar()] },
			},
			plugins: [starlightLinksValidator()],
			sidebar: [
				...folderGroup('Get started', 'guide'),
				...folderGroup('Language', 'language'),
				...referenceSidebar(),
				...folderGroup('Guides', 'guides', true),
				...folderGroup('Reforged', 'reforged'),
			],
		}),
	],
});
