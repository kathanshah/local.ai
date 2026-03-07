#!/bin/bash
# AI Server — Backup all configuration files
# Run: bash ~/scripts/backup-config.sh

BACKUP_DIR="/mnt/ai-models/backups/config-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up server config to: $BACKUP_DIR"

# System configs
sudo cp /etc/fstab "$BACKUP_DIR/"
sudo cp /etc/sysctl.d/99-ai-server.conf "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/security/limits.d/99-ai-inference.conf "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/tmpfiles.d/thp.conf "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/apt/apt.conf.d/51unattended-upgrades-nvidia "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/systemd/journald.conf.d/size.conf "$BACKUP_DIR/" 2>/dev/null

# Systemd services
sudo cp /etc/systemd/system/nvidia-clock-setup.service "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/systemd/system/power-profile-performance.service "$BACKUP_DIR/" 2>/dev/null
sudo cp -r /etc/systemd/system/ollama.service.d "$BACKUP_DIR/" 2>/dev/null

# Nginx reverse proxy
sudo cp /etc/nginx/sites-available/ai-server "$BACKUP_DIR/" 2>/dev/null

# Avahi / mDNS
sudo cp /etc/avahi/avahi-daemon.conf "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/hostname "$BACKUP_DIR/" 2>/dev/null
sudo cp /etc/hosts "$BACKUP_DIR/" 2>/dev/null

# Network
nmcli con show > "$BACKUP_DIR/nmcli-connections.txt" 2>/dev/null
sudo ufw status verbose > "$BACKUP_DIR/ufw-rules.txt" 2>/dev/null

# Installed packages
dpkg --get-selections > "$BACKUP_DIR/installed-packages.txt"

# Scripts
cp -r ~/scripts "$BACKUP_DIR/scripts/" 2>/dev/null

echo "Backup complete: $(du -sh "$BACKUP_DIR" | awk '{print $1}')"
echo "Contents:"
ls -la "$BACKUP_DIR/"
