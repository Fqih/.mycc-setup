# Fqih's Codex workspace instructions

This repository is a personal, version-controlled setup for Codex. Use the
repository's `.agents/skills` catalog for repeatable workflows and treat the
existing `rules/` files as the source of truth for project conventions.

## Working style

- Read the relevant skill before applying a specialized workflow.
- Inspect the repository and existing changes before editing.
- Prefer small, reversible changes and preserve unrelated user work.
- Explain assumptions, validation, and any remaining risks in the final reply.
- Use plain, direct language; avoid unnecessary recaps.

## Engineering conventions

- Python: use `ruff check .` and `ruff format --check .` when applicable.
- JavaScript/TypeScript: use the repository's configured lint, format, type,
  and test commands.
- Notebooks: strip generated outputs before committing when `nbstripout` is
  available.
- Security-sensitive changes: inspect `rules/security.md` and use the
  `security-review` skill when appropriate.
- Keep secrets in environment files or a secret manager. Commit templates,
  never credentials.

## Git workflow

- Identity: `Fqih <mhmdfkih21@gmail.com>`.
- Use conventional, imperative commit subjects of at most 72 characters.
- Never add a `Co-Authored-By` trailer for Claude or Anthropic.
- Never add a generated-by footer.
- Before pushing, review the complete diff and run the applicable secret scan.

## Role routing

The legacy `agents/` directory contains reusable role prompts migrated from
Claude Code. Use the matching Codex skill or role guidance when a task needs
architecture, planning, implementation, review, testing, documentation, or
security expertise. The legacy `commands/` directory is a reference catalog;
Codex equivalents are documented in `codex/command-mapping.md`.
