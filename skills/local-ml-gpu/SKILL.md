---
name: local-ml-gpu
description: Use when running ML training/inference on local AMD GPU (RX 6700S / RX 6800S / RX 6650 XT family = Navi 23 RDNA 2). Activates unsloth venv with bundled ROCm + PyTorch, exposes GPU selection pattern, Ollama integration, libmpi workaround for system Python. Trigger on "GPU", "ROCm", "torch.cuda", "ollama", "RX 6700S", "/gpu-check".
---

# local-ml-gpu

GPU compute workflow untuk multi-device setup:

| Device | OS | GPU | VRAM | Stack |
|---|---|---|---|---|
| **ASUS ROG Zephyrus** (primary) | Fedora 44 | AMD RX 6700S (Navi 23, RDNA 2) | 8GB | ROCm via unsloth venv |
| Zephyrus iGPU | Fedora 44 | Radeon 680M (Rembrandt) | shared | Display |
| **HP Pavilion** (secondary) | Windows 11 | NVIDIA GTX 1650 (Turing, cc 7.5) | 4GB | CUDA wheels regular |
| Pavilion | Windows 11 | Intel/AMD iGPU (Rembrandt/Vega) | shared | Display |

## Zephyrus — ROCm workflow (SUDAH JADI)

`torch.cuda.is_available()` = True via ROCm (PyTorch expose HIP sebagai CUDA API).

### Setup — pakai unsloth venv (SUDAH JADI)

JANGAN install PyTorch ROCm baru. Unsloth sudah bundle ROCm 7.13 + PyTorch 2.10.0+rocm7.13.0.

```bash
# Quick test
~/.unsloth/studio/unsloth_studio/bin/python3 -c "
import torch
print('torch:', torch.__version__)
print('cuda avail:', torch.cuda.is_available())
print('device 0:', torch.cuda.get_device_name(0))
print('VRAM:', torch.cuda.get_device_properties(0).total_memory / 1e9, 'GB')
"
# Expected output:
# torch: 2.10.0+rocm7.13.0
# cuda avail: True
# device 0: AMD Radeon RX 6700S
# VRAM: 8.0... GB
```

### Pakai sebagai default

Tambah ke `~/.bashrc` atau `~/.zshrc`:

```bash
# GPU Python (unsloth ROCm venv)
alias gpu-py='~/.unsloth/studio/unsloth_studio/bin/python3'
alias gpu-venv='source ~/.unsloth/studio/unsloth_studio/bin/activate'
```

Pakai `gpu-py script.py` untuk run script GPU tanpa activate venv.

### Untuk project baru: clone venv via uv

```bash
# clone unsloth env ke project-local venv (preserve ROCm libs)
uv venv .venv --python ~/.unsloth/studio/unsloth_studio/bin/python3
# atau
~/.unsloth/studio/unsloth_studio/bin/python3 -m venv .venv
```

## System Python broken untuk ROCm — kenapa

Default `python3` di pyenv (3.12.13) bisa import torch tapi gagal karena missing `libmpi_cxx.so.40`. Solusi: pakai unsloth venv yang bundle libs lengkap via `_rocm_sdk_core`.

Workaround kalau HARUS pakai system Python:

```bash
# cari libmpi di unsloth bundle
find ~/.cache/uv/archive-v0 -name 'libmpi_cxx.so*' 2>/dev/null | head -1
# set LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$(find ~/.cache/uv/archive-v0 -name '_rocm_sdk_core' -type d 2>/dev/null | head -1)/lib:$LD_LIBRARY_PATH"
python3 -c "import torch; print(torch.cuda.is_available())"
```

Lebih baik: pakai unsloth python langsung, no LD_LIBRARY_PATH hack.

## GPU selection pattern

```python
import torch

# default: GPU 0 (RX 6700S)
device = torch.device("cuda:0")  # atau "cuda" (sama)

# explicit VRAM check sebelum load model
free, total = torch.cuda.mem_get_info()
print(f"Free VRAM: {free/1e9:.1f}GB / {total/1e9:.1f}GB")

# Multi-GPU (kalau ada discrete + iGPU — saat ini dual tapi iGPU biasanya reserved display)
# RX 6700S = cuda:0, 680M iGPU = biasanya tidak di-expose ke torch
```

## Pavilion (Windows 11) — CUDA workflow

GTX 1650 = Turing, CUDA cc 7.5, 4GB VRAM. RAM 8GB total = ketat, pakai swap/Page File.

### Setup PyTorch CUDA di Windows

```powershell
# Cek CUDA driver version
nvidia-smi
# Output: CUDA Version: 12.x — install PyTorch yang kompatibel

# Install PyTorch CUDA (via pip, pakai py -m pip)
py -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
# atau cu118 kalau driver lebih lama

# Verify
py -c "import torch; print('torch:', torch.__version__); print('cuda:', torch.cuda.is_available()); print('device:', torch.cuda.get_device_name(0))"
# Expected:
# torch: 2.x.x+cu121
# cuda: True
# device: NVIDIA GeForce GTX 1650
```

