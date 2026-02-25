# Agent Guide

## Definition of Done

- Source and tests are updated together.
- `./tool/verify.sh` passes locally.
- `CHANGELOG.md` is updated for user-visible changes.
- Package remains publishable via dry-run.

## Notes

- Keep public API under `lib/` and implementation details under `lib/src/`.
- Prefer deterministic, side-effect-free utilities for easier testing.
