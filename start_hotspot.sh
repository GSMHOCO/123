#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

# Загружаем настройки
source config.env

# Файлы итоговых конфигов
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
DNSMASQ_CONF="/etc/dnsmasq.d/dankert-hotspot.conf"
NODOGSPLASH_CONF="/etc/nodogsplash/nodogsplash.conf"

render() {
  sed \
    -e "s|{{AP_IF}}|$AP_IF|g" \
    -e "s|{{SSID}}|$SSID|g" \
    -e "s|{{PASSPHRASE}}|$PASSPHRASE|g" \
    -e "s|{{AP_IP}}|$AP_IP|g" \
    -e "s|{{DHCP_RANGE_START}}|$DHCP_RANGE_START|g" \
    -e "s|{{DHCP_RANGE_END}}|$DHCP_RANGE_END|g" \
    -e "s|{{CLIENT_TIMEOUT}}|$CLIENT_TIMEOUT|g" \
    "$1"
}

echo "[*] Generating configs..."
render hostapd.tpl > /tmp/hostapd.conf
render dnsmasq.tpl > /tmp/dnsmasq.conf
render nodogsplash.tpl > /tmp/nodogsplash.conf

sudo cp /tmp/hostapd.conf "$HOSTAPD_CONF"
sudo cp /tmp/dnsmasq.conf "$DNSMASQ_CONF"
sudo cp /tmp/nodogsplash.conf "$NODOGSPLASH_CONF"

# Копируем splash.html и картинку
SPLASH_DIR="/var/run/nodogsplash"
sudo mkdir -p "$SPLASH_DIR"
sudo cp splash.html "$SPLASH_DIR/splash.html"
sudo cp "$PROMO_IMAGE" "$SPLASH_DIR/$(basename "$PROMO_IMAGE")"

# IP и NAT
sudo ip addr add "${AP_IP}/24" dev "$AP_IF" || true
sudo sysctl -w net.ipv4.ip_forward=1
sudo systemctl restart hostapd dnsmasq nodogsplash

sudo iptables -t nat -C POSTROUTING -o "$UPLINK" -j MASQUERADE 2>/dev/null || \
  sudo iptables -t nat -A POSTROUTING -o "$UPLINK" -j MASQUERADE
sudo iptables -C FORWARD -i "$UPLINK" -o "$AP_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  sudo iptables -A FORWARD -i "$UPLINK" -o "$AP_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -C FORWARD -i "$AP_IF" -o "$UPLINK" -j ACCEPT 2>/dev/null || \
  sudo iptables -A FORWARD -i "$AP_IF" -o "$UPLINK" -j ACCEPT

# Лимит скорости
sudo bash ./limit_speed.sh

echo "[+] Hotspot started! SSID: $SSID"
