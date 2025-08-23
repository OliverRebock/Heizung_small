#!/bin/bash
# Fix config.ini für MQTT
# ======================

echo "🔧 Repariere config.ini für MQTT..."

cd ~/pi5-sensors

# Backup der aktuellen config.ini
cp config.ini config.ini.backup
echo "📋 Backup erstellt: config.ini.backup"

# Frage nach korrekten MQTT Daten
echo ""
echo "🏠 Bitte gib deine korrekten MQTT Daten ein:"
read -p "Home Assistant IP: " HA_IP
read -p "MQTT Username: " MQTT_USER
echo -n "MQTT Passwort: "
read -s MQTT_PASS
echo ""

if [ -z "$HA_IP" ] || [ -z "$MQTT_USER" ] || [ -z "$MQTT_PASS" ]; then
    echo "❌ Alle Felder sind erforderlich!"
    exit 1
fi

echo ""
echo "📝 Erstelle neue config.ini..."

# Neue config.ini erstellen (nur relevante Teile)
cat > config.ini.new << EOF
[database]
host = localhost
port = 8086
database = sensors
username = admin
password = pi5sensors2024
token = pi5-token-2024
org = pi5org
bucket = sensors

[labels]
ds18b20_1 = RL WP
ds18b20_2 = VL UG
ds18b20_3 = VL WP
ds18b20_4 = RL UG
ds18b20_5 = RL OG
ds18b20_6 = RL Keller
ds18b20_7 = VL OG
ds18b20_8 = VL Keller
dht22 = Raumklima Heizraum

[mqtt]
broker = ${HA_IP}
port = 1883
username = ${MQTT_USER}
password = ${MQTT_PASS}
topic_prefix = pi5_heizung

[homeassistant]
ip = ${HA_IP}
mqtt_discovery = true
EOF

# Alte config.ini ersetzen
mv config.ini.new config.ini

echo "✅ Neue config.ini erstellt"
echo ""
echo "📋 MQTT Konfiguration:"
echo "   Broker: ${HA_IP}:1883"
echo "   User: ${MQTT_USER}"
echo "   Discovery: aktiviert"
echo ""

# MQTT Verbindung testen
echo "🧪 Teste MQTT Verbindung..."
timeout 5 mosquitto_pub -h "$HA_IP" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/test" -m "test" && {
    echo "✅ MQTT Verbindung erfolgreich!"
} || {
    echo "❌ MQTT Verbindung fehlgeschlagen!"
    echo "   Prüfe Home Assistant MQTT Einstellungen"
    exit 1
}

# Services neu starten
echo ""
echo "🔄 Starte Services neu..."
sudo systemctl restart pi5-sensors
sudo systemctl restart pi5-mqtt-bridge

echo ""
echo "🏠 Sende Discovery an Home Assistant..."
cd ~/pi5-sensors
source venv/bin/activate

# Discovery senden
python -c "
import sys
sys.path.append('.')
from mqtt_bridge import Pi5MqttBridge
import time

bridge = Pi5MqttBridge()
if bridge.setup_mqtt():
    time.sleep(2)
    bridge.publish_discovery()
    time.sleep(2)
    print('✅ Discovery gesendet!')
else:
    print('❌ MQTT Setup fehlgeschlagen!')
"

echo ""
echo "🎯 Prüfe jetzt in Home Assistant:"
echo "   Settings → Devices & Services → MQTT"
echo "   Suche nach 'Pi5 Heizungs Messer'"
echo ""
echo "✅ Reparatur abgeschlossen!"
