#!/usr/bin/env python3
"""EUOMigrate -- derive EasyUO Reforged's client tables for a UO client build it does not know yet.

  euomigrate.py fingerprint <client.exe>     add a KNOWN build (one uoclidata.pas has an exact table
                                             for) to the knowledge base, so later builds can be
                                             migrated from it without the exe; with --candidates,
                                             a migrated build (its usable values only)
  euomigrate.py migrate <client.exe>         derive C_*/E_* for an unknown build from every build in
                                             the knowledge base -> out/<id>/ (candidates.json,
                                             report.md, uoclidata.pas snippet)
  euomigrate.py verify <candidates.json>     check the values in the running client (read-only)
                                             and mark them verified / rejected
  euomigrate.py probe <candidates.json>      find object / gump / status layouts (B_*) in the running
                                             client (read-only)
  euomigrate.py emit <candidates.json>       regenerate report + snippet (e.g. after editing statuses)
  euomigrate.py selftest <exe> [<exe> ...]   leave-one-out: migrate each known build from the
                                             others and compare with its verified table
  euomigrate.py kb                           list the knowledge base

Nothing here writes to the repository's sources: the Pascal output is a snippet to review and paste.
"""
import argparse
import collections
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from euomig import kb as KB                      # noqa: E402
from euomig import emit as EM                    # noqa: E402
from euomig import fields as FD                  # noqa: E402
from euomig import siggen as SG                  # noqa: E402
from euomig import conv as CV                    # noqa: E402
from euomig.consensus import migrate             # noqa: E402
from euomig.tables import UoCliData              # noqa: E402
from euomig.target import Target                 # noqa: E402

OUT = os.path.join(HERE, 'out')


def log(*a):
    print(*a, flush=True)


def base_for(u, t, leave_out=False):
    """(state, label, newer_state): what uoclidata.pas gives this build today -- its B_/F_ values
    are inherited from it -- and, for a fixed-base build, the next newer milestone's state.
    leave_out: the build IS in uoclidata.pas (selftest) -- use only what an unknown build of that
    version would have had, i.e. the next OLDER milestone, and nothing newer (it would contain the
    answer)."""
    if t.relocatable and u.modern:
        return (u.resolve(t.version, stamp=None, relocatable=True),
                'the modern layout (%s)' % u.modern[0][1], None)
    idx, exact = u.milestone_index(t.version)
    if exact and leave_out:
        idx += 1
    if idx < 0 or idx >= len(u.milestones):
        return {f: 0 for f in u.fields}, 'nothing (older than every milestone)', None
    newer = u.milestone_state(idx - 1) if idx > 0 and not leave_out else None
    return u.milestone_state(idx), 'milestone %s (%s)' % (u.milestones[idx][0], u.milestones[idx][1]), newer


def build_sigs(t, values, descs, log=None):
    return SG.generate(t.code, {f: v for f, v in values.items() if f[:2] in ('C_', 'E_') and v},
                       {f: d['kind'] for f, d in descs.items()},
                       {f: d['derived']['of'] for f, d in descs.items() if 'derived' in d}, log=log)


def make_entry(u, t, table, source):
    descs = FD.build(t.code, t.db, table, u.fields)
    return KB.make(t.code, t.db, table, descs, source, sigs=build_sigs(t, table, descs))


# ---- commands -----------------------------------------------------------------------------------
def cmd_fingerprint(a):
    u = UoCliData()
    t = Target(a.exe, log=log)
    if a.candidates:
        # a migrated build: only its usable values (accepted / verified / derived / probed)
        c = EM.load_json(a.candidates)
        if c['target']['sha256'] != t.pe.sha256():
            raise SystemExit('%s was made for another exe' % a.candidates)
        table = {f: (e['value'] or 0) if (f[:2] in ('B_', 'F_') or e['status'] in EM.USABLE) else 0
                 for f, e in c['fields'].items()}
        nver = sum(1 for e in c['fields'].values() if e['status'] == 'verified')
        source = 'migrated by EUOMigrate (%d values verified live)' % nver
    else:
        table = u.exact_table(t.version, t.stamp, t.relocatable)
        if table is None:
            raise SystemExit('%s: uoclidata.pas has no verified table for this exact build -- migrate '
                             'it, verify it, then either add it to uoclidata.pas or fingerprint it '
                             'with --candidates out/<id>/candidates.json.' % t.label())
        source = 'uoclidata.pas'
    # values uoclidata.pas cannot carry for this exact build (found by its runtime scan only, e.g. the
    # buff bar's C_CLILOC / C_BUFFTIMERS on a fixed-base client) but that were checked in the live client
    for item in a.set or ():
        f, _, v = item.partition('=')
        if f not in u.fields or not v:
            raise SystemExit('--set FIELD=VALUE with a field of uoclidata.pas, got %r' % item)
        table[f] = int(v, 0)
        source += ' + %s from the live client' % f
    d = make_entry(u, t, table, source)
    path = KB.save(d, a.kb)
    log('wrote %s (%.0f KB)' % (path, os.path.getsize(path) / 1024))


