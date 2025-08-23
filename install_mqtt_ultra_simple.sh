#!/bin/bash
# Ultra-Simple MQTT Installation für Pi5 Heizungs Messer
set -e

echo "🏠 Pi5 MQTT Installation für Home Assistant"
echo "=========================================="

# Home Assistant Konfiguration abfragen
echo ""
echo "🏠 Home Assistant Konfiguration:"
read -p "   IP-Adresse von Home Assistant (z.B. 192.168.1.100): " HA_IP
if [ -z "$HA_IP" ]; then
    echo "❌ Home Assistant IP ist erforderlich!"
    exit 1
fi

echo ""
echo "🔐 MQTT Authentifizierung für Home Assistant:"
read -p "   MQTT Username: " MQTT_USER
if [ -z "$MQTT_USER" ]; then
    echo "❌ MQTT Username ist erforderlich!"
    exit 1
fi

echo -n "   MQTT Passwort: "
read -s MQTT_PASS
echo ""
if [ -z "$MQTT_PASS" ]; then
    echo "❌ MQTT Passwort ist erforderlich!"
    exit 1
fi

echo ""
echo "📋 Konfiguration:"
echo "   🏠 Home Assistant: $HA_IP:1883"
echo "   🔐 MQTT User: $MQTT_USER"
echo "   📡 Ziel: Home Assistant MQTT Broker"
echo ""

read -p "Fortfahren? [J/n]: " CONFIRM
CONFIRM=${CONFIRM:-j}
if [[ ! $CONFIRM =~ ^[Jj] ]]; then
    echo "Installation abgebrochen."
    exit 0
fi

# 1. MQTT Client installieren (KEIN Broker!)
echo "📦 Installiere MQTT Client..."
sudo apt update
sudo apt install -y mosquitto-clients

# Wir installieren KEINEN lokalen Broker - verwenden Home Assistant MQTT!

# 2. Prüfe ob pi5-sensors existiert
if [ ! -d "$HOME/pi5-sensors" ]; then
    echo "❌ pi5-sensors nicht gefunden!"
    echo "   Installiere zuerst: curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
    exit 1
fi

cd "$HOME/pi5-sensors"

# 3. Python Packages
echo "📦 Installiere Python MQTT..."
source venv/bin/activate
pip install paho-mqtt influxdb-client

# 4. Config für Home Assistant MQTT erstellen
echo "📝 Aktualisiere config.ini für Home Assistant MQTT..."
cat >> config.ini << ENDCONFIG

[mqtt]
broker = ${HA_IP}
port = 1883
username = ${MQTT_USER}
password = ${MQTT_PASS}
topic_prefix = pi5_heizung

[homeassistant]
ip = ${HA_IP}
mqtt_discovery = true
ENDCONFIG

# 5. MQTT Bridge laden
echo "📥 Lade MQTT Bridge..."
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py -o mqtt_bridge.py
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/setup_mqtt_service.sh -o setup_mqtt_service.sh
chmod +x setup_mqtt_service.sh

# 6. Service installieren
echo "⚙️ Installiere Service..."
bash setup_mqtt_service.sh

# 7. MQTT Verbindung testen
echo "🧪 Teste MQTT Verbindung zu Home Assistant..."
timeout 10 mosquitto_pub -h "$HA_IP" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/test" -m "connection_test" || {
    echo "⚠️ MQTT Test fehlgeschlagen - prüfe Home Assistant MQTT Einstellungen"
}

echo ""
echo "🎉 FERTIG!"
echo "========="
echo ""
echo "✅ MQTT Ziel: Home Assistant ($HA_IP:1883)"
echo "✅ MQTT User: $MQTT_USER"
echo "✅ Bridge Service installiert"
echo ""
echo "🔧 Befehle:"
echo "   sudo systemctl status pi5-mqtt-bridge"
echo "   mosquitto_sub -h $HA_IP -u $MQTT_USER -P $MQTT_PASS -t 'pi5_heizung/+/state'"
echo ""
echo "📋 Home Assistant:"
echo "   Die Sensoren erscheinen automatisch in Home Assistant!"
echo "   Prüfe: Einstellungen → Geräte & Services → MQTT"
