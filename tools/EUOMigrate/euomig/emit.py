"""Output: the candidates file (the hand-over between migrate, verify, probe and emit), a Markdown
report, and Pascal for uo\\uoclidata.pas.

candidates.json
  target      path, version, stamp, relocatable, sha256
  base        what uoclidata.pas gives the target today (floor milestone / modern layout)
  references  [{id, closeness, matched}]  closest first
  fields      name -> {value, conf, status, how, alts: [[value, conf, how], ...], checks: [...]}
              status: accepted   C_/E_ value with conf >= MIN_CONF
                      candidate  best guess below that: verify it before use
                      n/a        nothing found
                      unused     0 in the closest reference (that form of the feature is not used)
                      inherited  B_/F_ value taken over from base (conv / probe / verify may change it)
                      derived    B_/F_ value read from the target's code (conv, global distances)
                      probed     B_ value found in the running client by probe (differs from before)
                      verified / rejected   set by verify / probe
"""
import datetime
import json
import os

from . import TOOL_VERSION
from .resolve import MIN_CONF

USABLE = ('accepted', 'verified', 'derived', 'probed')

# Fields the Pascal side only ever uses together: one unusable member makes the others useless or
# harmful (a hook site without the call it replaces patches code it cannot undo), so the whole
# group goes to 0 -- the feature is then off instead of half-wired. Members a build does not use
# ('unused') do not count.
GROUPS = {
    'event hook': ('E_REDIR', 'E_OLDDIR'),
    'item properties': ('E_ITEMPROPID', 'E_ITEMNAMEADDR', 'E_ITEMPROPADDR', 'E_ITEMCHECKADDR', 'E_ITEMREQADDR'),
    'messages': ('E_SYSMSGADDR', 'E_EXMSGADDR', 'E_NEWOBJ', 'E_MSGGATE', 'E_MSGFLAGA', 'E_MSGFLAGB'),
    'pathfind': ('E_PATHFINDADDR', 'E_PATHFINDMID'),
    'macros': ('E_MACROADDR', 'E_MACROTAB'),
    'send packet': ('E_SENDPACKET', 'E_SENDECX', 'E_SENDLEN'),
    'buff bar': ('C_CLILOC', 'C_BUFFTIMERS'),
    'house pieces': ('C_WORLDGRID', 'C_STATICVT'),
}


def incomplete_groups(F):
    """{field: group name} for members of groups with an unusable member"""
    out = {}
    for g, members in GROUPS.items():
        live = [f for f in members if f in F and F[f]['status'] != 'unused']
        if any(F[f]['status'] not in USABLE for f in live):
            for f in live:
                out[f] = g
    return out


def status_of(f, r):
    if f[:2] in ('B_', 'F_'):
        return 'inherited'
    if r.value is None:
        return 'n/a'
    if r.value == 0 and r.conf >= 1.0:
        return 'unused'
    return 'accepted' if r.conf >= MIN_CONF else 'candidate'


def apply_derived(c, derived, base_state):
    """conv results (field -> (value, evidence)) replace inherited B_/F_ values"""
    for f, (v, how) in derived.items():
        e = c['fields'].get(f)
        if e is None:
            continue
        old = base_state.get(f, 0)
        e.update(value=v, conf=1.0, status='derived',
                 how=how + ('' if v == old else ' (inherited value was $%X)' % old))


def candidates(mig):
    t = mig.target
    out = {
        'tool': TOOL_VERSION,
        'created': datetime.datetime.now().isoformat(timespec='seconds'),
        'target': {'path': t.path, 'version': t.version, 'stamp': t.stamp, 'relocatable': t.relocatable,
                   'sha256': t.pe.sha256(), 'id': t.id},
        'base': mig.base_label,
        'references': [{'id': r.ref.id, 'closeness': round(r.closeness, 3), 'matched': len(r.M.m)} for r in mig.runs],
        'fields': {},
    }
    out['pseudo'] = {k: {'value': r.value, 'conf': round(r.conf, 3), 'how': r.how}
                     for k, r in mig.results.items() if k.startswith('@')}
    for f in mig.fields:
        r = mig.results[f]
        out['fields'][f] = {
            'value': r.value, 'conf': round(r.conf, 3), 'status': status_of(f, r), 'how': r.how,
            'alts': [[v, round(c, 3), h] for v, c, h in r.alts if v is not None],
            'checks': [],
        }
    return out


def save_json(d, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, indent=1)


def load_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def hx(v):
    return '$%08X' % (v or 0)