def cmd_kb(a):
    for e in KB.load_all(a.kb):
        n = sum(1 for f, d in e.fields.items() if d['kind'] not in ('absent', 'value'))
        log('%-24s %s  %d functions, %d located fields' % (e.id, e.label(), len(e.funcdb.start), n))


def cmd_migrate(a):
    u = UoCliData()
    t = Target(a.exe, log=log)
    refs = KB.load_all(a.kb)
    if a.ref:
        refs = [r for r in refs if r.id in a.ref]
    if not refs:
        raise SystemExit('the knowledge base in %s is empty: fingerprint a known build first' % a.kb)
    known = u.exact_table(t.version, t.stamp, t.relocatable)
    if known is not None:
        log('note: uoclidata.pas already has a table for %s -- migrating as if it had not' % t.id)
    base, label, newer = base_for(u, t, leave_out=known is not None)
    t0 = time.time()
    mig = migrate(t, refs, u.fields, base, label, newer, log=log)
    c = EM.candidates(mig)
    c['derived'] = derived_of(mig)
    usable = {f: e['value'] for f, e in c['fields'].items() if e['status'] in EM.USABLE and e['value']}
    EM.apply_derived(c, CV.derive(t.code, usable), base)
    rel = {}
    for f, (v, how) in mig.relative_layout().items():
        default = FD.RELATIVE[f][2]
        if not base.get(f) and v == default:
            v = 0                     # the getter's default already gives this distance
        rel[f] = (v, how)
    EM.apply_derived(c, rel, base)
    out = os.path.join(a.out, t.id)
    EM.save_json(c, os.path.join(out, 'candidates.json'))
    write_outputs(c, u, out, t, c['derived'])
    tally = collections.Counter(e['status'] for f, e in c['fields'].items() if f[:2] in ('C_', 'E_'))
    log('done in %.0fs: %s' % (time.time() - t0, ', '.join('%s %d' % kv for kv in sorted(tally.items()))))
    log('-> %s' % out)


def write_outputs(c, u, out, target=None, derived=None):
    with open(os.path.join(out, 'report.md'), 'w', encoding='utf-8') as f:
        f.write(EM.report_md(c))
    with open(os.path.join(out, 'uoclidata-snippet.pas'), 'w', encoding='utf-8') as f:
        f.write(EM.pascal(c, u))
    if target is None:
        return
    # signatures for the usable values, so the next build of this compiler needs no tool at all
    usable = {f: e['value'] for f, e in c['fields'].items()
              if f[:2] in ('C_', 'E_') and e['status'] in EM.USABLE and e['value']}
    pairs = SG.generate(target.code, usable, {}, derived or {})
    head = ['EUO Updtr scan strings generated by EUOMigrate %s for %s' % (c['tool'], target.label()),
            'Only verified/accepted values; each line is unique in this build\'s code and resolves to',
            'the value in candidates.json. Format: pattern ; joker ; offset ; X|C|CB ; adjust ; {name}']
    with open(os.path.join(out, 'EUO Updtr Strings %s.txt' % target.id), 'w', encoding='utf-8') as f:
        f.write(SG.strings_file(pairs, head))
    with open(os.path.join(out, 'scanner-table.pas'), 'w', encoding='utf-8') as f:
        f.write('// TScannerEntry rows for %s (Mode 1 = X, 2 = CB, 3 = C)\n' % target.id)
        f.write(SG.pascal_table(pairs, 'ScannerTable_%s' % target.id.replace('.', '_').replace('-', '_')))
    log('%d signatures for %d fields' % (len(pairs), len({f for f, s in pairs})))


def derived_of(mig):
    return {f: d['derived']['of'] for f, d in mig.primary.ref.fields.items() if 'derived' in d}


