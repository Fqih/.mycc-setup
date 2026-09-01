---
name: ds-workflow
description: Use when running data science experiments with mlflow — initialize tracking server, log params/metrics/artifacts, compare runs, register models, reproduce experiments. Trigger on "mlflow", "experiment", "tracking", "model registry", "/experiment-init".
---

# ds-workflow

MLflow-based experiment tracking. Setup sekali per project, pakai selamanya.

## Setup satu kali per project

### Backend store: SQLite (single-machine, paling ringan)

```bash
# tracking server di background
mlflow server \
    --backend-store-uri sqlite:///$(pwd)/mlflow.db \
    --default-artifact-root ./mlruns \
    --host 127.0.0.1 \
    --port 5000 &

# atau programmatic (lebih ringan, no server):
import mlflow
mlflow.set_tracking_uri(f"sqlite:///{Path.cwd()}/mlflow.db")
mlflow.set_registry_uri(f"sqlite:///{Path.cwd()}/mlflow.db")
```

### Backend store: PostgreSQL (production / multi-user)

```bash
# connection string format
mlflow server \
    --backend-store-uri postgresql://user:pass@host:5432/mlflow \
    --default-artifact-root s3://bucket/mlflow-artifacts \
    --host 0.0.0.0 \
    --port 5000
```

### Folder layout yang disarankan

```
project/
├── mlflow.db              # tracking metadata (gitignore)
├── mlruns/                # artifact root (gitignore)
├── experiments/
│   ├── exp-001-baseline/
│   │   ├── notebook.ipynb
│   │   └── params.yaml
│   └── exp-002-tuned/
├── requirements.txt
└── .gitignore             # include: mlflow.db, mlruns/
```

Tambah ke `.gitignore`:
```
mlflow.db
mlruns/
```

## Logging convention (WAJIB konsisten)

Setiap run **wajib** log:

```python
import mlflow
from pathlib import Path

mlflow.set_experiment("churn-prediction")  # grouped runs

with mlflow.start_run(run_name="exp-002-tuned"):
    # 1. Params (hyperparameters, config)
    mlflow.log_params({
        "model": "xgboost",
        "max_depth": 6,
        "learning_rate": 0.1,
        "n_estimators": 200,
        "random_seed": 42,
    })

    # 2. Tags (context)
    mlflow.set_tags({
        "author": "Fqih",
        "dataset_version": "v1.2",
        "purpose": "baseline for churn Q4",
    })

    # 3. Metrics (per epoch atau final)
    mlflow.log_metric("auc", 0.87, step=10)
    mlflow.log_metric("val_loss", 0.234, step=10)

    # atau batch
    mlflow.log_metrics({"precision": 0.81, "recall": 0.79, "f1": 0.80})

    # 4. Artifacts (figures, model, dataset hash)
    mlflow.log_artifact("confusion_matrix.png")
    mlflow.log_artifact("feature_importance.csv")

    # 5. Model (framework-specific)
    mlflow.sklearn.log_model(pipeline, "model")
    # atau mlflow.pytorch.log_model(net, "model")
    # atau mlflow.xgboost.log_model(model, "model")

    run_id = mlflow.active_run().info.run_id
    print(f"Run: {run_id}")
```

## Pola yang sering kepakai

### Hyperparameter sweep

```python
import mlflow
from sklearn.model_selection import ParameterGrid

params_grid = {
    "max_depth": [3, 6, 9],
    "learning_rate": [0.01, 0.1, 0.3],
}

for params in ParameterGrid(params_grid):
    with mlflow.start_run(run_name=f"sweep-{params['max_depth']}-{params['learning_rate']}"):
        mlflow.log_params(params)
        # ... train + eval
        mlflow.log_metric("val_auc", auc)
```

### Load model dari run sebelumnya

```python
# by run_id
model = mlflow.sklearn.load_model(f"runs:/{run_id}/model")

# by registered model name + version
model = mlflow.sklearn.load_model("models:/churn-classifier/1")
```

### Promote model ke registry

```python
from mlflow import MlflowClient

client = MlflowClient()
client.transition_model_version_stage(
    name="churn-classifier",
    version=1,
    stage="Production",  # Staging | Production | Archived
)
```

## Comparison & selection

```bash
# CLI: list runs sorted by metric
mlflow runs list --experiment-id 1 --order-by "metrics.auc DESC"

# atau via UI
open http://127.0.0.1:5000
```

Programmatic compare:

```python
import mlflow
import pandas as pd

experiment = mlflow.get_experiment_by_name("churn-prediction")
runs = mlflow.search_runs(
    experiment_ids=[experiment.experiment_id],
    order_by=["metrics.auc DESC"],
    max_results=10,
)
print(runs[["run_id", "params.max_depth", "metrics.auc", "metrics.f1"]])
```

## Notebook integration (jupyter-mcp-server)

Saat pakai MCP `jupyter`:

1. Selalu `mlflow.start_run` di cell, `mlflow.end_run` di akhir (atau pakai context manager).
2. Log metric **per step** untuk training loop, jangan cuma final.
3. Save plot dengan `plt.savefig()` → `mlflow.log_artifact()`.
4. **WAJIB** `mlflow.end_run()` sebelum exit notebook (kalau lupa, run jadi orphan).

```python
# cell terakhir notebook
if mlflow.active_run():
    mlflow.end_run()
```

## Reproducibility checklist

Sebelum `git commit`:

- [ ] `mlflow.db` di `.gitignore` (jangan commit)
- [ ] `mlruns/` di `.gitignore`
- [ ] Best run_id tercatat di NOTES.md atau commit message
- [ ] `requirements.txt` lock version
- [ ] Dataset hash tercatat (lihat `notebook-hygiene` skill)

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| Run ID berubah tiap restart | Paku `tracking_uri` di config file, jangan hardcode |
| Artifact tidak muncul di UI | Cek `--default-artifact-root` vs `log_artifact` path |
| Model registry "stage transition" deprecated di MLflow 3.x | Pakai `set_registered_model_alias` atau Model Registry v2 API |
| SQLite lock saat paralel | Migrasi ke PostgreSQL untuk multi-process |
| Logged metric None | Cek tipe data — `np.float32` kadang None, cast ke `float()` |

## Invokation

Auto-trigger saat:
- User bilang "experiment", "track", "mlflow", "log run"
- Edit file yang import mlflow
- User panggil `/experiment-init`

Manual: invoke skill ini atau jalankan command langsung.
