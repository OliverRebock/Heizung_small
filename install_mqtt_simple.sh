#!/bin/bash
# =============================================================================
# EINFACHES MQTT Installation Script - Ohne Interaktion
# =============================================================================

echo "🏠 Pi5 Heizungs Messer - Einfache MQTT Installation"
echo "=================================================="

# Feste Parameter setzen
HA_IP="${1:-192.168.1.100}"
MQTT_USER="${2:-}"
MQTT_PASS="${3:-}"

echo ""
echo "📋 Konfiguration:"
echo "   🏠 Home Assistant IP: $HA_IP"
echo "   📡 MQTT Broker: Pi5 (localhost)"
if [ -n "$MQTT_USER" ]; then
    echo "   🔐 MQTT Auth: $MQTT_USER"
else
    echo "   🔓 MQTT Auth: Keine"
fi
echo ""

# 1. MQTT BROKER INSTALLIEREN
echo "🚀 Installiere MQTT Broker..."
sudo apt update
sudo apt install -y mosquitto mosquitto-clients

# 2. MQTT KONFIGURATION
echo "⚙️ Konfiguriere MQTT..."
sudo systemctl stop mosquitto

# Mosquitto Config
sudo tee /etc/mosquitto/mosquitto.conf > /dev/null << 'EOF'
# MQTT Broker Konfiguration für Pi5 Heizungs Messer
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/
EOF

# Falls Authentication gewünscht
if [ -n "$MQTT_USER" ] && [ -n "$MQTT_PASS" ]; then
    echo "🔐 Aktiviere MQTT Authentifizierung..."
    sudo mosquitto_passwd -c -b /etc/mosquitto/passwd "$MQTT_USER" "$MQTT_PASS"
    sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null << 'EOF'
allow_anonymous false
password_file /etc/mosquitto/passwd
EOF
    echo "   ✅ User $MQTT_USER erstellt"
fi

# 3. MQTT SERVICE STARTEN
echo "🚀 Starte MQTT Service..."
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# Status prüfen
if sudo systemctl is-active --quiet mosquitto; then
    echo "   ✅ MQTT Broker läuft"
else
    echo "   ❌ MQTT Broker Problem"
    sudo systemctl status mosquitto
fi

# 4. PYTHON MQTT BRIDGE INSTALLIEREN
echo "📦 Installiere MQTT Bridge..."

# Prüfe ob pi5-sensors Verzeichnis existiert
if [ ! -d "$HOME/pi5-sensors" ]; then
    echo "❌ pi5-sensors Installation nicht gefunden!"
    echo "   Führe zuerst aus: curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
    exit 1
fi

cd "$HOME/pi5-sensors"

# MQTT Python Libraries installieren
source venv/bin/activate
pip install paho-mqtt influxdb-client

# 5. KONFIGURATION ERSTELLEN
echo "📝 Erstelle MQTT Konfiguration..."
cat >> config.ini << EOF

[mqtt]
broker = localhost
port = 1883
username = ${MQTT_USER}
password = ${MQTT_PASS}
topic_prefix = pi5_heizung

[homeassistant]
ip = ${HA_IP}
mqtt_discovery = true
EOF

echo "   ✅ config.ini aktualisiert"

# 6. MQTT BRIDGE SCRIPT HERUNTERLADEN
echo "📥 Lade MQTT Bridge Script..."
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py -o mqtt_bridge.py
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/setup_mqtt_service.sh -o setup_mqtt_service.sh
chmod +x setup_mqtt_service.sh

# 7. SERVICE INSTALLIEREN
echo "⚙️ Installiere MQTT Bridge Service..."
bash setup_mqtt_service.sh

echo ""
echo "🎉 MQTT Installation abgeschlossen!"
echo "=================================="
echo ""
echo "✅ Installiert:"
echo "   📡 Mosquitto MQTT Broker auf Pi5"
echo "   🌉 MQTT Bridge für Home Assistant"
echo "   🔄 Auto-Discovery aktiviert"
echo ""
echo "🌐 Zugriff:"
echo "   📡 MQTT Broker: $(hostname -I | awk '{print $1}'):1883"
echo "   🏠 Home Assistant: $HA_IP"
echo ""
echo "🔧 Befehle:"
echo "   MQTT Status:  sudo systemctl status mosquitto"
echo "   Bridge Status: sudo systemctl status pi5-mqtt-bridge"
echo "   Live Logs:    sudo journalctl -u pi5-mqtt-bridge -f"
echo "   Test MQTT:    mosquitto_sub -t 'pi5_heizung/+/state'"
echo ""
echo "📋 Nächste Schritte:"
echo "   1. Home Assistant MQTT Integration konfigurieren"
echo "   2. Broker IP: $(hostname -I | awk '{print $1}')"
echo "   3. Port: 1883"
if [ -n "$MQTT_USER" ]; then
    echo "   4. Username: $MQTT_USER"
    echo "   5. Passwort: $MQTT_PASS"
else
    echo "   4. Authentifizierung: Keine"
fi
echo "   → Sensoren werden automatisch erkannt!"
