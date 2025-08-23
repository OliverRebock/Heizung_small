#!/bin/bash
# Ultra-Simple MQTT Installation für Pi5 Heizungs Messer
set -e

echo "🏠 Pi5 MQTT Installation (Ultra-Simple)"
echo "======================================="

# Parameter
HA_IP="192.168.1.100"
echo "🏠 Home Assistant IP: $HA_IP"
echo "📡 MQTT Broker: Pi5 (localhost, ohne Auth)"
echo ""

# 1. Installiere MQTT
echo "📦 Installiere Mosquitto..."
sudo apt update
sudo apt install -y mosquitto mosquitto-clients

# 2. Einfache Config
echo "⚙️ Konfiguriere MQTT..."
sudo systemctl stop mosquitto

# Schreibe Config Zeile für Zeile
sudo bash -c 'cat > /etc/mosquitto/mosquitto.conf' << 'ENDCONFIG'
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/
ENDCONFIG

# 3. Starte MQTT
echo "🚀 Starte MQTT Service..."
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

if sudo systemctl is-active --quiet mosquitto; then
    echo "✅ MQTT Broker läuft"
else
    echo "❌ MQTT Problem"
    exit 1
fi

# 4. Prüfe ob pi5-sensors existiert
if [ ! -d "$HOME/pi5-sensors" ]; then
    echo "❌ pi5-sensors nicht gefunden!"
    echo "   Installiere zuerst: curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
    exit 1
fi

cd "$HOME/pi5-sensors"

# 5. Python Packages
echo "📦 Installiere Python MQTT..."
source venv/bin/activate
pip install paho-mqtt influxdb-client

# 6. Config erweitern
echo "📝 Aktualisiere config.ini..."
cat >> config.ini << 'ENDCONFIG'

[mqtt]
broker = localhost
port = 1883
username = 
password = 
topic_prefix = pi5_heizung

[homeassistant]
ip = 192.168.1.100
mqtt_discovery = true
ENDCONFIG

# 7. MQTT Bridge laden
echo "📥 Lade MQTT Bridge..."
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py -o mqtt_bridge.py
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/setup_mqtt_service.sh -o setup_mqtt_service.sh
chmod +x setup_mqtt_service.sh

# 8. Service installieren
echo "⚙️ Installiere Service..."
bash setup_mqtt_service.sh

echo ""
echo "🎉 FERTIG!"
echo "========="
echo ""
echo "✅ MQTT Broker: $(hostname -I | awk '{print $1}'):1883"
echo "✅ Home Assistant: $HA_IP"
echo "✅ Keine Authentifizierung"
echo ""
echo "🔧 Befehle:"
echo "   sudo systemctl status pi5-mqtt-bridge"
echo "   mosquitto_sub -t 'pi5_heizung/+/state'"
echo ""
echo "📋 Home Assistant Setup:"
echo "   MQTT Integration → Broker: $(hostname -I | awk '{print $1}')"
echo "   Port: 1883, Kein Username/Passwort"
