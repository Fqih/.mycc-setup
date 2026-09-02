---
description: Check GPU availability + driver version — ROCm untuk AMD RX 6700S, CUDA untuk NVIDIA GTX 1650.
---

Verify GPU stack siap untuk ML/DL workload. Dual-device aware: ROCm untuk Zephyrus, CUDA untuk Pavilion.

## Step 1: Detect device + GPU vendor

```bash
# Vendor
if command -v lspci &>/dev/null; then
    lspci | grep -i "vga\|3d"
fi

# AMD?
if lsmod 2>/dev/null | grep -q amdgpu; then
    echo "AMD GPU detected"
fi

# NVIDIA?
if lsmod 2>/dev/null | grep -q nvidia; then
    echo "NVIDIA GPU detected"
fi
```

## Step 2: ROCm version + status (AMD)

```bash
if command -v rocminfo &>/dev/null; then
    rocminfo | head -30
else
    echo "rocminfo not installed"
fi

# Kernel driver
cat /sys/module/amdgpu/version 2>/dev/null || echo "amdgpu module not loaded"

# HSA runtime
ls /opt/rocm*/bin/ 2>/dev/null | head -20
```

## Step 3: CUDA version + status (NVIDIA)

```bash
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi
else
    echo "nvidia-smi not available"
fi

# CUDA toolkit
nvcc --version 2>/dev/null || echo "nvcc not in PATH"
ls /usr/local/cuda*/bin/nvcc 2>/dev/null
```

## Step 4: PyTorch backend verification

```bash
python <<'EOF'
import torch

print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"Device count: {torch.cuda.device_count()}")
    print(f"Current device: {torch.cuda.current_device()}")
    print(f"Device name: {torch.cuda.get_device_name(0)}")
    print(f"VRAM: {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB")

# ROCm check
if hasattr(torch.version, 'hip'):
    print(f"HIP version: {torch.version.hip}")
    if torch.cuda.is_available():
        # ROCm build expose as CUDA API
        print(f"ROCm build active (HIP runtime)")
EOF
```

## Step 5: Quick compute sanity test

```bash
python <<'EOF'
import torch

if not torch.cuda.is_available():
    print("SKIP: no GPU available")
    exit(0)

# Small matmul sanity check
device = torch.device("cuda:0")
a = torch.randn(1024, 1024, device=device)
b = torch.randn(1024, 1024, device=device)

torch.cuda.synchronize()
import time
start = time.time()
c = a @ b
torch.cuda.synchronize()
elapsed = time.time() - start

print(f"1024x1024 matmul: {elapsed*1000:.1f} ms")
print(f"Result shape: {c.shape}, dtype: {c.dtype}")
print(f"Sanity: {c.mean().item():.4f} (expected ~0)")
print("GPU OK")
EOF
```

## Expected results

### Zephyrus (RX 6700S, Fedora, ROCm)

```
PyTorch: 2.10.0+rocm7.13.0
CUDA available: True
HIP version: 7.13.0
Device count: 1
Current device: 0
Device name: AMD Radeon RX 6700S
VRAM: 8.0 GB
1024x1024 matmul: 15-30 ms
```

### Pavilion (GTX 1650, Windows, CUDA)

```
PyTorch: 2.x.x+cu12x
CUDA available: True
CUDA version: 12.x
Device count: 1
Device name: NVIDIA GeForce GTX 1650
VRAM: 4.0 GB
1024x1024 matmul: 50-100 ms
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `torch.cuda.is_available()` False | PyTorch CPU-only build | `pip install torch --index-url https://download.pytorch.org/whl/rocm6.0` atau `+cu121` |
| `amd-gpu not detected` di ROCm | `HSA_OVERRIDE_GFX_VERSION` missing | `export HSA_OVERRIDE_GFX_VERSION=10.3.0` (RX 6700S Navi 23) |
| `CUDA out of memory` | VRAM < batch × model | Reduce batch, gradient checkpointing, atau FP16 |
| `nvcc not found` | CUDA toolkit not in PATH | `export PATH=/usr/local/cuda/bin:$PATH` |
| `No module named torch` | Venv not activated | `source ~/venvs/unsloth/bin/activate` (atau yang sesuai) |
| `amdgpu: Unknown symbol` | Kernel module mismatch | Update kernel + amdgpu driver |

## Venv reminder

Zephyrus: gunakan unsloth venv (PyTorch ROCm):
```bash
source ~/venvs/unsloth/bin/activate
```

Pavilion: gunakan CUDA venv:
```bash
source ~/venvs/cuda/bin/activate
```

Lihat skill `local-ml-gpu` untuk full GPU workflow.

## Output format

Final report harus include:
1. Device type (Zephyrus / Pavilion)
2. GPU vendor + model
3. Driver version (amdgpu / nvidia)
4. ROCm/CUDA version
5. PyTorch version + backend
6. VRAM available
7. Compute sanity test result
8. Pass/fail status
