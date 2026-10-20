"""EUOMigrate: derive the uoclidata.pas tables (C_* / E_* addresses, F_* flags, B_* layouts) for a
UO client build that EasyUO Reforged does not know yet.

Modules:
  pe        PE loader (sections, imports, relocations, version resource, RTTI)
  disasm    capstone sweep, function boundaries, operand classification (cached per exe)
  features  per-function fingerprints, global-access lists, call graph
  tables    reads uo\\uoclidata.pas (milestones, ModernBuilds) and the golden fixture
  kb        knowledge-base files (one fingerprint set per known build)
  match     function matching, propagation, global / site / displacement voting
  sigs      EUOUpdtr-style masked signatures
  conv      calling-convention detection (F_* flags)
  live      process access (memory, keys) for verify / probe
  oracles   plausibility checks for verify
  probe     layout probers
  emit      Pascal / strings / report output
"""

TOOL_VERSION = '1'
