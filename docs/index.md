# Admin Documentation

Server administration docs for the local.ai office server.

## Quick Access

| What | URL / Command |
|------|---------------|
| Stocky AI (chat) | http://ai.local |
| Ollama API | http://ai.local:11434 |
| Jupyter (code interpreter) | http://localhost:8889 (localhost only, token: `stocky-jupyter-token`) |
| SSH | `ssh k-server@ai.local` |

## Documentation

| Doc | Description |
|-----|-------------|
| [hardware.md](hardware.md) | Tested hardware and software configuration |
| [setup.md](setup.md) | Setup phases, config files, and disk layout |
| [rebuild.md](rebuild.md) | Full rebuild from scratch (step-by-step) |
| [runbook.md](runbook.md) | Daily operations, maintenance, and troubleshooting |
| [checklist.md](checklist.md) | Verification checklist for setup, reboots, and network changes |
| [cli-tools.md](cli-tools.md) | CLI coding assistants — Claude Code + Ollama setup (recommended), OpenCode, CodeBuff comparison |
| [system-prompt.md](system-prompt.md) | System prompt for local model — why it exists, how it works, how to maintain it |

## Scripts

All scripts are in [`../scripts/`](../scripts/). On the server they're also at `~/scripts/`.

| Script | What it does | Run |
|--------|-------------|-----|
| [test-system.sh](../scripts/test-system.sh) | Full system verification — hardware, services, config, network | `bash scripts/test-system.sh` |
| [test-inference.sh](../scripts/test-inference.sh) | Model speed test, VRAM check, API connectivity | `bash scripts/test-inference.sh` |
| [service-status.sh](../scripts/service-status.sh) | Quick dashboard — GPU, memory, disk, services | `bash scripts/service-status.sh` |
| [change-network.sh](../scripts/change-network.sh) | Switch WiFi/Ethernet/DHCP + auto-update firewall | `bash scripts/change-network.sh` |
| [backup-config.sh](../scripts/backup-config.sh) | Backup all config files to 2nd SSD | `bash scripts/backup-config.sh` |
| [toggle-parallel.sh](../scripts/toggle-parallel.sh) | Switch between 1×32K and 2×16K parallel modes | `bash scripts/toggle-parallel.sh` |
| [claude-local.sh](../scripts/claude-local.sh) | Run Claude Code with local Ollama (free, private) | `bash scripts/claude-local.sh` |
| [stocky-prompt.txt](../scripts/stocky-prompt.txt) | System prompt for local model — maps tasks to Python packages | Used by claude-local.sh and client alias |
| [client/setup-windows.ps1](../scripts/client/setup-windows.ps1) | Automated Windows client setup (Git, Node, Python, Claude Code, packages) | `powershell -ExecutionPolicy Bypass -File setup-windows.ps1` |
| [client/setup-mac.sh](../scripts/client/setup-mac.sh) | Automated macOS client setup (Homebrew, Node, Python, Claude Code, packages) | `bash scripts/client/setup-mac.sh` |
| [client/README.md](../scripts/client/README.md) | Client setup guide — requirements, usage, troubleshooting | |

## Quick Commands

```bash
# Check everything after a reboot
bash scripts/test-system.sh

# Quick status
bash scripts/service-status.sh

# Restart services
sudo systemctl restart ollama
sudo docker restart open-webui

# View logs
journalctl -u ollama -f
sudo docker logs -f open-webui

# GPU status
nvidia-smi
```
