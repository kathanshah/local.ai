# Verification Checklist

Use after initial setup, reboots, or major changes. For automated checks run `bash scripts/test-system.sh`.

---

## Hardware

- [ ] GPU: `nvidia-smi` shows RTX 5090, 32 GB VRAM
- [ ] RAM: `free -h` shows 125+ GB (252+ after upgrade)
- [ ] CPU: `nproc` shows 24 cores
- [ ] Disk 2: `df -h /mnt/ai-models` shows 1.8T available
- [ ] ReBAR: `nvidia-smi -q | grep BAR1` shows 32768 MiB
- [ ] XMP enabled in BIOS (check manually)

## Disk & Filesystem

- [ ] 2nd SSD mounted: `mountpoint /mnt/ai-models`
- [ ] Persistent mount: `grep ai-models /etc/fstab` shows UUID-based entry
- [ ] noatime on root: `mount | grep " / "` includes noatime
- [ ] noatime on home: `mount | grep " /home "` includes noatime
- [ ] Correct ownership: `ls -la /mnt/ai-models/ollama` shows ollama:ollama
- [ ] Directories exist:
  - [ ] `/mnt/ai-models/ollama/`
  - [ ] `/mnt/ai-models/open-webui/`
  - [ ] `/mnt/ai-models/open-interpreter-env/`
  - [ ] `/mnt/ai-models/qwen-agent-env/`

## Kernel & Memory

- [ ] swappiness: `sysctl vm.swappiness` = 10
- [ ] max_map_count: `sysctl vm.max_map_count` = 2097152
- [ ] overcommit_memory: `sysctl vm.overcommit_memory` = 0
- [ ] THP: `cat /sys/kernel/mm/transparent_hugepage/enabled` shows [always]
- [ ] memlock: `ulimit -l` = unlimited
- [ ] nofile: `ulimit -n` = 1048576
- [ ] Journald: `journalctl --disk-usage` < 500M

## CPU & Power

- [ ] Power profile: `powerprofilesctl get` = performance
- [ ] Energy pref: `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` = performance
- [ ] Turbo: `cat /sys/devices/system/cpu/intel_pstate/no_turbo` = 0
- [ ] Boot service: `systemctl is-enabled power-profile-performance` = enabled

## GPU

- [ ] Persistence mode: `nvidia-smi -q | grep "Persistence Mode"` = Enabled
- [ ] GPU clock: `nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader` >= 2400 MHz
- [ ] Memory clock: `nvidia-smi --query-gpu=clocks.current.memory --format=csv,noheader` = 14001 MHz
- [ ] Clock service: `systemctl is-enabled nvidia-clock-setup` = enabled
- [ ] Power limit: `nvidia-smi -q | grep "Current Power Limit"` = 575W

## Services — Should be DISABLED

- [ ] cups: `systemctl is-active cups` = inactive
- [ ] bluetooth: `systemctl is-active bluetooth` = inactive
- [ ] snapd: `systemctl is-active snapd` = inactive
- [ ] thermald: `systemctl is-active thermald` = inactive
- [ ] sleep: `systemctl is-enabled sleep.target` = masked

## Services — Should be RUNNING

- [ ] ollama: `systemctl is-active ollama` = active
- [ ] docker: `systemctl is-active docker` = active
- [ ] ssh: `systemctl is-active ssh` = active
- [ ] nginx: `systemctl is-active nginx` = active
- [ ] nvidia-persistenced: `systemctl is-active nvidia-persistenced` = active
- [ ] avahi-daemon: `systemctl is-active avahi-daemon` = active

## Docker Containers — Should be RUNNING

- [ ] open-webui: `sudo docker ps | grep open-webui` shows Up (healthy)
- [ ] searxng: `sudo docker ps | grep searxng` shows Up

## Hostname & mDNS

- [ ] Hostname: `hostname` = ai
- [ ] mDNS resolves: `ping -c1 ai.local` responds with LAN IP (not 172.17.x.x)
- [ ] Avahi excludes Docker: `grep deny-interfaces /etc/avahi/avahi-daemon.conf` shows docker0
- [ ] UFW mDNS rule: `sudo ufw status | grep 5353` shows 5353/udp ALLOW
- [ ] WebUI via hostname: `curl -s http://ai.local` responds
- [ ] Ollama via hostname: `curl -s http://ai.local:11434/api/tags` responds

## Ollama

- [ ] API responds: `curl -s http://localhost:11434/api/tags` returns JSON
- [ ] Bound to all interfaces: `grep OLLAMA_HOST /etc/systemd/system/ollama.service.d/override.conf` = 0.0.0.0:11434
- [ ] Models on 2nd SSD: `grep OLLAMA_MODELS /etc/systemd/system/ollama.service.d/override.conf` = /mnt/ai-models/ollama
- [ ] Memlock: `grep LimitMEMLOCK /etc/systemd/system/ollama.service.d/override.conf` = infinity
- [ ] File descriptors: `grep LimitNOFILE /etc/systemd/system/ollama.service.d/override.conf` = 1048576
- [ ] Qwen3-32B available: `ollama list` shows qwen3:32b