# ---- report -------------------------------------------------------------------------------------
def report_md(c):
    t = c['target']
    L = ['# EUOMigrate report: %s' % t['id'], '',
         '- target: `%s` (version %s, PE stamp %08X, %s)' % (
             os.path.basename(t['path']), t['version'], t['stamp'], 'relocatable' if t['relocatable'] else 'fixed base'),
         '- created %s by EUOMigrate %s' % (c['created'], c['tool']),
         '- B_/F_ values inherited from: %s' % c['base'],
         '- references (closest first): ' + ', '.join('%s (closeness %.2f, %d functions)' % (
             r['id'], r['closeness'], r['matched']) for r in c['references']),
         '']
    by = {}
    for f, e in c['fields'].items():
        by.setdefault(e['status'], []).append(f)
    L.append('| status | fields |')
    L.append('|---|---|')
    for s in ('verified', 'accepted', 'candidate', 'rejected', 'n/a', 'unused', 'inherited'):
        if by.get(s):
            L.append('| %s | %d |' % (s, len(by[s])))
    L.append('')
    L.append('`accepted` is static evidence above confidence %.2f; `candidate` must be verified before use '
             '(emit writes 0 for it). Code addresses (E_*) are patched with machine code at run time: '
             'never use one that has not been verified.' % MIN_CONF)
    L.append('')
    L.append('## Addresses')
    L.append('')
    L.append('| field | value | conf | status | evidence | runners-up |')
    L.append('|---|---|---|---|---|---|')
    for f, e in c['fields'].items():
        if f[:2] not in ('C_', 'E_'):
            continue
        if e['status'] == 'unused':
            continue
        alts = ' '.join('%08X (%.2f)' % (v, s) for v, s, h in e['alts'][:3])
        L.append('| %s | %s | %.2f | %s | %s | %s |' % (
            f, ('%08X' % e['value']) if e['value'] is not None else '-', e['conf'], e['status'],
            e['how'].replace('|', '/')[:220], alts))
    L.append('')
    unused = [f for f, e in c['fields'].items() if e['status'] == 'unused']
    if unused:
        L.append('Not used by the closest reference (left 0): ' + ', '.join(unused))
        L.append('')
    checks = [(f, ch) for f, e in c['fields'].items() for ch in e.get('checks', [])]
    if checks:
        L.append('## Checks')
        L.append('')
        for f, ch in checks:
            L.append('- %s: %s' % (f, ch))
        L.append('')
    L.append('## Layouts and flags')
    L.append('')
    der = [(f, e) for f, e in c['fields'].items() if f[:2] in ('B_', 'F_') and e['status'] in ('derived', 'verified', 'probed')]
    if der:
        L.append('Read from this build\'s code (derived) or from the running client (verified / probed):')
        L.append('')
        for f, e in der:
            L.append('- %s = %s (%s): %s' % (f, hx(e['value']), e['status'], e['how']))
        L.append('')
    L.append('Inherited from %s (structure offsets are not visible statically; `probe` checks them in the '
             'running client):' % c['base'])
    L.append('')
    L.append(', '.join('%s=%s' % (f, hx(e['value'])) for f, e in c['fields'].items()
                       if f[:2] in ('B_', 'F_') and e['status'] == 'inherited' and e['value']))
    L.append('')
    return '\n'.join(L)


# ---- Pascal -------------------------------------------------------------------------------------
def _entry(f, v, comment=''):
    s = '  (Expr: %s; Val: %s),' % (f, hx(v))
    return s + ('   // ' + comment if comment else '')


def _value_for_table(e, group=None):
    """what goes into the table: usable values as they are, anything unverified as 0 (a zero C_/E_
    field disables the feature; a wrong one reads garbage or patches the wrong code)"""
    return e['value'] if e['status'] in USABLE and not group else 0


def _comment(e, group=None):
    if e['status'] in USABLE:
        s = '%s %.2f' % (e['status'], e['conf'])
        return s + ('; 0 because the %s group is incomplete (%08X)' % (group, e['value']) if group else '')
    if e['value']:
        return 'UNVERIFIED candidate %08X (conf %.2f) -- verify, then put it here' % (e['value'], e['conf'])
    return e['status']


