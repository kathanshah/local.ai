# Rebuild Guide

Step-by-step instructions to rebuild this server from a fresh Ubuntu install. Follow in order.

For exact hardware/software specs this was tested on, see [hardware.md](hardware.md).

---

## Prerequisites

- Fresh Ubuntu 24.04 LTS installed on Disk 1 (NVMe SSD)
- Disk 2 (NVMe SSD) available for /mnt/ai-models
- NVIDIA GPU with proprietary drivers installed (`nvidia-smi` works)
- Internet connection
- User account created (e.g., `k-server`)

---

## Phase 1: Install Packages

```bash
sudo apt update && sudo apt install -y \
  git build-essential cmake python3-pip python3-venv \
  docker.io docker-compose-v2 \
  openssh-server htop btop iotop \
  curl wget jq unzip \
  nginx-light avahi-daemon
```

Add user to docker group:
```bash
sudo usermod -aG docker $USER
```

---

## Phase 2: Disable Unnecessary Services

```bash
sudo systemctl disable --now cups bluetooth snapd thermald
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### CPU Performance Mode

```bash
sudo powerprofilesctl set performance
```

Create persistent service:
```bash
sudo tee /etc/systemd/system/power-profile-performance.service << 'EOF'
[Unit]
Description=Set power profile to performance
After=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/bin/powerprofilesctl set performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable power-profile-performance
```

---

## Phase 3: Mount 2nd SSD

Find the disk UUID:
```bash
sudo blkid   # Find UUID of the 2nd NVMe (e.g., nvme0n1p1)
```

Format if new (skip if already has data):
```bash
sudo mkfs.ext4 /dev/nvme0n1p1
```

Mount:
```bash
sudo mkdir -p /mnt/ai-models
echo 'UUID=<your-uuid> /mnt/ai-models ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab
sudo mount -a
sudo chmod 755 /mnt/ai-models
```

Add noatime to root and home in `/etc/fstab` too.

Create directory structure:
```bash
sudo mkdir -p /mnt/ai-models/{ollama,open-webui}
sudo chown ollama:ollama /mnt/ai-models/ollama
```

---

## Phase 4: Kernel Tuning

```bash
sudo tee /etc/sysctl.d/99-ai-server.conf << 'EOF'
vm.swappiness=10
kernel.shmmax=137438953472
kernel.shmall=33554432
vm.overcommit_memory=0
vm.dirty_ratio=40
vm.dirty_background_ratio=10
vm.max_map_count=2097152
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
EOF
sudo sysctl --system
```

### Ulimits

```bash
sudo tee /etc/security/limits.d/99-ai-inference.conf << 'EOF'
*    soft    memlock    unlimited
*    hard    memlock    unlimited
*    soft    nofile     1048576
*    hard    nofile     1048576
EOF
```

### THP

```bash
sudo tee /etc/tmpfiles.d/thp.conf << 'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - always
EOF
echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

### Journald Cap

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/size.conf << 'EOF'
[Journal]
SystemMaxUse=500M
EOF
sudo systemctl restart systemd-journald
```

### Block NVIDIA Auto-Updates

```bash
sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-nvidia << 'EOF'
Unattended-Upgrade::Package-Blacklist {
    "nvidia-";
    "libnvidia-";
    "cuda-";
};
EOF
```

---

## Phase 5: GPU Optimization

```bash
# Enable persistence mode
sudo nvidia-smi -pm 1

# Lock clocks (adjust values for your GPU)
sudo nvidia-smi --lock-gpu-clocks=2407,3090
sudo nvidia-smi --lock-memory-clocks=14001
```

Create persistent service:
```bash
sudo tee /etc/systemd/system/nvidia-clock-setup.service << 'EOF'
[Unit]
Description=Lock NVIDIA GPU clocks for inference
After=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi --lock-gpu-clocks=2407,3090
ExecStart=/usr/bin/nvidia-smi --lock-memory-clocks=14001
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable nvidia-clock-setup
```

---

## Phase 6: Install Ollama + Model

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Configure Ollama:
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_MODELS=/mnt/ai-models/ollama"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
LimitMEMLOCK=infinity
LimitNOFILE=1048576
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Pull the model:
```bash
ollama pull qwen3:32b
```

---

## Phase 7: Open WebUI (Stocky AI)

Create custom entrypoint for branding:
```bash
cat > /mnt/ai-models/open-webui/custom-entrypoint.sh << 'SCRIPT'
#!/bin/bash
sed -i 's/WEBUI_NAME += " (Open WebUI)"/pass  # branding removed/' /app/backend/open_webui/env.py 2>/dev/null
exec /app/backend/start.sh "$@"
SCRIPT
chmod +x /mnt/ai-models/open-webui/custom-entrypoint.sh
```

Run the container:
```bash
sudo docker run -d --name open-webui --restart always \
  -p 3000:8080 \
  -v /mnt/ai-models/open-webui:/app/backend/data \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -e WEBUI_NAME="Stocky AI" \
  -e DEFAULT_MODELS="qwen3:32b" \
  -e ENABLE_SIGNUP=false \
  -e ENABLE_COMMUNITY_SHARING=false \
  -e ENABLE_MESSAGE_RATING=false \
  -e DEFAULT_USER_ROLE=user \
  --entrypoint /app/backend/data/custom-entrypoint.sh \
  ghcr.io/open-webui/open-webui:main
```

### Python Environments (optional)

```bash
# Open Interpreter
python3 -m venv /mnt/ai-models/open-interpreter-env
source /mnt/ai-models/open-interpreter-env/bin/activate
pip install open-interpreter "setuptools<81"
deactivate

