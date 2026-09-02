# Security Policy

## What this software does

EasyUO Reforged automates the Ultima Online client by reading and writing that
client process's memory and by patching small code hooks into it. Those are the
same techniques used by debuggers and game trainers. As a result:

- Antivirus / EDR products may flag the executable heuristically. This is
  expected for this class of tool and does not by itself indicate the binary is
  malicious. Verify official release binaries against the checksums published
  with each GitHub Release, and build from source if in doubt.
- Running scripts from untrusted sources is risky. A script controls your game
  client and can invoke OS-level actions (file access, `Execute`, key/mouse
  synthesis). Only run scripts you understand or trust.

## Supported versions

This is a rolling work-in-progress project. Only the latest `main` / most recent
release receives fixes.

## Reporting a vulnerability

If you find a vulnerability in EasyUO Reforged itself — for example a script
able to escape its intended sandboxing, a crash triggerable by malicious input
to `uo.dll`, or a memory-safety issue in the parsing code — please report it
privately:

- Use **GitHub → Security → Report a vulnerability** (private advisory), or
- open a normal issue that only says "security report, please make contact"
  without details, and wait to be contacted.

Please do **not** post working exploit steps in a public issue before a fix is
available. Describe the class of problem and the impact; hold the reproduction
detail for private follow-up.

Expect an initial response within about two weeks — this is a volunteer project,
not a staffed one.
