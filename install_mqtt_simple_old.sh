#!/bin/bash
# =============================================================================
# EINFACHES MQTT Installation Script - Für Home Assistant
# =============================================================================

echo "🏠 Pi5 Heizungs Messer - MQTT für Home Assistant"
echo "==============================================="

# Parameter abfragen wenn nicht gegeben
HA_IP="${1}"
MQTT_USER="${2}"
MQTT_PASS="${3}"

if [ -z "$HA_IP" ]; then
    read -p "🏠 Home Assistant IP-Adresse: " HA_IP
fi

if [ -z "$MQTT_USER" ]; then
    read -p "� MQTT Username: " MQTT_USER
fi

if [ -z "$MQTT_PASS" ]; then
    echo -n "🔐 MQTT Passwort: "
    read -s MQTT_PASS
    echo ""
fi

echo ""
echo "📋 Konfiguration:"
echo "   🏠 Home Assistant: $HA_IP:1883"
echo "   � MQTT User: $MQTT_USER"
echo "   📡 Ziel: Home Assistant MQTT Broker"
echo ""

# 1. MQTT CLIENT INSTALLIEREN (KEIN lokaler Broker!)
echo "� Installiere MQTT Client..."
sudo apt update
sudo apt install -y mosquitto-clients

# Wir verwenden den MQTT Broker von Home Assistant!

# 2. MQTT KONFIGURATION
echo "⚙️ Konfiguriere MQTT..."
sudo systemctl stop mosquitto

# Mosquitto Config erstellen
echo "# MQTT Broker Konfiguration für Pi5 Heizungs Messer" | sudo tee /etc/mosquitto/mosquitto.conf > /dev/null
echo "listener 1883" | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null
echo "allow_anonymous true" | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null
echo "persistence true" | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null
echo "persistence_location /var/lib/mosquitto/" | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null

# Falls Authentication gewünscht
if [ -n "$MQTT_USER" ] && [ -n "$MQTT_PASS" ]; then
    echo "🔐 Aktiviere MQTT Authentifizierung..."
    sudo mosquitto_passwd -c -b /etc/mosquitto/passwd "$MQTT_USER" "$MQTT_PASS"
    echo "allow_anonymous false" | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null
    echo "password_file /etc/mosquitto/passwd" | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null
    echo "   ✅ User $MQTT_USER erstellt"
fi
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

# Config sicher erstellen
echo "" >> config.ini
echo "[mqtt]" >> config.ini
echo "broker = localhost" >> config.ini
echo "port = 1883" >> config.ini
echo "username = ${MQTT_USER}" >> config.ini
echo "password = ${MQTT_PASS}" >> config.ini
echo "topic_prefix = pi5_heizung" >> config.ini
echo "" >> config.ini
echo "[homeassistant]" >> config.ini
echo "ip = ${HA_IP}" >> config.ini
echo "mqtt_discovery = true" >> config.ini

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
