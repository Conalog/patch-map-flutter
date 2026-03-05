# Agent Guide

## Definition of Done

- Source and tests are updated together.

## Notes

- Keep public API under `lib/` and implementation details under `lib/src/`.
- Prefer deterministic, side-effect-free utilities for easier testing.

## Commit Rules

- Use Conventional Commits: `type(scope): summary` (e.g. `feat(image): add network sprite fallback`).
- Allowed commit `type`: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`.
- Keep commits focused; do not mix unrelated changes in one commit.
- Commit source and matching tests together in the same commit.
- Use imperative, present-tense summaries and keep the subject concise.
- Do not commit temporary/debug-only changes (`print`, ad-hoc logs, commented code).
- Before committing, run relevant tests for changed areas and ensure they pass.
