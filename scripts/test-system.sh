#!/bin/bash
# AI Server — Full System Test
# Run: bash ~/scripts/test-system.sh

set -uo pipefail
PASS=0; FAIL=0; WARN=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

echo "========================================"
echo " AI Server System Test"
echo " $(date)"
echo "========================================"

# --- Hardware ---
echo ""
echo "--- Hardware ---"

GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "NOT FOUND")
[[ "$GPU" == *"5090"* ]] && pass "GPU: $GPU" || fail "GPU not detected (got: $GPU)"

RAM_GB=$(free -g | awk '/Mem:/{print $2}')
[[ $RAM_GB -ge 120 ]] && pass "RAM: ${RAM_GB} GB" || fail "RAM too low: ${RAM_GB} GB (need 120+)"

CORES=$(nproc)
[[ $CORES -ge 24 ]] && pass "CPU cores: $CORES" || fail "CPU cores: $CORES (expected 24)"

# --- Disk ---
echo ""
echo "--- Disk ---"

if mountpoint -q /mnt/ai-models 2>/dev/null; then
    AVAIL=$(df -BG /mnt/ai-models | awk 'NR==2{print $4}' | tr -d 'G')
    pass "AI models disk mounted (/mnt/ai-models, ${AVAIL}G free)"
else
    fail "AI models disk NOT mounted at /mnt/ai-models"
fi

if grep -q noatime /proc/mounts | grep -q " / "; then
    pass "Root has noatime"
else
    mount | grep " / " | grep -q noatime && pass "Root has noatime" || warn "Root missing noatime"
fi

# --- Kernel Tuning ---
echo ""
echo "--- Kernel Tuning ---"

SWAP=$(sysctl -n vm.swappiness)
[[ $SWAP -eq 10 ]] && pass "vm.swappiness = $SWAP" || fail "vm.swappiness = $SWAP (expected 10)"

MMAP=$(sysctl -n vm.max_map_count)
[[ $MMAP -ge 2097152 ]] && pass "vm.max_map_count = $MMAP" || fail "vm.max_map_count = $MMAP (expected 2097152)"

THP=$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -o '\[.*\]' | tr -d '[]')
[[ "$THP" == "always" ]] && pass "THP = $THP" || warn "THP = $THP (expected always)"

# --- Power & CPU ---
echo ""
echo "--- Power & CPU ---"

PROFILE=$(powerprofilesctl get 2>/dev/null || echo "unknown")
[[ "$PROFILE" == "performance" ]] && pass "Power profile: $PROFILE" || fail "Power profile: $PROFILE (expected performance)"

EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo "unknown")
[[ "$EPP" == "performance" ]] && pass "Energy perf preference: $EPP" || warn "Energy perf preference: $EPP"

# --- GPU ---
echo ""
echo "--- GPU ---"

PM=$(nvidia-smi -q 2>/dev/null | grep "Persistence Mode" | awk '{print $NF}')
[[ "$PM" == "Enabled" ]] && pass "GPU persistence mode: $PM" || fail "GPU persistence mode: $PM"

GFX_CLK=$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
[[ $GFX_CLK -ge 2400 ]] && pass "GPU clock: ${GFX_CLK} MHz" || warn "GPU clock: ${GFX_CLK} MHz (expected 2400+)"