def cmd_emit(a):
    u = UoCliData()
    c = EM.load_json(a.candidates)
    out = a.out or os.path.dirname(os.path.abspath(a.candidates))
    t = None
    if os.path.exists(c['target']['path']):
        t = Target(c['target']['path'], log=log)
        if t.pe.sha256() != c['target']['sha256']:
            log('%s changed since the migration: no signatures' % c['target']['path'])
            t = None
    write_outputs(c, u, out, t, c.get('derived'))
    log('-> %s' % out)


def cmd_verify(a):
    """check every C_/E_ value (and its runners-up) in the running client; read-only"""
    from euomig.live import Process
    from euomig import oracles as OR
    u = UoCliData()
    c = EM.load_json(a.candidates)
    t = Target(c['target']['path'], log=log)
    if t.pe.sha256() != c['target']['sha256']:
        raise SystemExit('%s is not the exe this migration was made for' % t.path)
    p = Process.attach(t, a.pid)
    log('attached to pid %d, loaded at %08X (delta %08X)' % (p.pid, p.base, p.delta))
    values = {f: e['value'] for f, e in c['fields'].items() if e['value'] is not None}
    ctx = OR.Ctx(p, t, values)
    # a data global belongs to one field: a runner-up another C_ field already holds is not one
    # (with every skill at 100 the real, base and cap arrays even look alike)
    owner = {e['value']: f for f, e in c['fields'].items()
             if f[:2] == 'C_' and e['status'] in EM.USABLE and e['value']}
    tally = collections.Counter()
    for f, e in c['fields'].items():
        if f[:2] not in ('C_', 'E_') or e['status'] in ('unused', 'n/a') or e['value'] is None:
            continue
        verdict, note = OR.check(ctx, f, e['value'])
        e['checks'] = ['%s: %08X %s' % (verdict, e['value'], note)]
        if verdict == 'pass':
            e['status'] = 'verified'
        elif verdict == 'fail':
            # the first runner-up that does not fail replaces it (verified if it passes)
            for v, s, h in e['alts']:
                if f[:2] == 'C_' and owner.get(v, f) != f:
                    e['checks'].append('skip: %08X is %s' % (v, owner[v]))
                    continue
                vv, nn = OR.check(ctx, f, v)
                e['checks'].append('%s: %08X %s' % (vv, v, nn))
                if vv != 'fail':
                    e['alts'] = [[e['value'], e['conf'], e['how']]] + [x for x in e['alts'] if x[0] != v]
                    e.update(value=v, conf=s, how=h + ' (runner-up, chosen by verify)',
                             status='verified' if vv == 'pass' else 'candidate')
                    break
            else:
                e['status'] = 'rejected'
        tally[e['status']] += 1
        log('%-9s %-16s %s' % (e['status'], f, e['checks'][-1] if e['status'] == 'verified' else e['checks'][0]))
    EM.save_json(c, a.candidates)
    out = os.path.dirname(os.path.abspath(a.candidates))
    write_outputs(c, u, out, t, c.get('derived'))
    log(', '.join('%s %d' % kv for kv in sorted(tally.items())) + ' -> ' + out)


def cmd_probe(a):
    """find object / gump / status layouts in the running client; read-only"""
    from euomig.live import Process
    from euomig import oracles as OR, probe as PR
    u = UoCliData()
    c = EM.load_json(a.candidates)
    t = Target(c['target']['path'], log=log)
    if t.pe.sha256() != c['target']['sha256']:
        raise SystemExit('%s is not the exe this migration was made for' % t.path)
    p = Process.attach(t, a.pid)
    values = {f: e['value'] for f, e in c['fields'].items() if e['value'] is not None}
    for need in ('C_CHARPTR', 'C_CONTPOS'):
        if c['fields'][need]['status'] not in EM.USABLE:
            log('note: %s is %s -- probes that start from it may find nothing' % (need, c['fields'][need]['status']))
    ctx = OR.Ctx(p, t, values)
    log('window: %r' % ctx.title)
    found, notes, _ = PR.run(ctx)
    for f, (v, how) in found.items():
        e = c['fields'][f]
        if e['value'] == v or (f == 'B_POS' and not e['value'] and v == 0x24):
            e['status'] = 'verified'
            e['checks'] = e.get('checks', []) + ['probe: %s' % how]
            log('verified  %-12s $%X  %s' % (f, v, how))
        else:
            old = e['value']
            e.update(value=v, conf=1.0, status='probed', how='probe: %s (was $%X)' % (how, old or 0))
            log('CHANGED   %-12s $%X (was $%X)  %s' % (f, v, old or 0, how))
    for n in notes:
        log('note: ' + n)
    EM.save_json(c, a.candidates)
    write_outputs(c, u, os.path.dirname(os.path.abspath(a.candidates)), t, c.get('derived'))