### Limitasi GTX 1650 (4GB VRAM)

- ❌ Tidak bisa load LLM > 7B quantized
- ❌ Tidak bisa training LLM (cuma inference quantized)
- ✅ Inference model kecil (≤ 3B param): llama3.2-3b, phi-3-mini, gemma-2-2b
- ✅ Training CNN/kecil: image classifier, fine-tune BERT-small
- ✅ Stable Diffusion (harus `--lowvram` flag)
- ⚠️ Training LLM dengan QLoRA:勉强, perlu CPU offload agresif

### Ollama di Windows

```powershell
# Download installer dari https://ollama.com/download/windows
# atau via winget
winget install Ollama.Ollama

# Default listen 127.0.0.1:11434
# Pull model ringkas
ollama pull llama3.2:3b-instruct-q4_K_M
ollama pull phi3:mini
ollama pull gemma2:2b
```

### WSL2 alternative (Linux env di Windows)

Untuk akses ROCm-like tooling atau Linux dev env:

```powershell
# Install WSL2
wsl --install -d Fedora

# Setup ROCm di WSL2 (lebih reliable dari native Windows ROCm)
# Ikuti pola unsloth venv di WSL2
```

### Sync konfigurasi CC ke Windows

Pavilion butuh config sendiri kalau CC dipakai lokal di sana:

```powershell
# Clone repo setup publik ke Windows
git clone https://github.com/Fqih/.mycc-setup.git $HOME\.mycc-setup
# Manual copy skills/rules ke %USERPROFILE%\.claude\
# (Symlink/copy — lihat repo README)
```

## ROCm diagnostic

## Ollama (sudah terinstall, active)

```bash
# status
systemctl status ollama

# list models
ollama list

# pull model (mis. llama3.1 8B quantized)
ollama pull llama3.1:8b-instruct-q4_K_M

# run interactive
ollama run llama3.1:8b-instruct-q4_K_M

# API endpoint
curl http://127.0.0.1:11434/api/generate -d '{
  "model": "llama3.1:8b-instruct-q4_K_M",
  "prompt": "Halo dalam bahasa Indonesia"
}'
```

### Ollama perf tuning untuk RX 6700S (8GB VRAM)

Edit `/etc/systemd/system/ollama.service.d/override.conf` atau `/etc/default/ollama`:

```bash
# pakai GPU layers offload penuh untuk model ≤ 7B
OLLAMA_NUM_GPU=999
# context window
OLLAMA_CONTEXT_LENGTH=8192
# bind ke Tailscale IP kalau mau akses dari HP (lihat remote-workflow skill)
OLLAMA_HOST=100.x.x.x:11434  # GANTI dengan Tailscale IP
```

Apply: `systemctl daemon-reload && systemctl restart ollama`.

### Pakai Ollama dari Python

```python
import requests

def ollama_generate(prompt: str, model: str = "llama3.1:8b-instruct-q4_K_M") -> str:
    resp = requests.post(
        "http://127.0.0.1:11434/api/generate",
        json={"model": model, "prompt": prompt, "stream": False},
        timeout=120,
    )
    return resp.json()["response"]
```

## ROCm diagnostic

```bash
# GPU status + util
rocm-smi

# detailed device info (install rocminfo jika belum ada)
sudo dnf install rocminfo  # jika ada di repo
# atau pakai /opt/rocm*/bin/rocminfo (mungkin belum ada di Fedora 44)

# alternative: pakai python
~/.unsloth/studio/unsloth_studio/bin/python3 -c "
import torch
print(torch.cuda.get_device_properties(0))
"
```

Cek VRAM real-time saat training:

```bash
watch -n 1 rocm-smi
```

## Training pattern (LoRA pada LLM)

```python
# quick LoRA fine-tune pakai unsloth (optimal untuk RDNA 2)
from unsloth import FastLanguageModel
from trl import SFTTrainer

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/llama-3.1-8b-instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,  # Wajib untuk 8GB VRAM
)

model = FastLanguageModel.get_peft_model(
    model,
    r=16,  # LoRA rank
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_alpha=16,
)

# ... training loop ...

# Simpan adapter
model.save_pretrained("./adapter")
```

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| `libmpi_cxx.so.40: cannot open` | Pakai unsloth python, jangan system python |
| VRAM OOM saat load model | `load_in_4bit=True` atau quantize ke q4_K_M |
| `torch.cuda.is_available()` False | Cek `rocminfo`, pastikan ROCm detect GPU |
| Ollama lambat | Cek `OLLAMA_NUM_GPU=999`, model harus ≤ 8B untuk 8GB VRAM |
| Training loss NaN | Lower learning rate, gradient clipping, cek dtype fp16 vs bf16 |

## Invokation

Auto-trigger saat:
- Import torch / detect GPU device
- User sebut "GPU", "ROCm", "RX 6700S", "training", "fine-tune"
- Script di folder project ML
