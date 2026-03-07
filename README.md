# local.ai

Local AI office server — self-hosted LLM inference on a dedicated machine, accessible to all devices on the LAN via `http://ai.local`.

## Hardware

| Component | Details |
|-----------|---------|
| CPU | Intel Core Ultra 9 285K — 24 cores |
| RAM | 128 GB DDR5 (256 GB upgrade planned) |
| GPU | NVIDIA RTX 5090 — 32 GB VRAM |
| Storage | 2x 1.86 TB NVMe SSDs (OS + Models) |
| OS | Ubuntu 24.04 LTS |

## Stack

- **Ollama** — LLM inference server
- **Open WebUI** — Browser-based chat interface (Docker)
- **Nginx** — Reverse proxy (port 80 → Open WebUI)
- **Avahi/mDNS** — Zero-config local DNS (`ai.local`)
- **Open Interpreter** — Natural language file/Excel operations
- **Qwen-Agent** — Agentic task automation

## Models

| Model | Status | Use Case |
|-------|--------|----------|
| Qwen3-32B | Active (fits in VRAM) | Daily driver — emails, content, docs, research |
| Qwen3-235B-A22B | Future (needs 256 GB RAM) | Legal, financial, deep research |

## Access

| Service | URL |
|---------|-----|
| Chat UI | http://ai.local |
| Ollama API | http://ai.local:11434 |
| SSH | `ssh k-server@ai.local` |

## Docs

- [`todo.md`](todo.md) — Setup status and system configuration reference
- [`runbook.md`](runbook.md) — Operational procedures and troubleshooting
- [`checklist.md`](checklist.md) — Verification checklist for setup and changes

## Scripts

| Script | Purpose |
|--------|---------|
| [`scripts/test-system.sh`](scripts/test-system.sh) | Full system verification (hardware, services, config) |
| [`scripts/test-inference.sh`](scripts/test-inference.sh) | Model speed and VRAM test |
| [`scripts/service-status.sh`](scripts/service-status.sh) | Quick status dashboard |
| [`scripts/change-network.sh`](scripts/change-network.sh) | Switch network + auto-update firewall |
| [`scripts/backup-config.sh`](scripts/backup-config.sh) | Backup all config files to 2nd SSD |

## Quick Start

```bash
# Check system status
bash scripts/service-status.sh

# Run full verification
bash scripts/test-system.sh

# Test inference speed
bash scripts/test-inference.sh
```

## License

Private — internal use only.
