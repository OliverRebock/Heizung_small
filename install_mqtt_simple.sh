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
    read -p "🔐 MQTT Username: " MQTT_USER
fi

if [ -z "$MQTT_PASS" ]; then
    echo -n "🔐 MQTT Passwort: "
    read -s MQTT_PASS
    echo ""
fi

echo ""
echo "📋 Konfiguration:"
echo "   🏠 Home Assistant: $HA_IP:1883"
echo "   🔐 MQTT User: $MQTT_USER"
echo "   📡 Ziel: Home Assistant MQTT Broker"
echo ""

# 1. MQTT CLIENT INSTALLIEREN (KEIN lokaler Broker!)
echo "📦 Installiere MQTT Client..."
sudo apt update
sudo apt install -y mosquitto-clients

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
echo "" >> config.ini
echo "[mqtt]" >> config.ini
echo "broker = ${HA_IP}" >> config.ini
echo "port = 1883" >> config.ini
echo "username = ${MQTT_USER}" >> config.ini
echo "password = ${MQTT_PASS}" >> config.ini
echo "topic_prefix = pi5_heizung" >> config.ini
echo "" >> config.ini
echo "[homeassistant]" >> config.ini
echo "ip = ${HA_IP}" >> config.ini
echo "mqtt_discovery = true" >> config.ini

echo "   ✅ config.ini aktualisiert"

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
echo "🎉 MQTT Installation abgeschlossen!"
echo "=================================="
echo ""
echo "✅ MQTT Ziel: Home Assistant ($HA_IP:1883)"
echo "✅ MQTT User: $MQTT_USER"
echo "✅ Bridge Service installiert"
echo ""
echo "🔧 Befehle:"
echo "   sudo systemctl status pi5-mqtt-bridge"
echo "   sudo journalctl -u pi5-mqtt-bridge -f"
echo "   mosquitto_sub -h $HA_IP -u $MQTT_USER -P $MQTT_PASS -t 'pi5_heizung/+/state'"
echo ""
echo "📋 Home Assistant:"
echo "   Die Sensoren erscheinen automatisch unter:"
echo "   Einstellungen → Geräte & Services → MQTT"
echo "   → Pi5 Heizungs Messer (10 Sensoren)"
