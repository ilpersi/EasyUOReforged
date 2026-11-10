# EasyUO Reforged documentation site

The source of <https://ilpersi.github.io/EasyUOReforged/>, built with
[Astro Starlight](https://starlight.astro.build) and published to GitHub Pages by
[`.github/workflows/docs.yml`](../.github/workflows/docs.yml) (*Publish docs site*) from the latest
release, each time a release is cut or when the workflow is run by hand. Pushes to `main` and pull
requests only build it, with [`.github/workflows/docs-check.yml`](../.github/workflows/docs-check.yml),
so a change to the site goes live with the next release.

## Preview locally

Needs Node.js 22.23 or later.

```
cd website
npm ci
npm run dev        # live preview at http://127.0.0.1:4321/EasyUOReforged/
npm run build      # full build, as CI does: fails on broken links or bad frontmatter
```

## Where things are

| Path | What it is |
|---|---|
| `src/content/docs/commands/` | One page per script command; sub-commands in a folder (`event/macro.md`). |
| `src/content/docs/variables/` | One page per `#variable`, file name without the `#` (`findid.md`). |
| `src/content/docs/**/index.mdx` | The A–Z lists. They are generated from the pages' frontmatter: never edit them to add an entry. |
| `src/reference.mjs` | Category lists and the name → URL rule, shared by everything below. |
| `src/content.config.ts` | Frontmatter schema for reference pages. |
| `src/components/` | Reference page header, "See also" block, A–Z table. |
| `src/euo-grammar.mjs` | `euo` code highlighting; command keywords come from `easyuo/eusyntax.pas`. |
| `src/sidebar.mjs` | Builds the Commands / Variables sidebar groups from frontmatter. |

## Writing a reference page

Copy an existing page of the same kind ([`commands/finditem.md`](src/content/docs/commands/finditem.md),
[`variables/findid.md`](src/content/docs/variables/findid.md)) and change it. The frontmatter
drives the header, the badges, the "Sets" / "Set by" rows, the "See also" list, the sidebar and
the A–Z lists, so the body only needs prose and examples:

- **Parameters** (table) · **Description** · **Examples** · **Notes** · **Reforged notes** (only
  when `changed: true` or `origin: reforged`).
- Code blocks use ```` ```euo ````. Every example is a whole script that runs as it is pasted: it sets up
  what it uses, shows the result and ends with `halt` (subs go after the `halt`; a script built around an
  endless main loop may end with its `goto`). `CheckDocsCoverage.ps1` checks the ending. An ID only the
  reader knows is set at the top with a comment (`set %petid ABCDEFG ; your pet's ID`). A file meant to be
  called gets a `title="..."` and ends with `exit`.
- Link to other pages root-relative, without the `/EasyUOReforged` base: `[#FindID](/variables/findid/)`.
  The build adds the base. (Hero `link:` and `LinkCard href` in `.mdx` files are the exception:
  they need the base written out.)
- In `sets:` and `related:`, name things as a script would: `'#FindID'`, `'FindItem'`,
  `'event Drag'`, `'dll:ScanItems'`. A name whose page doesn't exist yet shows as plain text.
- `source: wiki` marks text derived from the EasyUO wiki: the page then shows the GFDL 1.2 notice.

Every command, sub-command and `#variable` of the interpreter must have a page.
`tests/tools/CheckDocsCoverage.ps1` checks that against the source on every `tests/run_tests.ps1` run (and
so in CI), and also fails on a reference page that matches no real name. Exceptions go in its
`$NotDocumented` / `$PageWithoutName` tables, with a reason.

## The agent pack

The build also writes the pages as plain markdown for AI coding agents: `/agent/...`, `/llms.txt` and
`/llms-full.txt` in `dist/` (they are not served by `npm run dev`). They come from
[`tools/docs/gen-agent-pack.mjs`](../tools/docs/gen-agent-pack.mjs), which `astro.config.mjs` calls when the
build is done, and which also fills the `agent` folder of a release zip. It reads the frontmatter of the
`commands/`, `variables/`, `language/`, `guides/`, `guide/` and `reforged/` pages with a small parser of its own,
so keep frontmatter to one `key: value` per line, with lists on one line: it stops the build on a line it can't
read. The pack's `language.md`, which an agent reads in full, is three pages of this site in one file:
`language/common-mistakes.md`, `guides/patterns.md` and `guides/finding-ids.md`. A rule or pattern worth telling
an agent goes on one of them. On any page, an `euo` example may say what a variable holds at the end in a
comment starting with `=>` (`set %a 1 + 1   ; => %a = 2`): the test suite runs such examples, so they may use
only commands that need no client and don't wait (the list is in `tests/DocsExampleTests.pas`).
`tests/tools/CheckAgentPack.ps1` checks the rest.

## Licence

Text derived from the [EasyUO wiki](https://github.com/ilpersi/easyuo-wiki-archive) (pages with
`source: wiki`) is under the GNU Free Documentation License 1.2, like the wiki: see
[`LICENSE-GFDL-1.2.txt`](LICENSE-GFDL-1.2.txt) and the repository's `NOTICE`. Everything else in
this folder is under the project's BSD 2-Clause licence.
