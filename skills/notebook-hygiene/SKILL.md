---
name: notebook-hygiene
description: Use when working with Jupyter notebooks (.ipynb) — strip output before commit, pin kernels, ensure reproducibility, prevent JSON bloat in git, and integrate with mlflow experiments. Trigger on "notebook", ".ipynb", "jupyter", "strip output", "kernel".
---

# notebook-hygiene

Jupyter workflow yang bersih: notebook kecil di git, reproducible, siap production.

## Output stripping (WAJIB sebelum commit)

Notebook dengan output = JSON bloat (ratusan KB per cell untuk plot). Solusi: `nbstripout`.

### Setup satu kali per repo

```bash
# install hook di repo target
nbstripout --install

# cek status
cat .git/hooks/pre-commit | grep -q nbstripout && echo "hook aktif"
```

Hook `pre-commit` otomatis strip semua cell output dari `.ipynb` yang di-stage. **Wajib setup sebelum commit notebook pertama.**

### Manual strip (untuk file yang sudah terlanjur di-commit)

```bash
# strip output dari 1 file
nbstripout path/to/notebook.ipynb

# bulk strip semua notebook yang sudah ter-track
git ls-files '*.ipynb' | xargs -I{} nbstripout {}
git add '*.ipynb'
git commit -m "chore: strip notebook output"
```

### Verifikasi

```bash
# notebook harusnya kecil setelah strip
git diff --stat | grep ipynb
# idealnya: 0 changed lines untuk output
```

## Kernel pinning

Setiap notebook **wajib** declare kernel di metadata agar reproducibility terjaga.

```bash
# install kernel pinned ke env tertentu
python3 -m ipykernel install --user --name=myproject-py312 --display-name "Python 3.12 (myproject)"

# di notebook, pilih kernel ini via JupyterLab UI atau:
jupyter nbconvert --to notebook --execute \
    --ExecutePreprocessor.kernel_name=myproject-py312 \
    notebook.ipynb
```

Cek kernel di notebook:

```python
# cell pertama wajib: print kernel info
import sys, ipykernel
print(f"Python: {sys.version}")
print(f"Kernel: {ipykernel.__version__}")
print(f"Executable: {sys.executable}")
```

## Reproducibility rules (di setiap notebook)

1. **Random seed** — wajib di awal eksperimen:
   ```python
   import numpy as np
   import random
   RANDOM_SEED = 42
   np.random.seed(RANDOM_SEED)
   random.seed(RANDOM_SEED)
   # untuk torch: torch.manual_seed(RANDOM_SEED); torch.cuda.manual_seed_all(RANDOM_SEED)
   ```

2. **Environment lock** — `requirements.txt` atau `uv.lock` / `poetry.lock`. Commit lock file, bukan hanya constraints.

3. **Data versioning** — kalau pakai dataset besar, hash + catat di cell pertama:
   ```python
   DATASET_HASH = "sha256:abc123..."  # dari `sha256sum data.csv`
   ```

4. **No hardcoded paths** — pakai `pathlib.Path` relatif terhadap repo root, atau env var.

## Struktur notebook yang baik

```
# Header cell (markdown)
- Title
- Author (Fqih)
- Date
- Purpose
- Random seed

# Setup cell (code)
- imports
- seed
- config constants

# Data loading cell(s)
- reproducible loader
- hash check

# Analysis cells
- 1 cell = 1 logical step
- nama variabel deskriptif

# Conclusion cell (markdown)
- findings
- next steps
```

## MCP integration (jupyter-mcp-server)

Kalau MCP `jupyter` aktif, pakai untuk eksekusi cell-by-cell:

1. Start jupyter lab lokal:
   ```bash
   jupyter lab --port 8888 --IdentityProvider.token=claude-code-mcp --ip 127.0.0.1
   ```

2. CC punya akses ke tool MCP untuk: `execute_cell`, `read_cell`, `insert_cell`, `restart_notebook`, `list_kernels`, multimodal output (plot/gambar inline).

3. **Selalu restart kernel** sebelum eksekusi panjang untuk pastikan state bersih:
   - `restart_notebook` → `execute_cell` cell by cell → cek output di setiap step.

4. **JANGAN commit** notebook dengan cell output besar (gambar base64, DataFrame preview panjang). Strip dulu.

## Pre-commit checklist untuk notebook

Sebelum `git commit`:

- [ ] `nbstripout` output sudah jalan (cek `git diff --stat`)
- [ ] Kernel declared dan reproducible
- [ ] Random seed di cell pertama
- [ ] Tidak ada path absolut (`/home/fqih/...`)
- [ ] Tidak ada API key/secret hardcoded
- [ ] requirements.txt updated

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| Notebook 5MB+ di git | `nbstripout` retroactive + `.gitattributes` filter |
| Kernel "dead" setelah pindah env | `python3 -m ipykernel install --user --name=...` ulang |
| Output beda tiap run (no seed) | Tambah `np.random.seed`, `random.seed`, torch seed |
| Plot hilang di GitHub preview | Pakai `%matplotlib inline` (default), simpan figure ke file jika perlu |
| Cell error lalu stuck state | Restart kernel + run all dari awal |

## Invokation

Auto-trigger saat:
- Edit/tulis file `.ipynb`
- User bilang "notebook", "jupyter", "strip output"
- Pre-commit hook jalan dan ada `.ipynb` di staged

Manual trigger: `/notebook-strip` atau panggil skill ini langsung.
