---
description: Strip notebook output via nbstripout sebelum commit — keep diff clean, avoid binary blob di git.
---

# /notebook-strip

Strip output dari Jupyter notebook agar:
1. Diff di git tetap readable (no base64 image blobs)
2. Repo size tetap kecil
3. Tidak commit output yang mungkin contain data sensitif

## Mode 1: Setup repo (one-time per repo)

Install nbstripout filter untuk repo saat ini:

```bash
# Install kalau belum
pip install nbstripout

# Register git filter (auto-strip on commit)
nbstripout --install

# Verify
cat .gitattributes  # harus ada entry: *.ipynb filter=stripoutput
```

## Mode 2: Strip single notebook

```bash
nbstripout path/to/notebook.ipynb
git add path/to/notebook.ipynb
```

## Mode 3: Strip all notebooks in repo

```bash
# Find semua ipynb, strip output
find . -name "*.ipynb" -not -path "./.venv/*" -not -path "./node_modules/*" | \
    xargs -I{} nbstripout {}

# Stage semua
git add "*.ipynb"
```

## Mode 4: Strip + untrack existing large outputs

Kalau notebook sudah pernah ke-commit dengan output besar:

```bash
# Strip semua
find . -name "*.ipynb" -exec nbstripout {} \;

# Filter-branch untuk rewrite history (BERBAHAYA — hanya untuk repo pribadi)
# Untuk shared repo, jangan rewrite history — biarkan output lama, cuma prevent ke depan
git add "*.ipynb"
git commit -m "chore: strip notebook outputs"
```

## What gets stripped

✅ Stripped:
- Cell outputs (text, HTML, images, errors)
- Execution counts
- Metadata outputs

❌ Preserved:
- Source code (cells)
- Markdown
- Cell metadata (tags, collapsed state)
- Kernel info

## nbstripout vs alternatives

| Tool | Notes |
|---|---|
| **nbstripout** | Default, simple, configurable |
| **jupyter-nbstripout** | Same, distributed via pip |
| **JupyText** | Convert to .py + .ipynb pair, no output to commit |
| **ReviewNB** | SaaS untuk notebook diff review |

**Default**: nbstripout via `.gitattributes`.

## Kernel pinning

Strip output tapi keep kernel info untuk reproducibility:

```bash
# Verify kernel di notebook match env
jupyter kernelspec list
```

Pastikan kernel yang di-reference notebook exist. Lihat skill `notebook-hygiene` untuk full reproducibility workflow.

## Pre-commit integration

Tambah ke `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/kynan/nbstripout
    rev: 0.8.1
    hooks:
      - id: nstripout
```

## Common pitfalls

| Issue | Fix |
|---|---|
| Filter not running | Check `.gitattributes` ada entry `*.ipynb filter=stripoutput` |
| Output masih ke-commit | Re-install filter: `nbstripout --install --force` |
| Notebook corrupt setelah strip | Restore dari git: `git checkout HEAD -- notebook.ipynb` |
| Jupyter can't open stripped notebook | Strip only remove outputs, not structure — should still open |
| Kernel missing | `pip install ipykernel` + `python -m ipykernel install --user --name=name` |

## Verify strip worked

```bash
# File size check
ls -lh notebook.ipynb  # should be much smaller than original

# Diff check
git diff --stat notebook.ipynb  # should show only code, not output blob
```
