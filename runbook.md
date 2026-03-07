# AI Server — Runbook

## Quick Access

| What | URL / Command |
|---|---|
| Open WebUI (browser chat) | http://ai.local |
| Ollama API | http://ai.local:11434 |
| SSH | `ssh k-server@ai.local` |
| System test | `bash ~/scripts/test-system.sh` |
| Inference test | `bash ~/scripts/test-inference.sh` |
| Status dashboard | `bash ~/scripts/service-status.sh` |
| Change network | `bash ~/scripts/change-network.sh` |
| Backup configs | `bash ~/scripts/backup-config.sh` |

---

## Daily Operations

### Start the AI stack (after reboot)
Everything auto-starts on boot. If something isn't running:
```bash
sudo systemctl start ollama
sudo docker start open-webui
```

### Check everything is working
```bash
bash ~/scripts/service-status.sh
```

### View logs
```bash
# Ollama logs (live)
journalctl -u ollama -f

# Open WebUI logs (live)
sudo docker logs -f open-webui

# GPU stats (live, refreshes every 1s)
watch -n1 nvidia-smi
```

---

## Model Management

### List installed models
```bash
ollama list
```

### Pull a new model
```bash
ollama pull <model-name>
# Example: ollama pull qwen3:32b
```

### Remove a model
```bash
ollama rm <model-name>
```

### Test a model from CLI
```bash
ollama run qwen3:32b "Your prompt here"
```

### Check model storage usage
```bash
du -sh /mnt/ai-models/ollama/
```

---

## Open Interpreter (Excel/file operations)

### Start Open Interpreter
```bash
source /mnt/ai-models/open-interpreter-env/bin/activate
interpreter --api_base http://localhost:11434/v1 --api_key fake_key --model qwen3:32b
```

### Example tasks
- "Open /path/to/file.xlsx and show total revenue by quarter"
- "Create a new spreadsheet with monthly expense categories"
- "Read the PDF at /path/to/contract.pdf and summarize key terms"

### Exit
Type `exit` or press Ctrl+D, then `deactivate` to leave the venv.

---

## Qwen-Agent (agentic workflows)

### Activate environment
```bash
source /mnt/ai-models/qwen-agent-env/bin/activate
```

### Run with Gradio GUI
```python
python3 -c "
from qwen_agent.agents import Assistant
bot = Assistant(llm={'model': 'qwen3:32b', 'model_server': 'http://localhost:11434/v1', 'api_key': 'fake'})
# Use bot.run() for programmatic access
"
```

---

## Network Operations

### Change network (interactive)
```bash
bash ~/scripts/change-network.sh
```

### Quick WiFi change (non-interactive)
```bash
bash ~/scripts/change-network.sh --wifi "NewSSID" "password" 192.168.X.100/24 192.168.X.1
```

### Quick Ethernet setup
```bash
bash ~/scripts/change-network.sh --ethernet enp131s0 192.168.X.100/24 192.168.X.1
```

### Temporary DHCP (debugging)
```bash
bash ~/scripts/change-network.sh --dhcp
```

### After any network change, verify:
```bash
ping -c 2 8.8.8.8                          # Internet
ping -c 1 ai.local                         # mDNS name resolution
curl -s http://ai.local:11434/api/tags     # Ollama via hostname
curl -s http://ai.local               # WebUI via hostname
sudo ufw status                            # Firewall rules
```

### Manual firewall update (if change-network.sh didn't do it)
```bash
# Remove old LAN rule (check rule number first)
sudo ufw status numbered
sudo ufw delete <rule_number>

# Add for new subnet
sudo ufw allow from 192.168.X.0/24 to any port 11434 proto tcp
```

---

## Troubleshooting

### Ollama not responding
```bash
sudo systemctl status ollama
journalctl -u ollama --no-pager -n 30
sudo systemctl restart ollama
```

### Open WebUI not loading
```bash
sudo docker ps -a | grep open-webui     # Check container status
sudo docker logs open-webui --tail 30    # Check logs
sudo docker restart open-webui           # Restart
```

### Open WebUI can't reach Ollama
Check that Ollama is bound to 0.0.0.0:
```bash
grep OLLAMA_HOST /etc/systemd/system/ollama.service.d/override.conf
# Should show: OLLAMA_HOST=0.0.0.0:11434
curl http://localhost:11434/api/tags     # Test locally
```

### GPU not detected / low performance
```bash
nvidia-smi                               # Check GPU status
sudo systemctl restart nvidia-clock-setup # Re-apply clock settings
nvidia-smi -q | grep "Persistence Mode"  # Should be Enabled
```

