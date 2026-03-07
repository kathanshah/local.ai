#!/bin/bash
# AI Server — Quick service status dashboard
# Run: bash ~/scripts/service-status.sh

echo "========================================"
echo " AI Server Status — $(date '+%Y-%m-%d %H:%M')"
echo "========================================"

echo ""
echo "--- GPU ---"
nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "GPU not available"

echo ""
echo "--- Memory ---"
free -h | head -2

echo ""
echo "--- Disk ---"
df -h /mnt/ai-models / /home 2>/dev/null | awk 'NR==1 || /\// {print}'

echo ""
echo "--- Services ---"
printf "  %-25s %s\n" "Service" "Status"
printf "  %-25s %s\n" "-------" "------"
for svc in ollama docker ssh nginx avahi-daemon power-profiles-daemon nvidia-persistenced nvidia-clock-setup; do
    STATUS=$(systemctl is-active $svc 2>/dev/null || echo "unknown")
    printf "  %-25s %s\n" "$svc" "$STATUS"
done

echo ""
echo "--- Open WebUI ---"
sudo docker ps --format "  {{.Names}}: {{.Status}}" 2>/dev/null | grep open-webui || echo "  Not running"

echo ""
echo "--- Ollama Models ---"
ollama list 2>/dev/null || echo "  Ollama not responding"

echo ""
echo "--- Network ---"
echo "  Hostname: $(hostname).local"
ip -4 addr show | grep -E "inet " | grep -v 127.0.0.1 | awk '{print "  " $NF ": " $2}'
echo ""
echo "--- Access URLs ---"
echo "  Open WebUI:  http://ai.local"
echo "  Ollama API:  http://ai.local:11434"
echo "  SSH:         ssh k-server@ai.local"
