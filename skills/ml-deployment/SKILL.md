---
name: ml-deployment
description: Use when deploying ML models to production — model serving frameworks (FastAPI, BentoML, vLLM, Ollama, KServe, Triton), monitoring, autoscaling, ONNX/TensorRT optimization, GPU serving. Trigger on "deploy model", "model serving", "inference", "vllm", "triton", "fastapi model".
---

# ml-deployment

Production serving patterns untuk ML models — bukan prototype.

## Serving framework selection

| Framework | Best for | Pros | Cons |
|---|---|---|---|
| **FastAPI + Uvicorn** | Custom inference, small model | Simple, flexible | Manual scaling, no batching |
| **BentoML** | Mid-size, full pipeline | Pipeline versioning, multi-model | Learning curve |
| **vLLM** | LLM serving (HuggingFace) | PagedAttention, very fast | LLM-only |
| **Ollama** | Local/edge LLM | Zero-config, single binary | Single-machine |
| **Text Generation Inference** (HF) | LLM serving prod | Multi-GPU, quantization | LLM-only |
| **Triton Inference Server** | Multi-model, GPU | Batching, concurrent | Heavy setup |
| **KServe** | Kubernetes-native | Cloud-native | Needs K8s |
| **TorchServe** | PyTorch models | AWS-supported | PyTorch-only |
| **TensorFlow Serving** | TF models | Battle-tested | TF-only |
| **ONNX Runtime** | Cross-framework ONNX | Portable, fast | Need ONFX conversion |

**Pick by scenario:**
- **LLM, production, GPU available** → vLLM
- **LLM, local dev** → Ollama (sudah ada di skill `local-ml-gpu`)
- **Custom inference, sklearn/PyTorch** → BentoML atau FastAPI
- **K8s setup** → KServe
- **Multi-model GPU server** → Triton

## FastAPI pattern (most common)

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import numpy as np
from contextlib import asynccontextmanager

model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    model = joblib.load("model.pkl")
    yield
    # cleanup if needed

app = FastAPI(lifespan=lifespan)

class PredictRequest(BaseModel):
    features: list[float]

class PredictResponse(BaseModel):
    prediction: float
    confidence: float
    model_version: str

@app.post("/predict", response_model=PredictResponse)
async def predict(req: PredictRequest) -> PredictResponse:
    if model is None:
        raise HTTPException(503, "Model not loaded")

    arr = np.array([req.features])
    prob = model.predict_proba(arr)[0]
    pred = model.predict(arr)[0]

    return PredictResponse(
        prediction=float(pred),
        confidence=float(prob.max()),
        model_version="1.0.0",
    )

# Run: uvicorn app:app --host 0.0.0.0 --port 8000 --workers 4
```

## BentoML pattern

```python
import bentoml
from bentoml.io import JSON

# Save model
@bentoml.artifacts
class SklearnModelArtifact:
    def __init__(self, model):
        self.model = model

@bentoml.service(
    resources={"cpu": "2"},
    traffic={"timeout": 30},
)
class PredictService:
    model_ref = bentoml.models.BentoModel("classifier:latest")

    def predict(self, features: JSON) -> JSON:
        arr = np.array([features["data"]])
        prob = self.model_ref.predict_proba(arr)[0]
        return {"prediction": int(self.model_ref.predict(arr)[0]),
                "confidence": float(prob.max())}

# Build + serve
# bentoml build
# bentoml serve PredictService:latest
```

## vLLM pattern (LLM serving)

```python
from vllm import LLM, SamplingParams

llm = LLM(
    model="meta-llama/Llama-3.1-8B-Instruct",
    tensor_parallel_size=1,  # multi-GPU
    gpu_memory_utilization=0.85,
    quantization="awq",  # atau "gptq", "bitsandbytes"
)

# Single inference
sampling = SamplingParams(temperature=0.7, top_p=0.9, max_tokens=256)
outputs = llm.generate(["Halo, siapa kamu?"], sampling)

# OpenAI-compatible server
# vllm serve meta-llama/Llama-3.1-8B-Instruct --port 8000
```

## ONNX optimization

Convert PyTorch/sklearn ke ONNX untuk inference lebih cepat + portable:

```python
import torch
import onnx

# Export
model = MyModel()
model.load_state_dict(torch.load("model.pt"))
model.eval()