MEM_CLK=$(nvidia-smi --query-gpu=clocks.current.memory --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
[[ $MEM_CLK -ge 14000 ]] && pass "GPU memory clock: ${MEM_CLK} MHz" || warn "GPU memory clock: ${MEM_CLK} MHz (expected 14001)"

VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
[[ $VRAM -ge 32000 ]] && pass "VRAM: ${VRAM} MiB" || fail "VRAM: ${VRAM} MiB (expected 32768)"

BAR1=$(nvidia-smi -q 2>/dev/null | grep -A2 "BAR1" | grep "Total" | awk '{print $3}')
[[ "$BAR1" == "32768" ]] && pass "ReBAR: ${BAR1} MiB (full VRAM)" || warn "ReBAR: ${BAR1} MiB"

# --- Services ---
echo ""
echo "--- Services ---"

for svc in cups bluetooth thermald; do
    STATE=$(systemctl is-active $svc 2>/dev/null)
    [[ "$STATE" == "inactive" ]] && pass "$svc: disabled" || warn "$svc: $STATE (should be inactive)"
done

for svc in ssh ollama docker avahi-daemon; do
    STATE=$(systemctl is-active $svc 2>/dev/null || echo "inactive")
    [[ "$STATE" == "active" ]] && pass "$svc: running" || fail "$svc: $STATE (should be active)"
done

SLEEP=$(systemctl is-enabled sleep.target 2>/dev/null)
[[ "$SLEEP" == "masked" ]] && pass "Sleep targets: masked" || warn "Sleep targets: $SLEEP"

# --- Hostname & mDNS ---
echo ""
echo "--- Hostname & mDNS ---"

HNAME=$(hostname)
[[ "$HNAME" == "ai" ]] && pass "Hostname: $HNAME" || warn "Hostname: $HNAME (expected 'ai')"

MDNS_IP=$(getent ahosts ai.local 2>/dev/null | awk 'NR==1{print $1}')
if [[ -n "$MDNS_IP" ]] && [[ "$MDNS_IP" != 172.17.* ]]; then
    pass "mDNS ai.local resolves to $MDNS_IP"
else
    MDNS_IP2=$(ping -c1 -W2 ai.local 2>/dev/null | grep -oP '\(\K[0-9.]+' | head -1)
    if [[ -n "$MDNS_IP2" ]] && [[ "$MDNS_IP2" != 172.17.* ]]; then
        pass "mDNS ai.local resolves to $MDNS_IP2"
    else
        fail "mDNS ai.local not resolving to LAN IP (got: ${MDNS_IP:-none})"
    fi
fi

# --- Ollama ---
echo ""
echo "--- Ollama ---"

OLLAMA_API=$(curl -s --max-time 5 http://localhost:11434/api/tags 2>/dev/null)
if [[ -n "$OLLAMA_API" ]]; then
    pass "Ollama API responding"
    if echo "$OLLAMA_API" | grep -q "qwen3:32b"; then
        pass "Qwen3-32B model loaded"
    else
        warn "Qwen3-32B not yet available (may still be downloading)"
    fi
else
    fail "Ollama API not responding"
fi

OLLAMA_DIR=$(grep OLLAMA_MODELS /etc/systemd/system/ollama.service.d/override.conf 2>/dev/null | cut -d'"' -f2 | sed 's/OLLAMA_MODELS=//')
[[ "$OLLAMA_DIR" == "/mnt/ai-models/ollama" ]] && pass "Ollama models dir: $OLLAMA_DIR" || fail "Ollama models dir: $OLLAMA_DIR"

MEMLOCK=$(grep LimitMEMLOCK /etc/systemd/system/ollama.service.d/override.conf 2>/dev/null | cut -d= -f2)
[[ "$MEMLOCK" == "infinity" ]] && pass "Ollama memlock: unlimited" || fail "Ollama memlock: $MEMLOCK"

# --- Docker / Open WebUI ---
echo ""
echo "--- Open WebUI ---"

WEBUI=$(sudo docker ps --format '{{.Names}}:{{.Status}}' 2>/dev/null | grep open-webui || echo "")
if [[ -n "$WEBUI" ]]; then
    pass "Open WebUI container: running"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://ai.local 2>/dev/null)
    [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]] && pass "Open WebUI via ai.local: $HTTP_CODE" || warn "Open WebUI via ai.local: $HTTP_CODE"
else
    fail "Open WebUI container not running"
fi

NGINX_STATE=$(systemctl is-active nginx 2>/dev/null)
[[ "$NGINX_STATE" == "active" ]] && pass "Nginx reverse proxy: running" || fail "Nginx not running (ai.local won't work on port 80)"

# Check Docker→Ollama connectivity
DOCKER_OLLAMA=$(sudo docker exec open-webui curl -s --max-time 5 http://host.docker.internal:11434/api/tags 2>/dev/null)
if echo "$DOCKER_OLLAMA" | grep -q "models"; then
    pass "Docker→Ollama connectivity: OK"
else
    fail "Docker→Ollama blocked (check UFW rule for 172.17.0.0/16 → 11434)"
fi

# --- Python Environments ---
echo ""
echo "--- Python Environments ---"

if [[ -f /mnt/ai-models/open-interpreter-env/bin/activate ]]; then
    pass "Open Interpreter venv exists"
else
    fail "Open Interpreter venv missing"
fi

if [[ -f /mnt/ai-models/qwen-agent-env/bin/activate ]]; then
    pass "Qwen-Agent venv exists"
else
    fail "Qwen-Agent venv missing"
fi

# --- Network ---
echo ""
echo "--- Network ---"

IP=$(ip -4 addr show | grep -oP '192\.168\.\d+\.\d+' | head -1)
[[ -n "$IP" ]] && pass "LAN IP: $IP" || fail "No LAN IP found"

UFW=$(sudo ufw status 2>/dev/null | head -1)
[[ "$UFW" == *"active"* ]] && pass "UFW: active" || warn "UFW: $UFW"

SSH_RULE=$(sudo ufw status 2>/dev/null | grep "22/tcp" | head -1)
[[ -n "$SSH_RULE" ]] && pass "UFW SSH rule: present" || warn "UFW SSH rule: missing"

MDNS_RULE=$(sudo ufw status 2>/dev/null | grep "5353/udp" | head -1)
[[ -n "$MDNS_RULE" ]] && pass "UFW mDNS rule (5353/udp): present" || fail "UFW mDNS rule (5353/udp): missing — ai.local won't work from other machines"

# --- Security ---
echo ""
echo "--- Security ---"

if [[ -f /etc/apt/apt.conf.d/51unattended-upgrades-nvidia ]]; then
    pass "NVIDIA auto-update blocked"
else
    warn "NVIDIA auto-update block not configured"
fi

JRNL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[MG]' | head -1)
pass "Journald usage: $JRNL_SIZE"

# --- Summary ---
echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "========================================"

[[ $FAIL -eq 0 ]] && echo " System is READY." || echo " Fix $FAIL failure(s) before production use."
exit $FAIL
