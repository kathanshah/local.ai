# Runbook

Operational procedures for the local.ai server.

---

## Daily Operations

### Check status
```bash
bash scripts/service-status.sh
```

### Everything auto-starts on boot. If something isn't running:
```bash
sudo systemctl start ollama
sudo docker start open-webui
sudo systemctl start nginx
```

### View logs
```bash
journalctl -u ollama -f              # Ollama (live)
sudo docker logs -f open-webui       # Open WebUI (live)
watch -n1 nvidia-smi                 # GPU stats (live)
```

---

## Model Management

```bash
ollama list                          # List installed models
ollama pull <model-name>             # Download a model
ollama rm <model-name>               # Remove a model
ollama run qwen3:32b "Your prompt"   # Test from CLI
du -sh /mnt/ai-models/ollama/        # Check storage usage
```

---

## Open Interpreter (Excel/file operations)

### Start
```bash
source /mnt/ai-models/open-interpreter-env/bin/activate
interpreter --api_base http://localhost:11434/v1 --api_key fake_key --model qwen3:32b
```

### Example tasks
- "Open /path/to/file.xlsx and show total revenue by quarter"
- "Create a new spreadsheet with monthly expense categories"
- "Read the PDF at /path/to/contract.pdf and summarize key terms"

### Exit
Type `exit` or Ctrl+D, then `deactivate` to leave the venv.

---

## Qwen-Agent (agentic workflows)

```bash
source /mnt/ai-models/qwen-agent-env/bin/activate
```

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
bash scripts/change-network.sh
```

### Non-interactive
```bash
# WiFi with static IP
bash scripts/change-network.sh --wifi "SSID" "password" 192.168.X.100/24 192.168.X.1

# Ethernet with static IP
bash scripts/change-network.sh --ethernet enp131s0 192.168.X.100/24 192.168.X.1

# Temporary DHCP
bash scripts/change-network.sh --dhcp
```

The script auto-updates firewall rules and restarts mDNS. After any change, verify:
```bash
ping -c 2 8.8.8.8                        # Internet
ping -c 1 ai.local                       # mDNS
curl -s http://ai.local                   # WebUI
curl -s http://ai.local:11434/api/tags    # Ollama API
```

### Manual firewall update (if needed)
```bash
sudo ufw status numbered                  # Find old LAN rule
sudo ufw delete <rule_number>
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
sudo docker ps -a | grep open-webui       # Check container
sudo docker logs open-webui --tail 30      # Check logs
sudo docker restart open-webui             # Restart
```

### Open WebUI can't reach Ollama / no models in dropdown
```bash
# Test from inside the container
sudo docker exec open-webui curl -s --max-time 5 http://host.docker.internal:11434/api/tags

# If that times out, UFW is blocking Docker→Ollama
sudo ufw allow from 172.17.0.0/16 to any port 11434 proto tcp comment "Docker containers to Ollama"

# Also verify Ollama is bound to all interfaces
grep OLLAMA_HOST /etc/systemd/system/ollama.service.d/override.conf
# Should show: OLLAMA_HOST=0.0.0.0:11434
```

### GPU not detected / low performance
```bash
nvidia-smi
sudo systemctl restart nvidia-clock-setup  # Re-apply clock settings
nvidia-smi -q | grep "Persistence Mode"   # Should be Enabled
```

### Model generation is slow
```bash
nvidia-smi                                 # VRAM should show ~29 GB for qwen3:32b
powerprofilesctl get                       # Should be: performance
free -h                                    # Swap should be near 0
```

### Permission denied on /mnt/ai-models
```bash
ls -la /mnt/ai-models
sudo chmod 755 /mnt/ai-models
sudo chown ollama:ollama /mnt/ai-models/ollama
```

### ai.local not resolving from other machines
```bash
# Check avahi and firewall
sudo systemctl status avahi-daemon
sudo ufw status | grep 5353               # Must show 5353/udp ALLOW
hostname                                   # Must show: ai

# Check avahi isn't broadcasting Docker IP
avahi-resolve -n ai.local                  # Should show LAN IP, not 172.17.x.x
grep deny-interfaces /etc/avahi/avahi-daemon.conf  # Should show docker0

# Restart if needed
sudo systemctl restart avahi-daemon
```

**Client-side:**
- **Mac/Linux**: Works automatically via mDNS
- **Windows 10/11**: mDNS built in — try `ping ai.local` in cmd
- **Older Windows**: Install Bonjour Print Services from Apple
- **Fallback**: Use IP directly — `http://192.168.29.100`

### After reboot, GPU clocks not locked
```bash
sudo systemctl status nvidia-clock-setup
sudo systemctl restart nvidia-clock-setup
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

### System updates (NVIDIA excluded)
```bash
sudo apt update && sudo apt upgrade -y
# NVIDIA packages are blacklisted from auto-updates
# To manually update NVIDIA: sudo apt install nvidia-driver-XXX
```

### Backup config
```bash
bash scripts/backup-config.sh
# Saves to /mnt/ai-models/backups/config-<timestamp>/
```

---

## 256 GB RAM Upgrade

1. Power off, install 2x 128 GB DDR5 sticks
2. Boot into BIOS → enable XMP/EXPO profile
3. Boot into Ubuntu
4. Verify: `free -h` (should show ~252 GB)
5. Pull model: `ollama pull qwen3:235b-a22b` (~142 GB download)
6. Model appears automatically in Open WebUI dropdown
