---
description: Init ML experiment directory — mlflow setup, seed, git baseline, data folder structure.
---

# /experiment-init

Setup directory baru untuk ML experiment dengan reproducibility baseline.

## Usage

```
/experiment-init <experiment-name>
```

Example:
```
/experiment-init churn-prediction-v2
```

## Step 1: Create directory structure

```bash
EXP_NAME="$1"
EXP_DIR="experiments/${EXP_NAME}"
DATE=$(date +%Y%m%d-%H%M%S)
EXP_PATH="${EXP_DIR}/${DATE}"

mkdir -p "${EXP_PATH}"/{data,notebooks,src,configs,artifacts}

# Symlink "latest" ke current
ln -sfn "${DATE}" "${EXP_DIR}/latest"

echo "Created: ${EXP_PATH}"
cd "${EXP_PATH}"
```

## Step 2: Initialize git baseline

```bash
# Init submodule atau git repo kalau needed
if [ ! -d ".git" ]; then
    echo "Warning: not a git repo. Run 'git init' di parent."
fi

# Initial empty commit (baseline)
git checkout -b "exp/${EXP_NAME}" 2>/dev/null || git checkout "exp/${EXP_NAME}"

git commit --allow-empty -m "exp: baseline ${EXP_NAME}"
```

## Step 3: Seed di notebook pertama (WAJIB)

Generate `notebooks/00_setup.ipynb` atau `src/seed.py`:

```python
# src/seed.py
import os
import random

SEED = 42

random.seed(SEED)

try:
    import numpy as np
    np.random.seed(SEED)
except ImportError:
    pass

try:
    import torch
    torch.manual_seed(SEED)
    torch.cuda.manual_seed_all(SEED)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
except ImportError:
    pass

os.environ["PYTHONHASHSEED"] = str(SEED)

print(f"Seed set: {SEED}")
```

Import di setiap notebook/entry-point:
```python
import sys; sys.path.insert(0, "..")
from seed import SEED  # atau import src.seed as _
```

## Step 4: MLflow tracking setup

```python
# src/mlflow_init.py
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")  # atau file://./mlruns
mlflow.set_experiment("churn-prediction")  # experiment name

def start_run(name: str):
    return mlflow.start_run(run_name=name)

# Log params WAJIB:
# - SEED
# - dataset version / hash
# - model architecture
# - hyperparameters
```

## Step 5: configs/experiment.yaml

```yaml
experiment:
  name: churn-prediction-v2
  date: 2026-09-02
  seed: 42
  owner: fqih

data:
  source: data/train.parquet
  hash: sha256:...           # compute & paste di sini
  train_split: 0.8
  val_split: 0.1
  test_split: 0.1

model:
  type: xgboost
  params:
    max_depth: 6
    n_estimators: 200
    learning_rate: 0.05

training:
  device: cuda:0
  batch_size: 64
  epochs: 10
  early_stopping: 5

metrics:
  primary: roc_auc
  secondary: [f1, precision, recall]

artifacts:
  output_dir: artifacts/
  log_to_mlflow: true
```

## Step 6: README eksperimen

Buat `README.md` di experiment dir:

```markdown
# Experiment: churn-prediction-v2

**Date**: 2026-09-02
**Goal**: Predict customer churn with improved features
**Status**: in-progress

## Hypothesis
Adding tenure × monthly_charge interaction feature improves AUC by 2%+.

## Setup
- Seed: 42
- Data: `data/train.parquet` (sha256: ...)
- Model: XGBoost
- Tracking: mlflow (experiment: churn-prediction)

## Results
| Run | AUC | F1 | Notes |
|-----|-----|----|----|
| baseline | 0.78 | 0.65 | features v1 |
| v2 | 0.82 | 0.70 | + interaction term |

## Reproduce
```bash
cd experiments/churn-prediction-v2/20260902-120000
pip install -r requirements.txt
python src/train.py --config configs/experiment.yaml
```
```

## Step 7: requirements.txt (pin exact versions)

```txt
numpy==2.1.3
pandas==2.2.3
scikit-learn==1.5.2
xgboost==2.1.1
mlflow==2.16.0
```

## Step 8: Initial commit

```bash
git add .
git commit -m "exp: init churn-prediction-v2

- seed baseline 42
- mlflow tracking wired
- data hash recorded
- experiment.yaml schema"
```

## Anti-patterns to avoid

❌ **No seed**: results unreproducible
❌ **No data hash**: data drift invisible
❌ **No mlflow run**: metrics hilang setelah notebook close
❌ **No git baseline**: tidak bisa diff progress
❌ **No requirements pinning**: 6 bulan lagi, deps beda, hasil beda
❌ **Notebook tanpa src/**: code tidak reusable, hard to productionize
❌ **No README**: 6 bulan lagi, tidak ingat hypothesis

## Checklist

- [ ] Directory structure created
- [ ] Git branch `exp/<name>` checked out
- [ ] Empty baseline commit
- [ ] Seed module (`src/seed.py`)
- [ ] MLflow init (`src/mlflow_init.py`)
- [ ] `configs/experiment.yaml`
- [ ] `requirements.txt` pinned
- [ ] `README.md` dengan hypothesis + results table
- [ ] Initial commit dengan conventional message
- [ ] mlflow server running (kalau belum: `mlflow server --port 5000`)

Lihat skill `ds-workflow` untuk full MLflow + experiment tracking.