### Model generation is slow
```bash
# Check if model fits in VRAM
nvidia-smi                               # memory.used should be ~20GB for qwen3:32b
# Check CPU governor
powerprofilesctl get                     # Should be: performance
# Check if swapping
free -h                                  # Swap usage should be near 0
```

### Permission denied on /mnt/ai-models
```bash
ls -la /mnt/ai-models                   # Check permissions
sudo chmod 755 /mnt/ai-models           # Fix if needed
sudo chown ollama:ollama /mnt/ai-models/ollama  # Ollama dir ownership
```

### ai.local not resolving from other machines
```bash
# On the server — check avahi is running and firewall allows mDNS
sudo systemctl status avahi-daemon
sudo ufw status | grep 5353     # Must show 5353/udp ALLOW
# Restart if needed
sudo systemctl restart avahi-daemon

# Verify hostname
hostname                                 # Should show: ai

# Check avahi is not broadcasting docker IP
avahi-resolve -n ai.local                # Should show LAN IP, not 172.17.x.x

# If docker IP shows, check avahi config
grep deny-interfaces /etc/avahi/avahi-daemon.conf
# Should show: deny-interfaces=docker0
```

**Client-side fixes:**
- **Mac/Linux**: Should work automatically. Try `ping ai.local`
- **Windows 10/11**: mDNS built in. If not working, try `ping ai.local` in cmd
- **Older Windows**: Install Bonjour Print Services from Apple
- **Fallback**: Use IP directly — `http://192.168.29.100:3000`

### After reboot, clocks not locked
```bash
sudo systemctl status nvidia-clock-setup  # Check service
sudo systemctl restart nvidia-clock-setup # Manually trigger
nvidia-smi --query-gpu=clocks.current.graphics,clocks.current.memory --format=csv
```

---

## Maintenance

### Update Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl restart ollama
```

### Update Open WebUI
```bash
sudo docker pull ghcr.io/open-webui/open-webui:main
sudo docker stop open-webui && sudo docker rm open-webui
sudo docker run -d --name open-webui --restart always \
  -p 3000:8080 \
  -v /mnt/ai-models/open-webui:/app/backend/data \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  ghcr.io/open-webui/open-webui:main
```

### Update Python environments
```bash
# Open Interpreter
source /mnt/ai-models/open-interpreter-env/bin/activate
pip install --upgrade open-interpreter
deactivate

# Qwen-Agent
source /mnt/ai-models/qwen-agent-env/bin/activate
pip install --upgrade "qwen-agent[gui,rag,code-interpreter,mcp]"
deactivate
```

### System updates (safe — NVIDIA excluded)
```bash
sudo apt update && sudo apt upgrade -y
# NVIDIA packages are blacklisted from auto-updates
# To manually update NVIDIA: sudo apt install nvidia-driver-XXX
```

### Backup configuration
```bash
bash ~/scripts/backup-config.sh
```

---

## 256 GB RAM Upgrade

When ready:
1. Power off, install 2x128GB DDR5 sticks
2. Boot into BIOS, enable XMP/EXPO profile
3. Boot into Ubuntu
4. Verify: `free -h` (should show ~252 GB)
5. Pull heavy model: `ollama pull qwen3:235b-a22b` (~142 GB download)
6. Model appears automatically in Open WebUI model dropdown

---

## Key File Locations

| File | Purpose |
|---|---|
| `/etc/systemd/system/ollama.service.d/override.conf` | Ollama config (model dir, host, ulimits) |
| `/etc/sysctl.d/99-ai-server.conf` | Kernel tuning |
| `/etc/security/limits.d/99-ai-inference.conf` | User ulimits |
| `/etc/systemd/system/nvidia-clock-setup.service` | GPU clock persistence |
| `/etc/systemd/system/power-profile-performance.service` | CPU performance mode persistence |
| `/etc/tmpfiles.d/thp.conf` | THP persistence |
| `/etc/apt/apt.conf.d/51unattended-upgrades-nvidia` | NVIDIA update block |
| `/etc/systemd/journald.conf.d/size.conf` | Journal size cap |
| `/etc/avahi/avahi-daemon.conf` | mDNS config (ai.local broadcasting) |
| `/etc/hostname` | Server hostname (ai) |
| `/mnt/ai-models/ollama/` | Model weights |
| `/mnt/ai-models/open-webui/` | WebUI data |
| `~/scripts/` | All management scripts |
| `~/todo.md` | Original setup plan |
