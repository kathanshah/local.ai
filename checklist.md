# AI Server — Setup Verification Checklist

Use this after initial setup or after any major change. Run `bash ~/scripts/test-system.sh` for automated checks.

---

## Hardware

- [ ] GPU detected: `nvidia-smi` shows RTX 5090, 32 GB VRAM
- [ ] RAM: `free -h` shows 125+ GB (or 252+ after upgrade)
- [ ] CPU: `nproc` shows 24 cores
- [ ] Disk 2: `df -h /mnt/ai-models` shows 1.8T available
- [ ] ReBAR: `nvidia-smi -q | grep BAR1` shows 32768 MiB
- [ ] XMP enabled in BIOS (check manually)

## Disk & Filesystem

- [ ] 2nd SSD mounted: `mountpoint /mnt/ai-models` succeeds
- [ ] Persistent mount: `grep ai-models /etc/fstab` shows UUID-based entry
- [ ] noatime on root: `mount | grep " / "` includes noatime
- [ ] noatime on home: `mount | grep " /home "` includes noatime
- [ ] Correct ownership: `ls -la /mnt/ai-models/ollama` shows ollama:ollama
- [ ] Directory structure exists:
  - [ ] `/mnt/ai-models/ollama/`
  - [ ] `/mnt/ai-models/open-webui/`
  - [ ] `/mnt/ai-models/open-interpreter-env/`
  - [ ] `/mnt/ai-models/qwen-agent-env/`

## Kernel & Memory

- [ ] swappiness: `sysctl vm.swappiness` = 10
- [ ] max_map_count: `sysctl vm.max_map_count` = 2097152
- [ ] overcommit_memory: `sysctl vm.overcommit_memory` = 0
- [ ] THP: `cat /sys/kernel/mm/transparent_hugepage/enabled` shows [always]
- [ ] memlock ulimit: `ulimit -l` = unlimited (after re-login)
- [ ] nofile ulimit: `ulimit -n` = 1048576 (after re-login)
- [ ] Journald capped: `journalctl --disk-usage` < 500M

## CPU & Power

- [ ] Power profile: `powerprofilesctl get` = performance
- [ ] Energy pref: `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` = performance
- [ ] Turbo enabled: `cat /sys/devices/system/cpu/intel_pstate/no_turbo` = 0
- [ ] Persistence service: `systemctl is-enabled power-profile-performance` = enabled

## GPU

- [ ] Persistence mode: `nvidia-smi -q | grep "Persistence Mode"` = Enabled
- [ ] GPU clock locked: `nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader` >= 2400 MHz
- [ ] Memory clock locked: `nvidia-smi --query-gpu=clocks.current.memory --format=csv,noheader` = 14001 MHz
- [ ] Clock service: `systemctl is-enabled nvidia-clock-setup` = enabled
- [ ] Power limit: `nvidia-smi -q | grep "Power Limit"` shows 575W

## Services — Should be DISABLED

- [ ] cups: `systemctl is-active cups` = inactive
- [ ] bluetooth: `systemctl is-active bluetooth` = inactive
- [ ] snapd: `systemctl is-active snapd` = inactive
- [ ] thermald: `systemctl is-active thermald` = inactive
- [ ] sleep targets: `systemctl is-enabled sleep.target` = masked

## Services — Should be RUNNING

- [ ] ollama: `systemctl is-active ollama` = active
- [ ] docker: `systemctl is-active docker` = active
- [ ] ssh: `systemctl is-active ssh` = active
- [ ] nvidia-persistenced: `systemctl is-active nvidia-persistenced` = active
- [ ] avahi-daemon: `systemctl is-active avahi-daemon` = active
- [ ] nginx: `systemctl is-active nginx` = active

## Hostname & mDNS

- [ ] Hostname: `hostname` = ai
- [ ] mDNS resolves: `ping -c1 ai.local` responds with LAN IP (not 172.17.x.x)
- [ ] Avahi docker excluded: `grep deny-interfaces /etc/avahi/avahi-daemon.conf` shows docker0
- [ ] UFW mDNS rule: `sudo ufw status | grep 5353` shows 5353/udp ALLOW
- [ ] WebUI via hostname: `curl -s http://ai.local` responds
- [ ] Ollama via hostname: `curl -s http://ai.local:11434/api/tags` responds

