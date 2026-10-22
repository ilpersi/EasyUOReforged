#!/usr/bin/env python3
"""One-off import of the EasyUO wiki export into the documentation site.

Reads EasyUO-Documentation.md (https://github.com/ilpersi/easyuo-wiki-archive) and writes into
website/src/content/docs/:
  - one page per command, sub-command and #variable (commands/, variables/),
  - overview pages for the event / menu / namespace command families,
  - the language reference (language/) and the tutorials and appendices (guides/).

Its output was committed once and is edited by hand from then on. The script stays in the repo to
show where that text came from; it is not a build step, and it never overwrites a page unless
--force is given.

What it does to the text, beyond splitting it:
  - **Synopsis** becomes the `syntax:` frontmatter, the category tables' one-line summaries become
    `description:`, **Related:** lines become `related:`. Those are rendered by the site's
    components, so they are removed from the body.
  - Access (read-only / read-write) and value type of each #variable come from
    parser/EuoInterpreter.pas (VarNamesR / VarNamesRW and the GetVar conversions), not from the wiki.
  - Indented code becomes ```euo fences, GitHub `> [!NOTE]` blocks become Starlight `:::note`
    asides, headings move up so each page starts at `##`.
  - Links to wiki anchors (#cmd-…, #var-…, #sec-…) and to wiki.easyuo.com pages become links to
    the new pages. Links that cannot be mapped keep their text and lose the link (reported).
  - Notes that only say "available in EasyUO 1.5+" are dropped: Reforged is based on 1.5.
  - The wiki's Installation page (for the original EasyUO download) is not imported.

Usage:
  python tools/docs/import-wiki.py --source path/to/EasyUO-Documentation.md [--force]
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'website' / 'src' / 'content' / 'docs'
INTERP = ROOT / 'parser' / 'EuoInterpreter.pas'

CMD_SECTIONS = {
    'sec-flow-control': 'flow', 'sec-client': 'client', 'sec-event': 'event',
    'sec-exevent': 'exevent', 'sec-menu': 'menu', 'sec-namespace': 'namespace',
    'sec-miscellaneous': 'misc', 'sec-obsolete': 'obsolete',
}
VAR_SECTIONS = {
    'sec-character-variables': 'character', 'sec-status-variables': 'status',
    'sec-container': 'container', 'sec-last-action': 'lastaction', 'sec-finditem': 'finditem',
    'sec-shop': 'shop', 'sec-extended': 'extended', 'sec-client-variables': 'client',
    'sec-combat': 'combat', 'sec-namespace-variables': 'namespace',
    'sec-miscellaneous-variables': 'misc', 'sec-result': 'result', 'sec-tile': 'tile',
    'sec-constant': 'constant',
}
# Categories whose entries only make sense with a client attached. The mixed ones (Extended,
# Client) are left for the editorial pass rather than guessed.
CLIENT_CATEGORIES = {('command', 'client'), ('command', 'event'), ('command', 'exevent'),
                     *(('variable', c) for c in ('character', 'status', 'container', 'lastaction',
                                                 'finditem', 'shop', 'combat'))}

# Prose units: anchor -> (slug, title, sidebar order). None = not imported.
PROSE = {
    'guide-installation': None,
    'guide-introduction': ('guides/introduction', 'Introduction', 1),
    'guide-beginners-tutorial': ('guides/beginners-tutorial', "Beginner's tutorial", 2),
    'ref-variables': ('language/variables', 'Variables', 1),
    'ref-expressions': ('language/expressions', 'Expressions', 2),
    'ref-operators': ('language/operators', 'Operators', 3),
    'ref-control-structures': ('language/control-structures', 'Control structures', 4),
    'apx-qg-true-false': ('guides/true-and-false', '#True and #False', 3),
    'apx-tutorialscheffe1': ('guides/execution-speed', 'Execution speed', 4),
    'apx-how-stat-and-skill-gains-work-on-runuo-freeshards':
        ('guides/stat-and-skill-gains', 'Stat and skill gains on RunUO shards', 5),
    'apx-item-database': ('guides/containers-and-gumps', 'Containers and gumps', 6),
}
# Where links to whole wiki sections go.
SECTION_LINKS = {
    'sec-getting-started': '/guides/introduction/',
    'sec-language-reference': '/language/variables/',
    'sec-command-reference': '/commands/',
    'sec-system-variable-reference': '/variables/',
    'sec-appendices': '/guides/introduction/',
    **{k: f'/commands/?category={v}' for k, v in CMD_SECTIONS.items()},
    **{k: f'/variables/?category={v}' for k, v in VAR_SECTIONS.items()},
}
# Command families that get a generated overview page (exevent has a wiki entry of its own).
FAMILIES = {
    'event': ('Event', 'sec-event', 'event {type} [parameters...]'),
    'menu': ('Menu', 'sec-menu', 'menu {element} [parameters...]'),
    'namespace': ('Namespace', 'sec-namespace', 'namespace {local|global|clear|push|pop|copy} [parameters...]'),
}
EXEVENT_SYNTAX = 'exevent {type} [parameters...]'
# Commands the generated pages say they fill, by variable category.
SETS_BY_CATEGORY = {'tile': 'tile', 'getshopinfo': 'shop'}

ANCHOR_RE = re.compile(r'^<a id="((?:cmd|var|ref|guide|apx|sec)-[^"]+)"></a>\s*$')
LINK_RE = re.compile(r'\[([^\]]*)\]\(([^)\s]+)\)')
ONLY_15_RE = re.compile(r'^(this (command|variable) is )?only available (in|from) (easyuo|euo) ?1\.5\+?\.?$', re.I)

report = {'written': [], 'skipped': [], 'unmapped_links': [], 'no_syntax': [], 'dropped_notes': 0}


# --------------------------------------------------------------------------------------------
# The interpreter: canonical #variable names, access and value type
# --------------------------------------------------------------------------------------------

def pascal_array(src, name):
    m = re.search(name + r"\s*:\s*Array\[[^\]]*\]\s*of\s*String\s*=\s*\((.*?)\);", src, re.S | re.I)
    if not m:
        sys.exit(f'{name} not found in {INTERP}')
    return re.findall(r"'([^']+)'", m.group(1))


def interpreter_variables():
    """lower-case name -> (canonical name, 'ro'|'rw', type)."""
    src = INTERP.read_text(encoding='utf-8', errors='replace')
    names_r, names_rw = pascal_array(src, 'VarNamesR'), pascal_array(src, 'VarNamesRW')
    getvar = src[src.index('function TEuoInterpreter.GetVar'):src.index('procedure TEuoInterpreter.SetVar')]
    parts = re.split(r'^\s*(\d{3})\s*:', getvar, flags=re.M)
    bodies = {int(parts[i]): parts[i + 1] for i in range(1, len(parts), 2)}

    def classify(name, body):
        if name.upper() in ('TRUE', 'FALSE'):
            return 'boolean'
        if "+'_'+" in body:
            return 'string'           # "x_y" pairs such as #FindMod
        if 'CardToSys26' in body:
            return 'id'
        if 'IntToStr' in body and 'Byte(' in body:
            return 'boolean'          # 1 / 0 flags such as #CliLogged
        if 'IntToStr' in body:
            return 'number'
        return 'string'

    out = {}
    for i, n in enumerate(names_r):
        out[n.lower()] = (n, 'ro', classify(n, bodies.get(i, '')))
    for i, n in enumerate(names_rw):
        out[n.lower()] = (n, 'rw', classify(n, bodies.get(500 + i, '')))
    return out


# --------------------------------------------------------------------------------------------
# Names and slugs
# --------------------------------------------------------------------------------------------

def slug_for(anchor):
    kind, _, name = anchor.partition('-')
    if kind == 'cmd':
        special = {'repeatuntil': 'repeat', 'str-command': 'str'}
        return 'commands/' + special.get(name, name.replace('-', '/'))
    if kind == 'var':
        return 'variables/' + {'str-system-variable': 'str'}.get(name, name)
    prose = PROSE.get(anchor)
    return prose[0] if prose else None


def ref_name(slug):
    """Frontmatter name for a slug, in the form src/reference.mjs refSlug() maps back."""
    section, _, rest = slug.partition('/')
    return '#' + rest if section == 'variables' else rest.replace('/', ' ')


def command_title(heading, slug):
    special = {'commands/str': 'Str', 'commands/repeat': 'Repeat … Until', 'commands/exevent': 'ExEvent',
               'commands/uoxl': 'UOXL'}
    if slug in special:
        return special[slug]
    words = heading.split()
    if slug.count('/') >= 2:                       # sub-command: "event Drag", "menu Font Align"
        words[0] = words[0].lower()
    return ' '.join(words)


def sentence(text):
    text = text.strip()
    if text and text[0].islower():
        text = text[0].upper() + text[1:]
    if text and text[-1] not in '.!?…':
        text += '.'
    return text


def plain(text):
    """Markdown inline -> plain text, for descriptions."""
    text = LINK_RE.sub(r'\1', text)
    text = re.sub(r'[*`]', '', text)
    return re.sub(r'\\(.)', r'\1', text).strip()


def first_sentence(lines):
    para = []
    for line in lines:
        s = line.strip()
        if not s:
            if para:
                break
            continue
        if s.startswith(('#', '|', '>', ':::', '```', '<', '-', '*Read')) or s.startswith('    '):
            if para:
                break
            continue
        para.append(s)
    text = plain(' '.join(para))
    m = re.match(r'(.+?[.!?])(\s|$)', text)
    text = m.group(1) if m else text
    return sentence(text[:200])


# --------------------------------------------------------------------------------------------
# Body conversion
# --------------------------------------------------------------------------------------------

def is_indented(line):
    return line.startswith('    ') or line.startswith('\t')


def dedent(line):
    return line[1:] if line.startswith('\t') else line[4:]


LIST_ITEM_RE = re.compile(r'^\s*([-*+]|\d+\.)\s')


def indent_of(line):
    return len(line.expandtabs(4)) - len(line.expandtabs(4).lstrip())


def convert_blocks(lines):
    """Alerts -> asides and indented code -> fences, recursively inside asides.

    After a list item, an indented line only continues the item when it lines up with the item's
    text ("1.  text" puts the text at column 4). The wiki's "- item" lines put it at column 2, and a
    4-space block under them is a code example, so it becomes a fence.
    """
    out, i, list_col = [], 0, None
    while i < len(lines):
        line = lines[i]
        if line.startswith('```'):                 # existing fence: copy through
            out.append(line)
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                out.append(lines[i])
                i += 1
            if i < len(lines):
                out.append(lines[i])
                i += 1
            continue
        m = re.match(r'^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$', line)
        if m:
            inner = []
            i += 1
            while i < len(lines) and lines[i].startswith('>'):
                inner.append(re.sub(r'^> ?', '', lines[i]))
                i += 1
            inner = [l for l in convert_blocks(inner) if l.strip() != '<!-- -->']
            text = ' '.join(l.strip() for l in inner if l.strip() and l.strip() != '-')
            if not text or ONLY_15_RE.match(plain(text).lstrip('- ').strip()):
                report['dropped_notes'] += 1
                continue
            variant = {'NOTE': 'note', 'TIP': 'tip', 'IMPORTANT': 'caution',
                       'WARNING': 'caution', 'CAUTION': 'danger'}[m.group(1)]
            while inner and not inner[0].strip():
                inner.pop(0)
            while inner and not inner[-1].strip():
                inner.pop()
            out += ['', f':::{variant}', *inner, ':::', '']
            continue
        prev_blank = not out or not out[-1].strip()
        continues_item = list_col is not None and indent_of(line) == list_col
        if is_indented(line) and line.strip() and prev_blank and not continues_item:
            block = []
            while i < len(lines):
                if is_indented(lines[i]) and lines[i].strip():
                    block.append(dedent(lines[i]))
                    i += 1
                elif not lines[i].strip() and i + 1 < len(lines) and is_indented(lines[i + 1]) and lines[i + 1].strip():
                    block.append('')
                    i += 1
                else:
                    break
            out += ['```euo', *[b.rstrip() for b in block], '```']
            continue
        if line.strip():
            item = LIST_ITEM_RE.match(line)
            if item:
                list_col = item.end()
            elif not is_indented(line):
                list_col = None
        out.append(line)
        i += 1
    return out


def map_link(target, anchors, wiki_names):
    if target.startswith('#'):
        a = target[1:]
        if a in SECTION_LINKS:
            return SECTION_LINKS[a]
        slug = anchors.get(a)
        return f'/{slug}/' if slug else None
    m = re.match(r'https?://wiki\.easyuo\.com/index\.php(?:/|\?title=)([^&#)]+)', target)
    if m:
        slug = wiki_names.get(m.group(1).lower())
        return f'/{slug}/' if slug else None
    return target


def rewrite_inline(line, anchors, wiki_names, page):
    def repl(m):
        text, target = m.group(1), m.group(2)
        new = map_link(target, anchors, wiki_names)
        if new is None:
            report['unmapped_links'].append(f'{page}: [{text}]({target})')
            return text
        return f'[{text}]({new})'
    return LINK_RE.sub(repl, line)


def finish(lines, title_level, anchors, wiki_names, page):
    out, in_fence = [], False
    for line in lines:
        if line.startswith('```'):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence:
            out.append(line)
            continue
        if ANCHOR_RE.match(line) or re.match(r'^<a id="[^"]+"></a>\s*$', line):
            continue
        line = line.replace('<!-- -->', '')
        h = re.match(r'^(#{2,6}) (.*)$', line)
        if h:
            level = max(2, len(h.group(1)) - (title_level - 1))
            line = '#' * level + ' ' + h.group(2).strip()
        out.append(rewrite_inline(line, anchors, wiki_names, page).rstrip())
    text = '\n'.join(out)
    text = re.sub(r'\n{3,}', '\n\n', text).strip('\n')
    return text + '\n'


def extract_synopsis(lines):
    """Removes the **Synopsis** block; returns (syntax lines, remaining lines)."""
    for i, line in enumerate(lines):
        if line.strip() == '**Synopsis**':
            j, syn = i + 1, []
            while j < len(lines) and (not lines[j].strip() or is_indented(lines[j])):
                if lines[j].strip():
                    syn.append(dedent(lines[j]).rstrip())
                j += 1
            return syn, lines[:i] + lines[j:]
    return [], lines


def extract_related(lines, anchors):
    related, out, skipping = [], [], False
    for line in lines:
        s = line.strip()
        if re.match(r'^#{4,6} (Releated|Related) Commands', s):
            skipping = True
            continue
        if skipping:
            if not s or (LINK_RE.search(s) and not LINK_RE.sub('', s).strip(' ,-*')):
                for _, t in LINK_RE.findall(s):
                    related.append(t)
                continue
            skipping = False
        if re.match(r'^\*\*Related:?\*\*', s):
            related += [t for _, t in LINK_RE.findall(s)]
            continue
        out.append(line)
    names = []
    for t in related:
        slug = anchors.get(t.lstrip('#')) if t.startswith('#') else None
        if slug and slug.startswith(('commands/', 'variables/')):
            names.append(ref_name(slug))
    return names, out


# --------------------------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------------------------

def ys(value):
    return json.dumps(value, ensure_ascii=False)


def page_path(slug, all_slugs):
    if any(s.startswith(slug + '/') for s in all_slugs):
        return DOCS / slug / 'index.md'
    return DOCS / (slug + '.md')


def write_page(slug, fm, body, all_slugs, force):
    path = page_path(slug, all_slugs)
    if path.exists() and not force:
        report['skipped'].append(slug)
        return
    lines = ['---']
    for key, value in fm.items():
        if value is None or value == [] or value is False:
            continue
        if key == 'sidebar':
            lines += ['sidebar:', f'  order: {value}']
        elif isinstance(value, bool):
            lines.append(f'{key}: true')
        elif isinstance(value, list):
            lines.append(f'{key}: [' + ', '.join(ys(v) for v in value) + ']')
        elif isinstance(value, int):
            lines.append(f'{key}: {value}')
        elif key in ('kind', 'category', 'access', 'type', 'source'):
            lines.append(f'{key}: {value}')
        else:
            lines.append(f'{key}: {ys(value)}')
    lines.append('---')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(lines) + '\n\n' + body, encoding='utf-8', newline='\n')
    report['written'].append(slug)


def parse_section(lines):
    """Category unit -> (title, intro lines, {anchor: summary}, table lines)."""
    title, intro, table, summaries = '', [], [], {}
    for line in lines:
        if line.startswith('### '):
            title = line[4:].strip()
        elif line.startswith('|'):
            table.append(line)
            m = re.match(r'^\|\s*\[[^\]]*\]\(#((?:cmd|var)-[^)]+)\)[^|]*\|\s*(.*?)\s*\|\s*$', line)
            if m:
                summaries[m.group(1)] = m.group(2)
        elif not table and not line.startswith('## '):
            intro.append(line)
    return title, intro, summaries, table


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--source', required=True, type=Path, help='EasyUO-Documentation.md')
    ap.add_argument('--force', action='store_true', help='overwrite pages that already exist')
    args = ap.parse_args()

    lines = args.source.read_text(encoding='utf-8').splitlines()
    variables = interpreter_variables()

    units, start, current = [], None, None
    for i, line in enumerate(lines + ['<a id="sec-end"></a>']):
        m = ANCHOR_RE.match(line)
        if m:
            if current:
                units.append((current, lines[start:i]))
            current, start = m.group(1), i + 1

    anchors = {a: slug_for(a) for a, _ in units if slug_for(a)}
    all_slugs = set(anchors.values()) | {f'commands/{f}' for f in FAMILIES}
    # wiki page names ("Exit", "FindItem", "CharPosX") -> slug, for links to wiki.easyuo.com
    wiki_names = {}
    for a, slug in anchors.items():
        if slug.startswith(('commands/', 'variables/')) and slug.count('/') == 1:
            wiki_names.setdefault(slug.split('/')[1], slug)

    sections, summaries, category = {}, {}, None
    for a, body in units:
        if a.startswith('sec-'):
            sections[a] = parse_section(body)
            summaries.update(sections[a][2])

    var_by_category = {}
    for a, body in units:
        if a.startswith('sec-'):
            category = CMD_SECTIONS.get(a) or VAR_SECTIONS.get(a)
            continue
        slug = anchors.get(a)
        if a.startswith('var-') and slug:
            var_by_category.setdefault(category, []).append(ref_name(slug))

    category = None
    for a, body in units:
        if a.startswith('sec-'):
            category = CMD_SECTIONS.get(a) or VAR_SECTIONS.get(a)
            continue
        slug = anchors.get(a)
        if not slug:
            continue
        page = slug
        h = next((i for i, l in enumerate(body) if re.match(r'^#{3,4} ', l)), None)
        title_level, heading_text = 4, slug
        if h is not None:
            marks, heading_text = body[h].split(' ', 1)
            title_level, heading_text = len(marks), heading_text.strip()
            body = body[:h] + body[h + 1:]

        if a.startswith(('cmd-', 'var-')):
            syntax, body = extract_synopsis(body)
            body = [l for l in body if l.strip() != '**Description**']
            related, body = extract_related(body, anchors)
            related = [r for r in dict.fromkeys(related) if r != ref_name(slug)]
            body = [re.sub(r'^\*(Read-only|Read / write)\.\*\s*', '', l) for l in body]
            text = finish(convert_blocks(body), title_level, anchors, wiki_names, page)
            summary = summaries.get(a)
            description = sentence(plain(summary)) if summary else first_sentence(text.splitlines())

            if a.startswith('cmd-'):
                kind = 'command' if slug.count('/') == 1 else 'subcommand'
                if slug == 'commands/exevent':
                    title_, intro, _, _ = sections['sec-exevent']
                    text = finish(convert_blocks(intro), 3, anchors, wiki_names, page) + '\n' + text
                    syntax = syntax or [EXEVENT_SYNTAX]
                    description = first_sentence(intro)
                if not syntax:
                    report['no_syntax'].append(slug)
                name = slug.split('/')[-1]
                sets = var_by_category.get(SETS_BY_CATEGORY[name], []) if name in SETS_BY_CATEGORY and kind == 'command' else []
                fm = {
                    'title': command_title(heading_text, slug), 'description': description,
                    'kind': kind, 'category': category,
                    'syntax': '\n'.join(syntax) if syntax else None,
                    'needsClient': ('command', category) in CLIENT_CATEGORIES,
                    'obsolete': category == 'obsolete',
                    'sets': sets, 'related': related, 'source': 'wiki',
                }
            else:
                canonical, access, vtype = variables.get(slug.split('/')[1], (heading_text, None, None))
                if access is None:
                    print(f'warning: {slug} is not in the interpreter tables', file=sys.stderr)
                fm = {
                    'title': '#' + canonical, 'description': description, 'kind': 'variable',
                    'category': category, 'access': access, 'type': vtype,
                    'needsClient': ('variable', category) in CLIENT_CATEGORIES,
                    'related': related, 'source': 'wiki',
                }
            write_page(slug, fm, text, all_slugs, args.force)
        else:
            _, title, order = PROSE[a]
            text = finish(convert_blocks(body), title_level, anchors, wiki_names, page)
            fm = {'title': title, 'description': first_sentence(text.splitlines()), 'sidebar': order,
                  'source': 'wiki'}
            write_page(slug, fm, text, all_slugs, args.force)

    for name, (title, sec, syntax) in FAMILIES.items():
        _, intro, _, table = sections[sec]
        body = convert_blocks(intro + [''] + table)
        text = finish(body, 3, anchors, wiki_names, f'commands/{name}')
        fm = {'title': title, 'description': first_sentence(intro), 'kind': 'command', 'category': name,
              'syntax': syntax, 'needsClient': ('command', name) in CLIENT_CATEGORIES, 'source': 'wiki'}
        write_page(f'commands/{name}', fm, text, all_slugs, args.force)

    skipped = report['skipped']
    print(f"written: {len(report['written'])}   skipped (already exist): {len(skipped)}"
          + (f" {skipped}" if len(skipped) <= 10 else ''))
    print(f"notes dropped (empty or '1.5+ only'): {report['dropped_notes']}")
    if report['no_syntax']:
        print(f"commands without a synopsis: {report['no_syntax']}")
    if report['unmapped_links']:
        print(f"links kept as text ({len(report['unmapped_links'])}):")
        for l in report['unmapped_links']:
            print('  ' + l)


if __name__ == '__main__':
    main()
