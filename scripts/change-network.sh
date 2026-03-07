#!/bin/bash
# AI Server — Network Change Script
# Use when moving the server to a different network.
#
# Usage:
#   bash ~/scripts/change-network.sh                    # Interactive mode
#   bash ~/scripts/change-network.sh --wifi "SSID" "password" 192.168.1.100/24 192.168.1.1
#   bash ~/scripts/change-network.sh --ethernet enp131s0 192.168.1.100/24 192.168.1.1
#   bash ~/scripts/change-network.sh --dhcp              # Switch to DHCP (temporary)

set -euo pipefail

# Current state
echo "========================================"
echo " Network Change Tool"
echo " $(date)"
echo "========================================"
echo ""
echo "Current connections:"
nmcli -t -f NAME,TYPE,DEVICE,STATE con show --active 2>/dev/null || echo "  (none active)"
echo ""
echo "Current IPs:"
ip -4 addr show | grep -E "inet " | grep -v 127.0.0.1 | awk '{print "  " $NF ": " $2}'
echo ""

update_firewall() {
    local SUBNET=$1
    echo ""
    echo "Updating firewall for new subnet ${SUBNET}..."

    # Remove old LAN-only Ollama rule (find the rule number)
    RULE_NUM=$(sudo ufw status numbered 2>/dev/null | grep "11434" | grep -oP '^\[\s*\K\d+' | head -1)
    if [[ -n "$RULE_NUM" ]]; then
        echo "y" | sudo ufw delete $RULE_NUM 2>/dev/null
    fi

    # Add new LAN-only rule
    sudo ufw allow from "${SUBNET}" to any port 11434 proto tcp

    # Ensure mDNS is allowed (for ai.local)
    if ! sudo ufw status | grep -q "5353/udp"; then
        sudo ufw allow 5353/udp comment "mDNS - ai.local name resolution"
    fi

    echo "Firewall updated. Ollama API now allows: ${SUBNET}"
    sudo ufw status | grep -E "11434|3000|22|5353"
}

if [[ "${1:-}" == "--wifi" ]]; then
    SSID="${2:?Usage: --wifi SSID PASSWORD IP/CIDR GATEWAY}"
    PASSWORD="${3:?Missing password}"
    STATIC_IP="${4:?Missing IP (e.g., 192.168.1.100/24)}"
    GATEWAY="${5:?Missing gateway (e.g., 192.168.1.1)}"
    DNS="${6:-8.8.8.8,1.1.1.1}"

    echo "Connecting to WiFi: $SSID"
    echo "Static IP: $STATIC_IP, Gateway: $GATEWAY, DNS: $DNS"
    echo ""

    # Check if connection profile exists
    if nmcli con show "$SSID" &>/dev/null; then
        echo "Updating existing profile '$SSID'..."
        sudo nmcli con mod "$SSID" \
            ipv4.method manual \
            ipv4.addresses "$STATIC_IP" \
            ipv4.gateway "$GATEWAY" \
            ipv4.dns "$DNS" \
            wifi-sec.key-mgmt wpa-psk \
            wifi-sec.psk "$PASSWORD"
    else
        echo "Creating new WiFi profile '$SSID'..."
        sudo nmcli con add type wifi con-name "$SSID" ssid "$SSID" \
            wifi-sec.key-mgmt wpa-psk \
            wifi-sec.psk "$PASSWORD" \
            ipv4.method manual \
            ipv4.addresses "$STATIC_IP" \
            ipv4.gateway "$GATEWAY" \
            ipv4.dns "$DNS" \
            autoconnect yes
    fi

    sudo nmcli con up "$SSID"
    echo ""
    echo "Connected. Verifying..."
    sleep 2
    ip addr show | grep "$STATIC_IP" && echo "[OK] IP assigned" || echo "[WARN] IP not yet visible"

    SUBNET=$(echo "$STATIC_IP" | sed 's|\.[0-9]*/|.0/|')
    update_firewall "$SUBNET"

