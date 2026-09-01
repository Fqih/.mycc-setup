---
name: scientific-python
description: Always-follow rules for Python data science / ML code — dtype explicitness, random seed mandatory, type hints with numpy.typing, vectorization over loops, vectorized I/O.
---

# Scientific Python Rules

Selalu apply saat tulis DS/ML code (numpy, pandas, sklearn, pytorch).

## Type hints (wajib)

Gunakan `numpy.typing` untuk array, bukan `Any` atau `np.ndarray` generic:

```python
from numpy.typing import NDArray
import numpy as np

def compute_mean(arr: NDArray[np.float64]) -> float:
    return float(arr.mean())
```

Untuk pandas, hint dengan index/dtype eksplisit:

```python
import pandas as pd

def filter_active(df: pd.DataFrame) -> pd.DataFrame:
    return df[df["status"] == "active"]
```

## dtype explicitness (wajib)

Jangan biarkan dtype di-infer kalau akan dipakai downstream:

```python
# ❌ BAD
data = np.array([1, 2, 3])  # int64 default

# ✅ GOOD
data = np.array([1, 2, 3], dtype=np.int32)
prices = prices.astype(np.float64)
```

Untuk pandas Series, pakai `pd.Series` constructor dengan dtype:

```python
scores: pd.Series = pd.Series([0.1, 0.5, 0.9], dtype=np.float32)
```

## Random seed (WAJIB untuk eksperimen)

Setiap eksperimen/reproducible script **wajib** seed di awal:

```python
import random
import numpy as np
import os

SEED = 42
random.seed(SEED)
np.random.seed(SEED)
os.environ["PYTHONHASHSEED"] = str(SEED)

# Untuk PyTorch (lihat skill local-ml-gpu untuk ROCm specifics):
# import torch
# torch.manual_seed(SEED)
# torch.cuda.manual_seed_all(SEED)  # atau rocm equivalent
```

Tambahkan `SEED` ke mlflow params (lihat `ds-workflow` skill).

## Vectorization (prefer over loops)

```python
# ❌ BAD — Python loop over array
result = []
for x in arr:
    result.append(x ** 2)

# ✅ GOOD — vectorized
result = arr ** 2
```

Pengecualian: loop yang unavoidable (mis. iterasi baris DataFrame dengan side effect ke DB) — tapi **harus ada komentar** kenapa loop diperlukan.

## I/O pattern (chunked untuk data besar)

```python
# ❌ BAD — load all at once
df = pd.read_csv("huge.csv")

# ✅ GOOD — chunked
chunks = pd.read_csv("huge.csv", chunksize=10_000)
for chunk in chunks:
    process(chunk)

# atau polars (lazy)
import polars as pl
df = pl.scan_csv("huge.csv").filter(...).collect()
```

## Notebook vs production code

| Aspect | Notebook (.ipynb) | Production (.py) |
|---|---|---|
| Seed | Wajib di cell pertama | Wajib di module-level constant |
| Type hints | Optional tapi encouraged | Wajib |
| Function length | Cells OK untuk eksplorasi | Function ≤ 50 lines, single responsibility |
| Logging | Print OK | `logging` module |
| Error handling | Print traceback OK | Catch + log + re-raise yang informatif |

## Forbidden patterns

- ❌ `from numpy import *` atau `from pandas import *`
- ❌ `np.ndarray` tanpa parameter di type hint
- ❌ `pd.read_csv(...)` tanpa `dtype=` atau converters untuk kolom yang diketahui tipenya
- ❌ `random.random()` tanpa `random.seed()` di awal file
- ❌ `assert` untuk validasi data (akan di-strip dengan `python -O`)
- ❌ Hardcoded paths (`/home/fqih/...`, `/Users/...`) — pakai `pathlib.Path` relatif atau env var
- ❌ Inline `print` untuk debug permanen — pakai `logging.debug`

## Performance checklist

Sebelum commit DS/ML code:

- [ ] Tidak ada loop yang bisa di-vectorize
- [ ] dtype eksplisit untuk array yang masuk model
- [ ] Tidak ada `df.iterrows()` (pakai `.itertuples()` atau vectorized)
- [ ] Large file pakai chunked read
- [ ] GPU dipakai kalau tersedia (lihat `local-ml-gpu` skill)
- [ ] mlflow log params + metrics (lihat `ds-workflow` skill)
