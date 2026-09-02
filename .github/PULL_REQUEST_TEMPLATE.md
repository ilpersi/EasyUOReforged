<!-- Keep PRs to one logical change. See CONTRIBUTING.md. -->

## What & why

<!-- What does this change do, and what problem does it solve? -->

## Behavior vs. original EasyUO

<!-- Does this preserve the original's behavior exactly? If it intentionally
     diverges, say where and why. If it fixes a regression the port introduced,
     say what the original does. -->

## How it was verified

- [ ] `pwsh ./tests/run_tests.ps1` passes
- [ ] Added/updated tests for the changed logic (or: not testable without a live client — explain below)
- [ ] Built with `lazbuild --build-mode=Release` (all three projects still link)
- [ ] Manually tested against a live client — client build(s): <!-- e.g. 7.0.117.0 -->

## Notes for reviewers

<!-- Anything tricky, follow-ups deliberately left out, etc. -->