elif [[ "${1:-}" == "--ethernet" ]]; then
    IFACE="${2:?Usage: --ethernet INTERFACE IP/CIDR GATEWAY}"
    STATIC_IP="${3:?Missing IP (e.g., 192.168.1.100/24)}"
    GATEWAY="${4:?Missing gateway (e.g., 192.168.1.1)}"
    DNS="${5:-8.8.8.8,1.1.1.1}"
    CON_NAME="office-server"

    echo "Setting up Ethernet: $IFACE"
    echo "Static IP: $STATIC_IP, Gateway: $GATEWAY, DNS: $DNS"
    echo ""

    # Remove old profile if exists
    nmcli con show "$CON_NAME" &>/dev/null && sudo nmcli con delete "$CON_NAME" 2>/dev/null

    sudo nmcli con add type ethernet con-name "$CON_NAME" ifname "$IFACE" \
        ipv4.method manual \
        ipv4.addresses "$STATIC_IP" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS" \
        autoconnect yes

    sudo nmcli con up "$CON_NAME"
    echo ""
    echo "Connected. Verifying..."
    sleep 2
    ip addr show "$IFACE" | grep "$STATIC_IP" && echo "[OK] IP assigned" || echo "[WARN] IP not yet visible"

    SUBNET=$(echo "$STATIC_IP" | sed 's|\.[0-9]*/|.0/|')
    update_firewall "$SUBNET"

elif [[ "${1:-}" == "--dhcp" ]]; then
    echo "Switching active connection to DHCP..."
    ACTIVE_CON=$(nmcli -t -f NAME con show --active | head -1)
    if [[ -n "$ACTIVE_CON" ]]; then
        sudo nmcli con mod "$ACTIVE_CON" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
        sudo nmcli con up "$ACTIVE_CON"
        echo "Switched '$ACTIVE_CON' to DHCP."
        sleep 3
        echo "New IP:"
        ip -4 addr show | grep -E "inet " | grep -v 127.0.0.1 | awk '{print "  " $NF ": " $2}'
    else
        echo "[FAIL] No active connection found."
    fi

else
    # Interactive mode
    echo "Options:"
    echo "  1) Connect to WiFi with static IP"
    echo "  2) Connect via Ethernet with static IP"
    echo "  3) Switch to DHCP (temporary/debugging)"
    echo "  4) Show current network info only"
    echo ""
    read -p "Choose [1-4]: " CHOICE

    case $CHOICE in
        1)
            read -p "WiFi SSID: " SSID
            read -sp "WiFi Password: " PASSWORD; echo
            read -p "Static IP (e.g., 192.168.1.100/24): " STATIC_IP
            read -p "Gateway (e.g., 192.168.1.1): " GATEWAY
            read -p "DNS [8.8.8.8,1.1.1.1]: " DNS
            DNS=${DNS:-8.8.8.8,1.1.1.1}
            exec "$0" --wifi "$SSID" "$PASSWORD" "$STATIC_IP" "$GATEWAY" "$DNS"
            ;;
        2)
            echo "Available ethernet interfaces:"
            nmcli device | grep ethernet
            read -p "Interface (e.g., enp131s0): " IFACE
            read -p "Static IP (e.g., 192.168.1.100/24): " STATIC_IP
            read -p "Gateway (e.g., 192.168.1.1): " GATEWAY
            read -p "DNS [8.8.8.8,1.1.1.1]: " DNS
            DNS=${DNS:-8.8.8.8,1.1.1.1}
            exec "$0" --ethernet "$IFACE" "$STATIC_IP" "$GATEWAY" "$DNS"
            ;;
        3)
            exec "$0" --dhcp
            ;;
        4)
            echo "Interfaces:"
            nmcli device status
            echo ""
            echo "Connections:"
            nmcli con show
            echo ""
            echo "Routes:"
            ip route
            ;;
        *)
            echo "Invalid choice."
            exit 1
            ;;
    esac
fi

echo ""
echo "Restarting mDNS (ai.local)..."
sudo systemctl restart avahi-daemon
sleep 1
MDNS_CHECK=$(ping -c1 -W2 ai.local 2>/dev/null | grep -oP '\(\K[0-9.]+' | head -1)
if [[ -n "$MDNS_CHECK" ]]; then
    echo "[OK] ai.local resolves to $MDNS_CHECK"
else
    echo "[WARN] ai.local not resolving yet — may take a few seconds"
fi

echo ""
echo "Done. Test connectivity:"
echo "  ping -c 2 8.8.8.8"
echo "  curl -s http://ai.local:11434/api/tags"
echo "  curl -s http://ai.local"
