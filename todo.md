# AI Office Server — Setup Complete

## System

| Component | Details |
|-----------|---------|
| CPU | Intel Core Ultra 9 285K — 24 cores, up to 5.8 GHz |
| RAM | 128 GB DDR5 (upgrade to 256 GB planned) |
| GPU | NVIDIA RTX 5090 — 32 GB VRAM, Driver 590.48.01, CUDA 13.1 |
| Disk 1 | 1.86 TB NVMe (nvme1n1) — OS + Home + EFI |
| Disk 2 | 1.86 TB NVMe (nvme0n1) — mounted at /mnt/ai-models |
| OS | Ubuntu 24.04.4 LTS, Kernel 6.17.0-14 |
| Hostname | ai (ai.local on LAN via mDNS) |
| IP | 192.168.29.100 (static, WiFi "Kathan Fiber 5G") |
| ReBAR | Enabled (BAR1 = 32768 MiB) |

---

## Models

| Model | Size | Where | Use Case |
|---|---|---|---|
| Qwen3-32B (daily driver) | 20 GB Q4_K_M | Fully in VRAM | Emails, content, Excel, docs, research, agentic tasks |
| Qwen3-235B-A22B (future) | 142 GB Q4_K_M | RAM + GPU offload | Legal contracts, financial analysis, deep research |

---

## Execution Status

| Phase | What | Status | Notes |
|---|---|---|---|
| 1 | Install packages | Done | git, build-essential, cmake, pip, docker, ssh, htop, btop, etc. |
| 2 | Disable services | Done | cups, bluetooth, snapd, thermald disabled; sleep masked; avahi re-enabled for mDNS |
| 2 | CPU performance mode | Done | powerprofilesctl=performance, EPP=performance, turbo on, boot service created |
| 3 | Mount 2nd SSD | Done | UUID-based fstab, /mnt/ai-models, chmod 755 (fix: ollama user needs traverse) |
| 3 | noatime | Done | Applied to /, /home, /mnt/ai-models |
| 4 | Kernel tuning | Done | swappiness=10, max_map_count=2M, THP=always, shmmax=128GB |
| 4 | Ulimits | Done | memlock=unlimited, nofile=1M (takes effect on re-login) |
| 4 | Journald cap | Done | 500M max |
| 4 | NVIDIA update block | Done | nvidia-/libnvidia-/cuda- blacklisted from unattended-upgrades |
| 5 | GPU optimization | Done | Persistence on, clocks locked 2407-3090/14001 MHz, boot service |
| 6 | Ollama | Done | v0.17.7, models on 2nd SSD, memlock=infinity, host=0.0.0.0 |
| 6 | Qwen3-32B | Done | Downloading (18/20 GB at time of last check) |
| 7 | Open WebUI | Done | Docker, port 3000, healthy, connected to Ollama |
| 7 | Open Interpreter | Done | Fix: pinned setuptools<81 for pkg_resources |
| 7 | Qwen-Agent | Done | Fix: installed missing soundfile dependency |
| 8 | Static IP | Done | 192.168.29.100/24, gateway .1, DNS 8.8.8.8/1.1.1.1 |
| 8 | Firewall | Done | SSH + Ollama (LAN only) + WebUI (port 3000) |
| — | Hostname & mDNS | Done | Hostname=ai, avahi re-enabled (docker0 excluded), UFW allows 5353/udp for mDNS |
| — | Nginx reverse proxy | Done | Port 80 → Open WebUI (3000), users just type ai.local |
| 9 | BIOS XMP check | Pending | Check on next reboot: DEL/F2 → Memory settings → Enable XMP |
| 10 | 256 GB RAM + 235B | Future | `ollama pull qwen3:235b-a22b` after RAM upgrade |

---

## Disk Layout

```
/mnt/ai-models/             ← 2nd SSD (1.9 TB)
  ├── ollama/               ← Model weights (ollama:ollama ownership)
  ├── open-webui/           ← Open WebUI data & user DB
  ├── open-interpreter-env/ ← Python venv
  └── qwen-agent-env/       ← Python venv
```

---

## Config Files

| File | Purpose |
|---|---|
| `/etc/systemd/system/ollama.service.d/override.conf` | Ollama: model dir, host, ulimits |
| `/etc/sysctl.d/99-ai-server.conf` | Kernel tuning for AI inference |
| `/etc/security/limits.d/99-ai-inference.conf` | User ulimits (memlock, nofile) |
| `/etc/systemd/system/nvidia-clock-setup.service` | GPU clock lock on boot |
| `/etc/systemd/system/power-profile-performance.service` | CPU performance mode on boot |
| `/etc/tmpfiles.d/thp.conf` | THP=always on boot |
| `/etc/apt/apt.conf.d/51unattended-upgrades-nvidia` | NVIDIA auto-update block |
| `/etc/systemd/journald.conf.d/size.conf` | Journal size cap (500M) |
| `/etc/nginx/sites-available/ai-server` | Nginx reverse proxy (port 80 → Open WebUI) |
| `/etc/avahi/avahi-daemon.conf` | mDNS config (docker0 excluded) |

---

## Scripts

| Script | Purpose |
|---|---|
| `~/scripts/test-system.sh` | Full system verification (all phases) |
| `~/scripts/test-inference.sh` | Model speed and VRAM test |
| `~/scripts/change-network.sh` | Switch WiFi/Ethernet/DHCP + auto firewall update |
| `~/scripts/service-status.sh` | Quick status dashboard |
| `~/scripts/backup-config.sh` | Backup all config files to 2nd SSD |

---

## Quick Reference

| What | URL / Command |
|---|---|
| Open WebUI | http://ai.local |
| Ollama API | http://ai.local:11434 |
| SSH | `ssh k-server@ai.local` |
| Open Interpreter | `source /mnt/ai-models/open-interpreter-env/bin/activate && interpreter --api_base http://localhost:11434/v1 --api_key fake_key --model qwen3:32b` |
| Pull model | `ollama pull <model>` |
| List models | `ollama list` |
| Check GPU | `nvidia-smi` |
| Restart Ollama | `sudo systemctl restart ollama` |
| Restart WebUI | `sudo docker restart open-webui` |
| Ollama logs | `journalctl -u ollama -f` |
| WebUI logs | `sudo docker logs -f open-webui` |
| Full docs | `~/runbook.md` |
| Checklist | `~/checklist.md` |
