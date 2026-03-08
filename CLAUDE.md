# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo contains configuration docs and operational scripts for **Stocky AI** — a self-hosted office AI assistant running on a dedicated GPU server. The stack is: Ollama (LLM inference) → Open WebUI (chat UI, branded as "Stocky AI") → Nginx (reverse proxy at http://ai.local). SearXNG provides private web search. All services run on Ubuntu 24.04 with an RTX 5090 GPU.

**This is not a software project with build/test/lint steps.** It's an infrastructure repo — documentation and bash scripts for operating the server.

## Architecture

```
User browser → http://ai.local (port 80)
  → Nginx reverse proxy → Open WebUI (Docker, port 3000)
    → Ollama API (systemd service, port 11434) → Qwen3-32B on GPU
  → SearXNG (Docker, port 8888 on ai-net) for web search
  → Jupyter (Docker, port 8889 on ai-net) for code execution + file generation
```

- **Ollama**: systemd service, models stored on 2nd SSD at `/mnt/ai-models/ollama/`
- **Open WebUI**: Docker container on `ai-net` network, data at `/mnt/ai-models/open-webui/`
- **SearXNG**: Docker container on `ai-net` network, config at `/mnt/ai-models/searxng/`
- **Jupyter**: Docker container on `ai-net` network, work dir at `/mnt/ai-models/jupyter-data/`
- **Nginx**: reverse proxy, config at `/etc/nginx/sites-available/ai-server`
- Ollama config override: `/etc/systemd/system/ollama.service.d/override.conf`

## Key Scripts

All in `scripts/`. Run from repo root with `bash scripts/<name>.sh`.

| Script | Purpose |
|--------|---------|
| `test-system.sh` | Full system verification (41 checks) — run after reboot or changes |
| `test-inference.sh` | Model speed test + VRAM + API check |
| `service-status.sh` | Quick status dashboard |
| `toggle-parallel.sh` | Switch between 1×32K context and 2×16K parallel mode |
| `change-network.sh` | Switch WiFi/Ethernet/DHCP, auto-updates firewall + mDNS |
| `backup-config.sh` | Backup config files to `/mnt/ai-models/backups/` |

## Key Documentation

| Doc | What |
|-----|------|
| `docs/rebuild.md` | Full rebuild from scratch (the authoritative setup guide) |
| `docs/runbook.md` | Daily ops, troubleshooting, maintenance procedures |
| `docs/setup.md` | Setup log with phase status, config file locations, issues fixed |
| `docs/checklist.md` | Manual verification checklist |
| `docs/hardware.md` | Exact hardware/software specs and performance tuning values |

## Important Details

- Server IP: `192.168.29.100` (static), hostname: `ai`, accessible as `ai.local` via mDNS
- Primary model: `qwen3:32b` (Q4_K_M, 20 GB on disk, ~29 GB VRAM)
- Model is branded as "Stocky" in Open WebUI with a custom system prompt
- NVIDIA drivers are blocked from auto-updates (see `/etc/apt/apt.conf.d/51unattended-upgrades-nvidia`)
- GPU clocks locked via `nvidia-clock-setup.service`, CPU pinned to performance mode
- Docker network `ai-net` enables container-to-container DNS (Open WebUI ↔ SearXNG ↔ Jupyter)
- UFW firewall allows: SSH (22), HTTP (80), Ollama (11434 from LAN + Docker subnets), mDNS (5353/udp)
- Future plan: 256 GB RAM upgrade → Qwen3-235B-A22B model
