---
name: telegram-notify
description: Use when sending notifications from long-running scripts (training, deploy, cron) to Telegram phone — setup bot via BotFather, polling atau push, anti-spam, secure token storage. Trigger on "telegram", "notify", "bot", "long-running", "/telegram-setup".
---

# telegram-notify

Kirim notifikasi ke HP via Telegram bot saat training selesai, deploy sukses, atau error.

## Setup satu kali

### 1. Buat bot via BotFather

1. Buka Telegram, cari `@BotFather`.
2. Kirim `/newbot`, beri nama + username (harus unik, akhiri `bot`).
3. BotFather kasih **token** simpan:
   ```
   123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   ```
4. **JANGAN commit token ke git.**

### 2. Dapatkan chat_id

Mulai chat dengan bot kamu (klik link dari BotFather), kirim pesan apa saja.

```bash
# Ganti <TOKEN>
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
# Output: 987654321  ← INI chat_id kamu
```

### 3. Simpan credentials

Tambah ke `~/.bashrc` atau `~/.config/telegram.env`:

```bash
# ~/.config/telegram.env (chmod 600)
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export TELEGRAM_CHAT_ID="987654321"
```

```bash
chmod 600 ~/.config/telegram.env
# Load di shell: source ~/.config/telegram.env
```

## Kirim pesan (one-liner)

```bash
# Source env dulu
source ~/.config/telegram.env

# Plain text
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="✅ Training selesai. AUC: 0.87"

# Markdown
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="Markdown" \
    -d text="*Training selesai*
Model: xgboost
AUC: 0.87
Runtime: 23m"

# File (log, plot, csv ≤ 50MB)
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
    -F chat_id="${TELEGRAM_CHAT_ID}" \
    -F document=@training.log
```

## Python wrapper

Taruh di `~/.local/bin/tg-notify` atau project utilities:

```python
#!/usr/bin/env python3
"""tg-notify — kirim pesan Telegram dari script."""
import os
import sys
import requests


def notify(text: str, file: str | None = None) -> None:
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat = os.environ.get("TELEGRAM_CHAT_ID")
    if not token or not chat:
        print("WARN: TELEGRAM_BOT_TOKEN/CHAT_ID not set, skip notify", file=sys.stderr)
        return

    if file:
        url = f"https://api.telegram.org/bot{token}/sendDocument"
        with open(file, "rb") as f:
            requests.post(url, data={"chat_id": chat}, files={"document": f}, timeout=30)
    else:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        requests.post(url, json={"chat_id": chat, "text": text}, timeout=30)


if __name__ == "__main__":
    text = sys.argv[1] if len(sys.argv) > 1 else "(empty)"
    file = sys.argv[2] if len(sys.argv) > 2 else None
    notify(text, file)
```

```bash
chmod +x ~/.local/bin/tg-notify
echo "Training selesai 🎉" | tg-notify
tg-notify "Deploy sukses" deploy.log
```

## Integrasi ML training

```python
# di training script
import time
import mlflow
from tg_notify import notify

start = time.time()

with mlflow.start_run(run_name="exp-042"):
    # ... training loop ...
    for epoch in range(100):
        train_loss = ...
        mlflow.log_metric("train_loss", train_loss, step=epoch)

    # notifikasi di akhir
    notify(
        f"✅ *Training selesai*\n"
        f"Run: {mlflow.active_run().info.run_id}\n"
        f"Final loss: {train_loss:.4f}\n"
        f"Duration: {(time.time() - start) / 60:.1f}m"
    )
```

## Integrasi deploy

```bash
# di Netlify deploy script
netlify deploy --prod --dir=dist && \
    tg-notify "✅ Deployed to production: https://yourapp.netlify.app" || \
    tg-notify "❌ Deploy FAILED — cek log"
```

## Anti-spam

Bot mengirim spam kalau script loop kasih notif tiap step. Throttle:

```python
import time

class ThrottledNotifier:
    def __init__(self, min_interval_sec: int = 300):
        self.min_interval = min_interval_sec
        self._last_sent = 0

    def notify(self, text: str, force: bool = False) -> None:
        now = time.time()
        if not force and (now - self._last_sent) < self.min_interval:
            return  # skip
        notify(text)
        self._last_sent = now

# Usage: hanya notif tiap 5 menit walau training loop iterasi tiap 30 detik
notif = ThrottledNotifier(min_interval_sec=300)
for epoch in range(1000):
    train_loss = ...
    if epoch % 10 == 0:
        notif.notify(f"Epoch {epoch}, loss {train_loss:.4f}")
```

## Security

- Token = akses penuh ke bot. Treat seperti password.
- `chmod 600 ~/.config/telegram.env`
- Jangan commit `.env` apapun ke git (tambah ke `.gitignore`).
- Revoke token di BotFather (`/revoke`) kalau bocor.

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| "chat not found" | Mulai chat dulu dengan bot, kirim `/start` |
| "bot was blocked by user" | User block bot, kirim `/start` lagi di HP |
| Markdown parse error | Escape `_`, `*`, `[` di pesan; atau pakai plain text |
| File > 50MB | Telegram limit, kompres atau pakai link eksternal |
| Rate limit (30 msg/sec global, 1 msg/sec per chat) | Throttle pakai `ThrottledNotifier` |

## Invokation

Auto-trigger saat:
- Script training/deploy/cron panjang tanpa progress feedback
- User sebut "notif", "telegram", "hp", "alert"
- Shell script return non-zero
