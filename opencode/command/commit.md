---
description: Create a git commit (single-author, no Claude attribution per CLAUDE.md)
---

## Your task

Create a single git commit for the current changes.

## Steps (gunakan bash tool, bukan substitusi)

1. `git status --short` — lihat perubahan.
2. `git diff HEAD` — review apa yang mau di-stage.
3. `git branch --show-current` — tahu branch aktif.
4. `git log --oneline -8` — ikuti style commit terakhir.

## Identity verification (WAJIB)

Sebelum commit, jalankan:
```
git config user.name   # HARUS: Fqih
git config user.email  # HARUS: mhmdfkih21@gmail.com
```
Kalau salah, stop. Fix: `git config --global user.name Fqih && git config --global user.email mhmdfkih21@gmail.com`, lalu retry.

## Rules (per CLAUDE.md)

- Single-author only. NO `Co-Authored-By:` trailer of any kind.
- NO `🤖 Generated with [Claude Code]` tagline.
- Conventional commit: `<type>: <subject>` — feat, fix, refactor, docs, test, chore, perf, ci.
- Subject max 72 chars, imperative mood ("add" not "added").

## Setelah berkas siap

`git add <files>` lalu `git commit -m "<type>: <subject>"`. Pastikan hook pre-commit lolos (identity, no co-author, no secret, ruff). Jangan nambah konteks lain.
