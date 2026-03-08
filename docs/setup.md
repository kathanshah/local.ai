# Setup Log

What was done to configure this server and the current state of each phase.

## Execution Status

| Phase | What | Status | Notes |
|-------|------|--------|-------|
| 1 | Install packages | Done | git, build-essential, cmake, pip, docker, ssh, htop, btop, etc. |
| 2 | Disable services | Done | cups, bluetooth, thermald disabled; sleep masked; snapd kept for Firefox/Snap Store but snapd.apparmor re-enabled; avahi re-enabled for mDNS |
| 2 | CPU performance mode | Done | powerprofilesctl=performance, EPP=performance, turbo on, boot service created |
| 3 | Mount 2nd SSD | Done | UUID-based fstab, /mnt/ai-models, chmod 755 (fix: ollama user needs traverse) |
| 3 | noatime | Done | Applied to /, /home, /mnt/ai-models |
| 4 | Kernel tuning | Done | swappiness=10, max_map_count=2M, THP=always, shmmax=128GB |
| 4 | Ulimits | Done | memlock=unlimited, nofile=1M |
| 4 | Journald cap | Done | 500M max |
| 4 | NVIDIA update block | Done | nvidia-/libnvidia-/cuda- blacklisted from unattended-upgrades |
| 5 | GPU optimization | Done | Persistence on, clocks locked 2407-3090/14001 MHz, boot service |
| 6 | Ollama | Done | v0.17.7, models on 2nd SSD, memlock=infinity, host=0.0.0.0, 2 parallel |
| 6 | Qwen3-32B | Done | 20 GB, loaded in VRAM, ~16.5 tok/s |
| 7 | Open WebUI | Done | Docker, port 80 via nginx reverse proxy, healthy |
| 7 | Open Interpreter | Done | Fix: pinned setuptools<81 for pkg_resources |
| 7 | Qwen-Agent | Done | Fix: installed missing soundfile dependency |
| 8 | Static IP | Done | 192.168.29.100/24, gateway .1, DNS 8.8.8.8/1.1.1.1 |
| 8 | Firewall (UFW) | Done | SSH (22), Ollama (11434 LAN + Docker), WebUI (80), mDNS (5353/udp) |
| — | Hostname & mDNS | Done | hostname=ai, avahi re-enabled, allow-interfaces whitelist (real NICs only), UFW allows 5353/udp |
| — | Nginx reverse proxy | Done | Port 80 → Open WebUI (3000), users access http://ai.local |
| — | Branding (Stocky AI) | Done | App name=Stocky AI, model name=Stocky, custom system prompt, business suggestions, signup disabled |
| — | Code interpreter (Jupyter) | Done | Jupyter container on ai-net, connected to Open WebUI for file generation (Excel, CSV, etc.) |
| — | Web search (SearXNG) | Done | Self-hosted search via Docker, private, no API keys needed |
| — | Toggle parallel script | Done | `bash scripts/toggle-parallel.sh` switches between 1×32K and 2×16K |
| 9 | BIOS XMP check | Pending | Check on next reboot: DEL/F2 → Memory settings → Enable XMP |
| 10 | 256 GB RAM + 235B | Future | `ollama pull qwen3:235b-a22b` after RAM upgrade |

## Issues Fixed During Setup

| Issue | Cause | Fix |
|-------|-------|-----|
| Ollama permission denied on /mnt/ai-models | Mount point had 700 permissions | `sudo chmod 755 /mnt/ai-models` |
| Open Interpreter import error | setuptools v82 dropped pkg_resources | `pip install "setuptools<81"` |
| Qwen-Agent import error | Missing soundfile dependency | `pip install soundfile` |
| ai.local resolving to Docker IP (172.17.0.1) | Avahi broadcasting on docker0 | Initially added `deny-interfaces=docker0`; later switched to `allow-interfaces=wlp133s0f0,enp131s0,enp132s0` (whitelist real NICs) because ai-net bridge (br-*) also leaked |
| ai.local unreachable from other machines | UFW blocking mDNS multicast | `sudo ufw allow 5353/udp` |
| Open WebUI can't see models | UFW blocking Docker→Ollama (172.17.0.1→11434) | `sudo ufw allow from 172.17.0.0/16 to any port 11434 proto tcp` |
| Firefox & Snap Store won't launch after reboot | `snapd.apparmor` was disabled when snapd was disabled; snap apps need AppArmor profiles | `sudo systemctl enable --now snapd.apparmor` |
| nvidia-clock-setup fails on boot | Dependency on nvidia-persistenced which initially fails with device permission error | `sudo nvidia-smi -pm 1` manually; service recovers on next boot after persistenced starts |

## Disk Layout

```
/mnt/ai-models/             ← 2nd SSD (1.86 TB)
  ├── ollama/               ← Model weights (19 GB, ollama:ollama ownership)
  ├── open-webui/           ← Open WebUI data & user DB
  ├── jupyter-data/         ← Jupyter working directory (code interpreter output files)
  ├── open-interpreter-env/ ← Python venv
  └── qwen-agent-env/       ← Python venv
```

## Config Files

| File | Purpose |
|------|---------|
| `/etc/systemd/system/ollama.service.d/override.conf` | Ollama: model dir, host binding, ulimits, 2 parallel |
| `/etc/sysctl.d/99-ai-server.conf` | Kernel tuning (swappiness, max_map_count, shmmax, etc.) |
| `/etc/security/limits.d/99-ai-inference.conf` | User ulimits (memlock, nofile) |
| `/etc/systemd/system/nvidia-clock-setup.service` | GPU clock lock on boot |
| `/etc/systemd/system/power-profile-performance.service` | CPU performance mode on boot |
| `/etc/tmpfiles.d/thp.conf` | THP=always on boot |
| `/etc/apt/apt.conf.d/51unattended-upgrades-nvidia` | NVIDIA auto-update block |
| `/etc/systemd/journald.conf.d/size.conf` | Journal size cap (500M) |
| `/etc/nginx/sites-available/ai-server` | Nginx reverse proxy (port 80 → Open WebUI on 3000) |
| `/etc/avahi/avahi-daemon.conf` | mDNS config (allow-interfaces whitelist: real NICs only, no Docker) |
| `/etc/fstab` | 2nd SSD mount (UUID-based, noatime) |
| `/etc/hostname` | Server hostname: ai |