def pascal(c, u):
    t = c['target']
    head = ['// ---- generated by EUOMigrate %s on %s for %s ----' % (c['tool'], c['created'][:10], t['id']),
            '// references: ' + ', '.join('%s (%.2f)' % (r['id'], r['closeness']) for r in c['references']),
            '// unverified candidates are written as 0; see the report before using any E_* value.']
    F = c['fields']
    G = incomplete_groups(F)
    if G:
        head.append('// incomplete feature groups, written as 0: ' + ', '.join(sorted(set(G.values()))))
    if t['relocatable']:
        name = 'SysVarModernAddrs_%08X' % t['stamp']
        rows = []
        for f in u.fields:
            if f[:2] not in ('C_', 'E_') or f not in u.modern_reset:
                continue
            e = F.get(f)
            if not e or e['status'] == 'unused':
                continue
            v = _value_for_table(e, G.get(f))
            if v or e['value']:
                rows.append(_entry(f, v, _comment(e, G.get(f))))
        out = head + ['%s : array[0..%d] of TSysVarList = (' % (name, len(rows))] + rows + \
            ['  (Expr: LISTEND; Val: 0)', ');', '',
             '// add to ModernBuilds (and raise its upper bound by one):',
             '//  (Stamp: $%08X; Layout: @SysVarModernLayout; Addrs: @%s)' % (t['stamp'], name)]
        layout = dict(u.lists.get(u.modern[0][1], ())) if u.modern else {}
        diff = [(f, e) for f, e in F.items() if f[:2] in ('B_', 'F_') and e['status'] in USABLE
                and e['value'] != layout.get(f, 0)]
        if diff:
            out += ['', '// WARNING: this build does not fit %s. ApplyModernBuild applies the Addrs list of' % (
                u.modern[0][1] if u.modern else 'the modern layout'),
                '// each build after the layout, so move these rows into %s before' % name,
                '// LISTEND (and raise its upper bound by %d): they then override the layout for this build only.' % (
                    len(diff))]
            out += ['//' + _entry(f, e['value'], e['how'])[1:] for f, e in diff]
        return '\n'.join(out) + '\n'
    # fixed base, a version uoclidata.pas already has: check against its milestone instead
    idx, exact = u.milestone_index(t['version'])
    if exact:
        known = u.milestone_state(idx)
        state = dict(known)
        for f, e in F.items():
            if f[:2] in ('C_', 'E_') or (f[:2] in ('B_', 'F_') and e['status'] in USABLE):
                state[f] = _value_for_table(e, G.get(f)) if f[:2] in ('C_', 'E_') else e['value']
        # 0 in a B_ field means the getter's default: compare effective values
        eff = {'B_POS': 0x24}
        diff = [f for f in u.fields if (state.get(f, 0) or eff.get(f, 0)) != (known.get(f, 0) or eff.get(f, 0))]
        out = head + ['// %s is already in uoclidata.pas (milestone %d, %s).' % (t['version'], idx, u.milestones[idx][1])]
        if not diff:
            out.append('// The migration reproduces it exactly: all %d fields agree. Nothing to change.' % len(u.fields))
        else:
            out.append('// %d of %d fields differ from it -- check each before changing %s:' % (
                len(diff), len(u.fields), u.milestones[idx][1]))
            out += ['//' + _entry(f, state.get(f, 0), 'table has $%08X; %s' % (
                known.get(f, 0), _comment(F[f], G.get(f)) if f in F else ''))[1:] for f in diff]
        return '\n'.join(out) + '\n'
    # fixed base: a milestone delta against the floor milestone
    floor_state, idx = u.floor_state(t['version'])
    if floor_state is None:
        floor_state, idx = {f: 0 for f in u.fields}, len(u.milestones)
    state = dict(floor_state)
    for f, e in F.items():
        if f[:2] in ('C_', 'E_'):
            state[f] = _value_for_table(e, G.get(f))
        elif f[:2] in ('B_', 'F_') and e['status'] in USABLE:
            state[f] = e['value']
    norm = u.normalize(t['version'])
    name = 'SysVarMS_' + t['version'].replace('.', '_')
    rows = []
    for f in u.fields:
        if state.get(f, 0) != floor_state.get(f, 0) or (f in F and (F[f]['status'] == 'candidate' or f in G)):
            rows.append(_entry(f, state.get(f, 0), _comment(F[f], G.get(f)) if f in F else ''))
    out = head + ['// delta against milestone %s (%s), the state an unknown %s gets today' % (
        idx, u.milestones[idx][0] if idx < len(u.milestones) else 'none', t['version'])]
    out += ['%s : array[0..%d] of TSysVarList = (' % (name, len(rows))] + rows + ['  (Expr: LISTEND; Val: 0)', ');', '']
    out += ['// Milestones (newest first): insert before entry %d, then add 1 to every VersionIndex' % idx,
            '// Milestone number >= %d:' % idx,
            "//  (NormVer: '%s'; List: @%s)," % (norm, name),
            '// VersionIndex:',
            "//  (Cli: '%s'; Milestone: %d)," % (t['version'], idx)]
    # the next newer milestone must not inherit what this one changed
    if idx > 0:
        newer = idx - 1
        newer_state = u.milestone_state(newer)
        fix = [f for f in u.fields if state.get(f, 0) != floor_state.get(f, 0)
               and newer_state.get(f, 0) == floor_state.get(f, 0)
               and f not in dict(u.lists.get(u.milestones[newer][1], ()))]
        if fix:
            out += ['', '// and append to %s (milestone %s) so that it keeps its own values:' % (
                u.milestones[newer][1], u.milestones[newer][0])]
            out += [_entry(f, newer_state.get(f, 0)) for f in fix]
    return '\n'.join(out) + '\n'
