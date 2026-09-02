---
description: Commit, push, and open a PR (single-author, no Claude attribution)
---

## Your task

Commit, push, dan buka PR untuk perubahan saat ini.

## Steps (gunakan bash tool)

1. `git status --short` + `git diff HEAD` — review perubahan.
2. `git branch --show-current` — tahu branch aktif.
3. Kalau di `main`/`master`, buat feature branch: `git switch -c <type>/<short-desc>` (e.g. `feat/add-rag-pipeline`).
4. Verify identity: `git config user.name` / `git config user.email` — HARUS `Fqih` / `mhmdfkih21@gmail.com`. Kalau salah, stop & fix.
5. `git add -A` lalu `git commit -m "<type>: <subject>"` — conventional, NO `Co-Authored-By:`, NO `🤖 Generated with [Claude Code]`.
6. `git push -u origin <branch>` (hook pre-push nge-verify identity + secret scan + telegram notify).
7. `gh pr create --title "<type>: <subject>" --fill` lalu tambah body: summary (1–3 bullets) + test plan checklist, NO Claude attribution.

Single-author only per CLAUDE.md. Pre-commit + pre-push hooks meng-enforce. Jangan tambah konteks lain.