# Qwen-Agent
python3 -m venv /mnt/ai-models/qwen-agent-env
source /mnt/ai-models/qwen-agent-env/bin/activate
pip install "qwen-agent[gui,rag,code-interpreter,mcp]" soundfile
deactivate
```

---

## Phase 8: Network + Firewall

### Set Hostname

```bash
sudo hostnamectl set-hostname ai
sudo sed -i 's/127.0.1.1.*/127.0.1.1 ai/' /etc/hosts
```

### Avahi (mDNS for ai.local)

```bash
# Exclude Docker interface from mDNS
sudo sed -i 's/#deny-interfaces=.*/deny-interfaces=docker0/' /etc/avahi/avahi-daemon.conf
sudo systemctl enable --now avahi-daemon
```

### Static IP (adjust for your network)

```bash
bash scripts/change-network.sh
# Or non-interactive:
# bash scripts/change-network.sh --wifi "SSID" "password" 192.168.X.100/24 192.168.X.1
```

### Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp                                                    # SSH
sudo ufw allow from 192.168.29.0/24 to any port 11434 proto tcp         # Ollama (LAN)
sudo ufw allow from 172.17.0.0/16 to any port 11434 proto tcp           # Ollama (Docker)
sudo ufw allow 80/tcp comment "Open WebUI via ai.local"                  # HTTP
sudo ufw allow 5353/udp comment "mDNS - ai.local name resolution"       # mDNS
sudo ufw enable
```

### Nginx Reverse Proxy

```bash
sudo tee /etc/nginx/sites-available/ai-server << 'EOF'
server {
    listen 80 default_server;
    server_name ai.local;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/ai-server /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

### Passwordless Sudo (for automation)

```bash
sudo visudo
# Add: k-server ALL=(ALL) NOPASSWD:ALL
```

---

## Phase 9: Configure Stocky AI Branding

After first login (admin account), configure via API:

```bash
# Login
TOKEN=$(curl -s http://localhost:3000/api/v1/auths/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"YOUR_EMAIL","password":"YOUR_PASSWORD"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Set default model and suggestions
curl -s -X POST http://localhost:3000/api/v1/configs/import \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "ui": {
        "enable_signup": false,
        "default_models": "qwen3:32b",
        "default_prompt_suggestions": [
          {"title": ["Draft a professional email", "for a client or team update"], "content": "Draft a professional email to the team about a project milestone update. Keep it concise and positive."},
          {"title": ["Analyze my spreadsheet", "formulas, pivot tables, or insights"], "content": "I need help with a spreadsheet task. Let me describe what I need and you can help me with the right formula or approach."},
          {"title": ["Summarize a document", "and extract key action items"], "content": "Summarize the following document and extract the key action items, deadlines, and decisions made."},
          {"title": ["Review a contract", "and flag risks or key clauses"], "content": "Review the following contract text and highlight key clauses, potential risks, and anything I should negotiate."},
          {"title": ["Research a topic", "and give me a structured brief"], "content": "Research the following topic and provide a structured brief with key findings, pros/cons, and recommendations."},
          {"title": ["Write a business proposal", "outline with clear structure"], "content": "Help me create a structured business proposal outline. I will provide the project details."}
        ]
      }
    }
  }'

# Set model name, description, system prompt, and parameters
curl -s -X POST http://localhost:3000/api/v1/models/model/update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "qwen3:32b",
    "name": "Stocky",
    "meta": {
      "description": "Your in-house AI that knows its way around a spreadsheet and a good pun",
      "capabilities": {"file_context":true,"vision":true,"file_upload":true,"web_search":true,"image_generation":false,"code_interpreter":true,"citations":true,"status_updates":true,"builtin_tools":true},
      "suggestion_prompts": [
        {"title":["Draft a professional email","for a client or team update"],"content":"Draft a professional email to the team about a project milestone update."},
        {"title":["Analyze my spreadsheet","formulas, pivot tables, or insights"],"content":"I need help with a spreadsheet task."},
        {"title":["Summarize a document","and extract key action items"],"content":"Summarize the following document and extract the key action items."},
        {"title":["Review a contract","and flag risks or key clauses"],"content":"Review the following contract text and highlight key clauses and risks."},
        {"title":["Research a topic","and give me a structured brief"],"content":"Research the following topic and provide a structured brief."},
        {"title":["Write a business proposal","outline with clear structure"],"content":"Help me create a structured business proposal outline."}
      ]
    },
    "params": {
      "system": "You are Stocky, an AI assistant built for business productivity. You are helpful, sharp, and professional — but you have a dry sense of humor and are not afraid to crack a clever joke when the moment is right.\n\nKeep responses clear, concise, and actionable. Use bullet points and headings to structure longer answers. When drafting emails, documents, or proposals, match the appropriate tone for the context — formal for clients, relaxed for internal comms.\n\nYou are great with spreadsheets, data analysis, writing, research, and reviewing contracts. If something is ambiguous, ask a quick clarifying question rather than guessing.\n\nNever mention that you are an AI model, what model you are, or technical details about how you work. You are simply Stocky — the office assistant who actually gets things done (and occasionally gets a laugh).",
      "temperature": 0.7,
      "top_p": 0.9,
      "num_ctx": 32768
    }
  }'
```

---

## Phase 10: Verify

```bash
bash scripts/test-system.sh    # Should show 41 passed, 0 failed
bash scripts/test-inference.sh  # Should show 15+ tok/s
```

Open http://ai.local — should show "Stocky AI" with the model "Stocky" ready.

---

## BIOS (do on next reboot)

- Enter BIOS (DEL/F2 at boot)
- Enable XMP/EXPO memory profile
- Verify ReBAR is enabled