dummy = torch.randn(1, 3, 224, 224)
torch.onnx.export(
    model,
    dummy,
    "model.onnx",
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
    opset_version=17,
)

# Run via ONNX Runtime
import onnxruntime as ort
sess = ort.InferenceSession("model.onnx", providers=["CUDAExecutionProvider"])
outputs = sess.run(None, {"input": dummy.numpy()})
```

Untuk AMD ROCm: `providers=["ROCMExecutionProvider"]`.

## Batching untuk throughput

```python
# Dynamic batching — kumpulkan request dalam window, kirim sebagai batch
from collections import deque
import asyncio

batch_queue = deque(maxlen=32)

async def predict_batched(features_list):
    batch_queue.append(features_list)
    if len(batch_queue) >= 8 or timeout_reached():
        batch = list(batch_queue)
        batch_queue.clear()
        arr = np.array(batch)
        return model.predict(arr)
```

Triton + BentoML punya dynamic batching built-in.

## Quantization

| Method | Size reduction | Accuracy loss | Tool |
|---|---|---|---|
| FP32 → FP16 | 2x | Minimal | Native |
| FP32 → INT8 (PTQ) | 4x | ~1% | ONNX Runtime, TFLite |
| FP16 → INT4 (GPTQ) | 4x | ~2-3% | AutoGPTQ |
| FP16 → INT4 (AWQ) | 4x | ~1-2% | AutoAWQ |
| FP16 → INT4 (bitsandbytes) | 4x | ~2% | bitsandbytes |

Untuk LLM: AWQ atau GPTQ untuk quality terbaik.

## Monitoring

Track per-request:
- Latency (p50, p95, p99)
- Throughput (req/s)
- Error rate
- Input distribution drift
- Output confidence drift
- GPU util + VRAM

```python
from prometheus_client import Counter, Histogram

REQUEST_COUNT = Counter("ml_requests_total", "Total predict requests", ["model", "status"])
LATENCY = Histogram("ml_request_duration_seconds", "Request latency", ["model"])

@app.post("/predict")
async def predict(req: PredictRequest):
    with LATENCY.labels(model="classifier").1").time():
        try:
            result = model.predict(...)
            REQUEST_COUNT.labels(model="classifier", status="success").inc()
            return result
        except Exception as e:
            REQUEST_COUNT.labels(model="classifier", status="error").inc()
            raise
```

Plus: log input/output ke MLflow untuk tracking produksi + retraining data.

## Autoscaling

| Trigger | When |
|---|---|
| CPU/GPU util > 70% | Scale up |
| Queue depth > N | Scale up |
| Latency p95 > SLO | Scale up |
| Request rate < baseline | Scale down |

Platform:
- **Kubernetes** + HPA (HorizontalPodAutoscaler)
- **Cloud Run / App Runner**: traffic-based auto
- **Modal, Replicate, BentoCloud**: managed

## Health checks

```python
@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": model is not None}

@app.get("/ready")
async def ready():
    # lebih strict — cek model bisa inference
    if model is None:
        raise HTTPException(503)
    test = model.predict(np.zeros((1, NUM_FEATURES)))
    return {"status": "ready"}
```

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| Model load blocking startup | Use `lifespan` async context manager |
| Input validation skip | Pydantic strict types, return 422 for bad input |
| GPU OOM saat concurrent | Dynamic batching + max concurrent = 1 per GPU |
| Cold start slow | Warm-up inference di startup, cache weights in memory |
| Numerical drift across versions | Pin `numpy`/`torch` versions di lock file |
| PII leak di logs | Redact/hash sensitive fields sebelum log |
| Model artifact di repo (besar) | Simpan di S3/GCS/HF Hub, download at startup |
| No rollback plan | Versioning via BentoML/MLflow registry, stage transitions |

## Checklist before prod

- [ ] Load test: target RPS tercapai
- [ ] Latency p95 < SLO
- [ ] Error rate < 0.1%
- [ ] GPU/CPU headroom untuk 2x peak
- [ ] Health + ready endpoints
- [ ] Metrics ke Prometheus
- [ ] Logs structured (JSON)
- [ ] Model version + git SHA di response
- [ ] Graceful shutdown (in-flight finish)
- [ ] Rollback tested

## Invokation

Auto-trigger saat:
- Edit file yang import bentoml, vllm, fastapi + model
- User sebut "deploy", "serve", "inference", "endpoint"
- Code pattern: predict/score/forward + http endpoint