## Ollama

- [ ] API responds: `curl -s http://localhost:11434/api/tags` returns JSON
- [ ] Bound to all interfaces: `grep OLLAMA_HOST /etc/systemd/system/ollama.service.d/override.conf` = 0.0.0.0:11434
- [ ] Models on 2nd SSD: `grep OLLAMA_MODELS /etc/systemd/system/ollama.service.d/override.conf` = /mnt/ai-models/ollama
- [ ] Memlock unlimited: `grep LimitMEMLOCK /etc/systemd/system/ollama.service.d/override.conf` = infinity
- [ ] File descriptors: `grep LimitNOFILE /etc/systemd/system/ollama.service.d/override.conf` = 1048576
- [ ] Qwen3-32B available: `ollama list` shows qwen3:32b

## Open WebUI

- [ ] Container running: `sudo docker ps | grep open-webui` shows Up
- [ ] HTTP accessible: `curl -s -o /dev/null -w "%{http_code}" http://ai.local` = 200 or 302
- [ ] Data persisted: `ls /mnt/ai-models/open-webui/` has files
- [ ] Connected to Ollama: Models appear in WebUI dropdown

## Python Environments

- [ ] Open Interpreter: `/mnt/ai-models/open-interpreter-env/bin/activate` exists
- [ ] Qwen-Agent: `/mnt/ai-models/qwen-agent-env/bin/activate` exists
- [ ] Open Interpreter works:
  ```bash
  source /mnt/ai-models/open-interpreter-env/bin/activate
  python3 -c "import interpreter; print('OK')"
  deactivate
  ```
- [ ] Qwen-Agent works:
  ```bash
  source /mnt/ai-models/qwen-agent-env/bin/activate
  python3 -c "import qwen_agent; print('OK')"
  deactivate
  ```

## Network

- [ ] Static IP assigned: `ip addr` shows 192.168.29.100 (or your configured IP)
- [ ] Internet access: `ping -c 2 8.8.8.8` succeeds
- [ ] DNS works: `ping -c 2 google.com` succeeds
- [ ] UFW active: `sudo ufw status` = active
- [ ] SSH rule: `sudo ufw status` shows 22/tcp ALLOW
- [ ] Ollama LAN rule: `sudo ufw status` shows 11434/tcp ALLOW from LAN
- [ ] WebUI rule: `sudo ufw status` shows 3000/tcp ALLOW
- [ ] mDNS rule: `sudo ufw status` shows 5353/udp ALLOW

## Security

- [ ] NVIDIA auto-update blocked: `cat /etc/apt/apt.conf.d/51unattended-upgrades-nvidia` shows blacklist
- [ ] Passwordless sudo configured (for automation): `sudo -n whoami` = root
- [ ] Docker group: `groups` includes docker (after re-login)

## Inference Verification

- [ ] Generate test: `ollama run qwen3:32b "Say hello in one sentence"` responds
- [ ] Speed test: `bash ~/scripts/test-inference.sh` shows 30+ tok/s
- [ ] VRAM usage: `nvidia-smi` shows ~20 GB used when model loaded
- [ ] From another machine: `curl http://ai.local:11434/api/tags` responds

---

## After Network Change

When moving to a new network, re-verify:

- [ ] Run: `bash ~/scripts/change-network.sh`
- [ ] New IP assigned and reachable
- [ ] Firewall updated for new subnet
- [ ] Ollama API accessible from LAN
- [ ] Open WebUI accessible from LAN
- [ ] SSH accessible from LAN
- [ ] Internet connectivity works

---

## After Reboot

Quick check after any reboot:

```bash
bash ~/scripts/test-system.sh
```

Specifically verify these (they require persistence services):
- [ ] GPU clocks locked (nvidia-clock-setup.service)
- [ ] Power profile = performance (power-profile-performance.service)
- [ ] THP = always (tmpfiles.d/thp.conf)
- [ ] 2nd SSD mounted (fstab)
- [ ] Ollama running with correct config
- [ ] Open WebUI container auto-started