def cmd_selftest(a):
    """leave-one-out over the given exes that uoclidata.pas knows exactly"""
    u = UoCliData()
    targets = [Target(p, log=log) for p in a.exes]
    known = []
    for t in targets:
        table = u.exact_table(t.version, t.stamp, t.relocatable)
        if table is None:
            log('%s: no verified table, skipped' % t.label())
            continue
        known.append((t, table, KB.KBEntry(make_entry(u, t, table, 'uoclidata.pas'))))
    if len(known) < 2:
        raise SystemExit('selftest needs at least two builds with verified tables')
    grand = collections.Counter()
    for t, table, _ in known:
        refs = [e for (t2, _, e) in known if t2 is not t]
        base, label, newer = base_for(u, t, leave_out=True)
        mig = migrate(t, refs, u.fields, base, label, newer, log=log)
        log('== %s from %s' % (t.label(), ', '.join(r.ref.id for r in mig.runs)))
        tally = collections.Counter()
        for f in u.fields:
            if f[:2] not in ('C_', 'E_') or not table.get(f):
                continue
            r = mig.results[f]
            truth = table[f]
            alts = [v for v, s, h in r.alts]
            if r.value == truth:
                mark = 'right' if r.conf >= EM.MIN_CONF else 'right-unsure'
            elif r.value is None or r.value == 0:
                mark = 'missing'
            elif truth in alts:
                mark = 'runner-up'
            else:
                mark = 'WRONG' if r.conf >= EM.MIN_CONF else 'wrong-unsure'
            tally[mark] += 1
            if mark != 'right' or a.verbose:
                log('  %-12s %-16s truth %08X got %s conf %.2f  %s' % (
                    mark, f, truth, ('%08X' % r.value) if r.value else '-', r.conf, r.how[:120]))
        log('  ' + ', '.join('%s %d' % kv for kv in sorted(tally.items())))
        grand.update(tally)
    log('total: ' + ', '.join('%s %d' % kv for kv in sorted(grand.items())))


def main(argv=None):
    p = argparse.ArgumentParser(prog='euomigrate', description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--kb', default=KB.KB_DIR, help='knowledge-base directory (default: %(default)s)')
    sub = p.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('fingerprint', help='add a known build to the knowledge base')
    s.add_argument('exe')
    s.add_argument('--candidates', help='take the table from a (verified) migration instead of uoclidata.pas')
    s.add_argument('--set', action='append', metavar='FIELD=VALUE',
                   help='add a value checked in the live client that uoclidata.pas does not hold (repeatable)')
    s.set_defaults(fn=cmd_fingerprint)
    s = sub.add_parser('migrate', help='derive the tables of an unknown build')
    s.add_argument('exe')
    s.add_argument('--out', default=OUT)
    s.add_argument('--ref', action='append', help='only this knowledge-base id (repeatable)')
    s.set_defaults(fn=cmd_migrate)
    s = sub.add_parser('emit', help='regenerate report and Pascal from a candidates file')
    s.add_argument('candidates')
    s.add_argument('--out')
    s.set_defaults(fn=cmd_emit)
    s = sub.add_parser('verify', help='check a migration against the running client (read-only)')
    s.add_argument('candidates')
    s.add_argument('--pid', type=int)
    s.set_defaults(fn=cmd_verify)
    s = sub.add_parser('probe', help='find object / gump / status layouts in the running client (read-only)')
    s.add_argument('candidates')
    s.add_argument('--pid', type=int)
    s.set_defaults(fn=cmd_probe)
    s = sub.add_parser('selftest', help='leave-one-out over builds with verified tables')
    s.add_argument('exes', nargs='+')
    s.add_argument('-v', '--verbose', action='store_true')
    s.set_defaults(fn=cmd_selftest)
    s = sub.add_parser('kb', help='list the knowledge base')
    s.set_defaults(fn=cmd_kb)
    a = p.parse_args(argv)
    a.fn(a)


if __name__ == '__main__':
    main()
