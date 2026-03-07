# Tested Hardware & Software Configuration

This documents the exact hardware and software this setup was built and tested on.

## Hardware

| Component | Model | Specs |
|-----------|-------|-------|
| CPU | Intel Core Ultra 9 285K | 24 cores (8P + 16E), up to 5.8 GHz, LGA 1851 |
| RAM | DDR5 (2x 64 GB) | 128 GB total, XMP profile recommended |
| GPU | NVIDIA GeForce RTX 5090 | 32 GB GDDR7 VRAM, 575W TDP |
| Disk 1 (OS) | NVMe SSD (nvme1n1) | 1.86 TB, ext4, mounted at / |
| Disk 2 (Models) | NVMe SSD (nvme0n1) | 1.86 TB, ext4, mounted at /mnt/ai-models |
| Motherboard | (LGA 1851, PCIe 5.0) | ReBAR enabled (BAR1 = 32768 MiB) |

## Software

| Component | Version | Notes |
|-----------|---------|-------|
| OS | Ubuntu 24.04.4 LTS | Server install, minimal desktop |
| Kernel | 6.17.0-14-generic | Default Ubuntu kernel |
| NVIDIA Driver | 590.48.01 | Auto-update blocked via unattended-upgrades |
| CUDA | 13.1 | Included with driver |
| Ollama | 0.17.7 | LLM inference server |
| Open WebUI | latest (Docker) | `ghcr.io/open-webui/open-webui:main` |
| Nginx | 1.24.0 | Reverse proxy (port 80 → Open WebUI) |
| Docker | Community Edition | For Open WebUI container |
| Python | 3.x (system) | Venvs for Open Interpreter and Qwen-Agent |

## Models Tested

| Model | Quantization | Size on Disk | VRAM Usage | Tokens/sec | Fits in VRAM |
|-------|-------------|-------------|------------|------------|-------------|
| Qwen3-32B | Q4_K_M | 20 GB | ~29 GB | ~16.5 tok/s | Yes (fully) |

### Planned

| Model | Quantization | Size on Disk | Requirements |
|-------|-------------|-------------|-------------|
| Qwen3-235B-A22B | Q4_K_M | ~142 GB | 256 GB RAM (upgrade needed) |

## BIOS Settings

| Setting | Value | Notes |
|---------|-------|-------|
| XMP / EXPO | Enable | DDR5 memory profile — check on next reboot |
| ReBAR | Enabled | Resizable BAR for full GPU memory mapping |
| PCIe Gen | Auto / Gen 5 | For GPU slot |

## Network (as tested)

| Setting | Value |
|---------|-------|
| Connection | WiFi (Kathan Fiber 5G) |
| IP | 192.168.29.100/24 (static) |
| Gateway | 192.168.29.1 |
| DNS | 8.8.8.8, 1.1.1.1 |
| Hostname | ai (ai.local via mDNS/Avahi) |

Network settings are site-specific. Use `bash scripts/change-network.sh` when moving to a different network.

## Performance Tuning Applied

| Tuning | Value | Why |
|--------|-------|-----|
| vm.swappiness | 10 | Keep model weights in RAM |
| vm.max_map_count | 2097152 | Required for mmap model loading (llama.cpp) |
| THP | always | Reduce TLB misses for large memory allocations |
| kernel.shmmax | 137438953472 (128 GB) | Shared memory for large models |
| Power profile | performance | Max CPU frequency |
| EPP | performance | Energy Performance Preference for P-cores |
| Intel Turbo | enabled | Allow boost clocks |
| GPU persistence | enabled | Avoid driver unload/reload latency |
| GPU clocks | locked 2407-3090 / 14001 MHz | Consistent inference speed |
| memlock | unlimited | Allow pinning model memory |
| nofile | 1048576 | High file descriptor limit for Ollama |
| noatime | on /, /home, /mnt/ai-models | Reduce unnecessary disk writes |
| Journald | 500M max | Prevent log bloat |
| NVIDIA auto-update | blocked | Prevent driver breakage from unattended-upgrades |
