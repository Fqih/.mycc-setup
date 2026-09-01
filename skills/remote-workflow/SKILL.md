---
name: remote-workflow
description: Use when accessing development machine from phone or another device — Tailscale mesh VPN setup, SSH hardening, code-server optional, mosh for roaming, security checklist. Trigger on "remote", "tailscale", "ssh", "from phone", "HP", "/remote-setup".
---

# remote-workflow

Akses laptop Fedora dari HP via Tailscale mesh VPN + SSH. Tanpa port forwarding, tanpa expose IP publik.

## Arsitektur

```
[HP Android/iOS]  ──── Tailscale tunnel ────>  [Fedora laptop]
   Termux/JuiceSSH                              sshd (port 22)
   atau browser                                 code-server (port 8080, optional)
                                                Ollama (port 11434, opsional)
```

Tailscale memberi IP private statis (100.x.x.x) ke tiap device. Tidak perlu setup router/firewall.

## Setup satu kali (perlu sudo)

### 1. Install Tailscale di Fedora (Zephyrus — primary)

```bash
# official install script
curl -fsSL https://tailscale.com/install.sh | sh

# enable + start
sudo systemctl enable --now tailscaled

# authenticate (browser akan terbuka, login via Google/Microsoft/GitHub)
sudo tailscale up

# cek IP Tailscale (catat untuk dipakai dari HP/device lain)
tailscale ip -4
# Output: 100.x.y.z  ← INI yang dipakai dari device lain
```

### 2. Install Tailscale di device lain

**HP Android/iOS:**
- Android: https://play.google.com/store/apps/details?id=com.tailscale.ipn
- iOS: https://apps.apple.com/app/tailscale/id1470499037

**Windows 11 (HP Pavilion):**
```powershell
# Via winget
winget install Tailscale.Tailscale

# Atau download installer dari https://tailscale.com/download/windows
# Login dengan akun yang sama
```

**Fedora kedua (kalau ada):**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Login dengan akun yang sama di semua device → otomatis masuk mesh.

### 3. Enable SSH server di Fedora

```bash
# install openssh-server jika belum
sudo dnf install -y openssh-server

# generate SSH key (kalau belum ada)
ssh-keygen -t ed25519 -C "fqih@fedora-laptop"

# enable + start
sudo systemctl enable --now sshd

# cek
systemctl status sshd
```

### 4. Hardening sshd_config

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<'EOF'
# Disable password auth — pakai key only
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
PermitEmptyPasswords no

# Limit to Tailscale interface only
ListenAddress 100.x.y.z   # GANTI dengan IP Tailscale kamu

# Session
ClientAliveInterval 60
ClientAliveCountMax 3
MaxAuthTries 3
LoginGraceTime 30
EOF

# validate config
sudo sshd -t && echo "config OK"

# restart
sudo systemctl restart sshd
```

### 5. Test SSH dari device lain

**Dari Android (HP):**
- **JuiceSSH** (GUI) — recommended untuk pemula
- **Termux** + `pkg install openssh` — full shell
- **Termius** (cross-platform) — sync via cloud

```bash
# dari HP (Termux/JuiceSSH)
ssh fqih@100.x.y.z   # GANTI dengan Tailscale IP laptop Zephyrus
```

**Dari Windows 11 (Pavilion):**

```powershell
# Built-in SSH client Windows 10+
ssh fqih@100.x.y.z

# Atau pakai Windows Terminal + WSL2 untuk Linux-like experience
wsl --install -d Fedora   # sekali
wsl                        # masuk WSL
ssh fqih@100.x.y.z         # dari dalam WSL

# Atau pakai VS Code Remote-SSH extension:
# 1. Install extension "Remote - SSH"
# 2. Ctrl+Shift+P → "Remote-SSH: Connect to Host"
# 3. ssh fqih@100.x.y.z
# 4. Buka folder project langsung dari VS Code Pavilion → edit di Zephyrus
```

**Dari iOS:**
- **Blink Shell** — premium tapi powerful
- **Termius** — cross-platform

```bash
ssh fqih@100.x.y.z
```

## Akses spesifik

### File edit di HP — 3 opsi

**A. Code-server (VS Code di browser, recommended)**

```bash
# install di Fedora
curl -fsSL https://code-server.dev/install.sh | sh

# edit config
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<'EOF'
bind-addr: 100.x.y.z:8080   # GANTI dengan Tailscale IP
auth: password
password: "$(head -c 16 /dev/urandom | base64)"   # atau password statis
cert: false
EOF

# enable + start
sudo systemctl enable --now code-server@$USER

# dari HP: buka browser ke http://100.x.y.z:8080
```

**B. Vim/Neovim via SSH + Termux**
Paling ringan, cocok untuk quick edit.

**C. SSHFS mount folder laptop ke HP (Linux only)**
Butuh Termux + Termux:API. Skip untuk Android biasa.

### Ollama dari HP

```bash
# Pastikan OLLAMA_HOST set ke Tailscale IP (lihat local-ml-gpu skill)
# FirewallFedora:
sudo firewall-cmd --permanent --zone=trusted --add-interface=tailscale0
sudo firewall-cmd --reload

# dari HP:
curl http://100.x.y.z:11434/api/generate -d '{"model": "llama3.1:8b", "prompt": "halo"}'
```

## Mosh untuk roaming (opsional)

SSH putus kalau HP ganti WiFi/4G. Mosh = SSH + roaming + UDP.

```bash
# install di Fedora
sudo dnf install -y mosh

# buka port UDP 60001 (kalau pakai firewall strict)
sudo firewall-cmd --permanent --add-port=60001/udp
sudo firewall-cmd --reload

# dari HP (Termux)
pkg install mosh
mosh fqih@100.x.y.z
```

## Security checklist

- [ ] SSH key-based only, password disabled
- [ ] sshd ListenAddress di Tailscale IP saja (bukan 0.0.0.0)
- [ ] Tailscale MagicDNS aktif untuk hostname stattp IP
- [ ] 2FA di akun Tailscale
- [ ] Auto-update Tailscale enabled
- [ ] Backup SSH key ke password manager

## Tailscale commands

```bash
tailscale status              # list devices
tailscale ping <hostname>     # test connectivity
tailscale ip -4               # IP sendiri
tailscale netcheck            # NAT type + connectivity diagnostics
tailscale logout              # remove dari mesh
```

## Invokation

Auto-trigger saat:
- User sebut "remote", "HP", "phone", "tailscale", "ssh"
- Edit file config di `/etc/ssh/sshd_config.d/`, `/etc/systemd/`
- Diskusi soal akses multi-device