## Open WebUI (Stocky AI)

- [ ] Container running: `sudo docker ps | grep open-webui` shows Up (healthy)
- [ ] HTTP accessible: `curl -s -o /dev/null -w "%{http_code}" http://ai.local` = 200 or 302
- [ ] Data persisted: `ls /mnt/ai-models/open-webui/` has files
- [ ] Docker→Ollama: `sudo docker exec open-webui curl -s http://host.docker.internal:11434/api/tags` returns JSON
- [ ] App name: shows "Stocky AI" (not "Open WebUI")
- [ ] Model name: shows "Stocky" in dropdown (not "qwen3:32b")
- [ ] Custom entrypoint: `ls /mnt/ai-models/open-webui/custom-entrypoint.sh` exists
- [ ] On `ai-net` network: `sudo docker inspect open-webui --format '{{json .NetworkSettings.Networks}}'` shows ai-net

## SearXNG (Web Search)

- [ ] Container running: `sudo docker ps | grep searxng` shows Up
- [ ] On `ai-net` network: `sudo docker inspect searxng --format '{{json .NetworkSettings.Networks}}'` shows ai-net
- [ ] JSON format enabled: `grep -A2 formats /mnt/ai-models/searxng/settings.yml` includes json
- [ ] Responds: `curl -s "http://localhost:8888/search?q=test&format=json" | python3 -c "import sys,json; print('OK' if json.load(sys.stdin).get('results') is not None else 'FAIL')"`
- [ ] Open WebUI can reach it: `sudo docker exec open-webui curl -s --max-time 5 "http://searxng:8080/search?q=test&format=json" | head -c 100`

## Nginx

- [ ] Running: `systemctl is-active nginx` = active
- [ ] Config test: `sudo nginx -t` = syntax ok
- [ ] Port 80 serving: `curl -s -o /dev/null -w "%{http_code}" http://localhost` = 200 or 302

## Python Environments

- [ ] Open Interpreter venv: `/mnt/ai-models/open-interpreter-env/bin/activate` exists
- [ ] Qwen-Agent venv: `/mnt/ai-models/qwen-agent-env/bin/activate` exists
- [ ] Open Interpreter imports:
  ```bash
  source /mnt/ai-models/open-interpreter-env/bin/activate
  python3 -c "import interpreter; print('OK')"
  deactivate
  ```
- [ ] Qwen-Agent imports:
  ```bash
  source /mnt/ai-models/qwen-agent-env/bin/activate
  python3 -c "import qwen_agent; print('OK')"
  deactivate
  ```

## Firewall (UFW)

- [ ] UFW active: `sudo ufw status` = active
- [ ] SSH: 22/tcp ALLOW
- [ ] Ollama LAN: 11434/tcp ALLOW from LAN subnet
- [ ] Ollama Docker bridge: 11434/tcp ALLOW from 172.17.0.0/16
- [ ] Ollama Docker ai-net: 11434/tcp ALLOW from 172.18.0.0/16
- [ ] HTTP: 80/tcp ALLOW
- [ ] mDNS: 5353/udp ALLOW

## Security

- [ ] NVIDIA auto-update blocked: `cat /etc/apt/apt.conf.d/51unattended-upgrades-nvidia`
- [ ] Passwordless sudo: `sudo -n whoami` = root
- [ ] Docker group: `groups` includes docker

## Inference

- [ ] Generate test: `ollama run qwen3:32b "Say hello in one sentence"`
- [ ] Speed test: `bash scripts/test-inference.sh` shows 15+ tok/s
- [ ] VRAM usage: `nvidia-smi` shows ~29 GB when model loaded
- [ ] From another machine: `curl http://ai.local:11434/api/tags` responds

---

## After Network Change

- [ ] Run `bash scripts/change-network.sh`
- [ ] New IP assigned and reachable
- [ ] Firewall updated for new subnet
- [ ] ai.local resolves from other machines
- [ ] Ollama API accessible from LAN
- [ ] Open WebUI accessible from LAN
- [ ] SSH accessible from LAN
- [ ] Internet works

## After Reboot

Run `bash scripts/test-system.sh` and specifically verify:
- [ ] GPU clocks locked (nvidia-clock-setup.service)
- [ ] Power profile = performance (power-profile-performance.service)
- [ ] THP = always (tmpfiles.d/thp.conf)
- [ ] 2nd SSD mounted (fstab)
- [ ] Ollama running with correct config
- [ ] Open WebUI container auto-started
- [ ] SearXNG container auto-started
- [ ] Nginx serving on port 80
