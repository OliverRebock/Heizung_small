#!/bin/bash
# Ultra-Simple MQTT Installation für Pi5 Heizungs Messer - DEBUG VERSION
set -e

echo "🏠 Pi5 MQTT Installation für Home Assistant (DEBUG)"
echo "================================================="

# Home Assistant Konfiguration abfragen
echo ""
echo "🏠 Home Assistant Konfiguration:"
echo -n "   IP-Adresse von Home Assistant (z.B. 192.168.1.100): "
read HA_IP
echo "DEBUG: Eingegeben HA_IP = '$HA_IP'"

if [ -z "$HA_IP" ]; then
    echo "❌ Home Assistant IP ist erforderlich!"
    exit 1
fi

echo ""
echo "🔐 MQTT Authentifizierung für Home Assistant:"
echo -n "   MQTT Username: "
read MQTT_USER
echo "DEBUG: Eingegeben MQTT_USER = '$MQTT_USER'"

if [ -z "$MQTT_USER" ]; then
    echo "❌ MQTT Username ist erforderlich!"
    exit 1
fi

echo -n "   MQTT Passwort: "
read -s MQTT_PASS
echo ""
echo "DEBUG: MQTT_PASS eingegeben (Länge: ${#MQTT_PASS} Zeichen)"

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

echo -n "Fortfahren? [J/n]: "
read CONFIRM
CONFIRM=${CONFIRM:-j}
if [[ ! $CONFIRM =~ ^[Jj] ]]; then
    echo "Installation abgebrochen."
    exit 0
fi

# 1. MQTT Client installieren (KEIN Broker!)
echo "📦 Installiere MQTT Client..."
sudo apt update
sudo apt install -y mosquitto-clients

echo "✅ MQTT Client installiert"

# 2. Prüfe ob pi5-sensors existiert
if [ ! -d "$HOME/pi5-sensors" ]; then
    echo "❌ pi5-sensors nicht gefunden!"
    echo "   Installiere zuerst: curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
    exit 1
fi

cd "$HOME/pi5-sensors"
echo "✅ Verzeichnis: $(pwd)"

# 3. Python Packages
echo "📦 Installiere Python MQTT..."
source venv/bin/activate
pip install paho-mqtt influxdb-client

echo "✅ Python MQTT installiert"

# 4. Config für Home Assistant MQTT erstellen
echo "📝 Erstelle config.ini für Home Assistant MQTT..."
echo "DEBUG: Schreibe Config für HA_IP='$HA_IP', MQTT_USER='$MQTT_USER'"

echo "" >> config.ini
echo "[mqtt]" >> config.ini
echo "broker = $HA_IP" >> config.ini
echo "port = 1883" >> config.ini
echo "username = $MQTT_USER" >> config.ini
echo "password = $MQTT_PASS" >> config.ini
echo "topic_prefix = pi5_heizung" >> config.ini
echo "" >> config.ini
echo "[homeassistant]" >> config.ini
echo "ip = $HA_IP" >> config.ini
echo "mqtt_discovery = true" >> config.ini

echo "✅ config.ini für Home Assistant ($HA_IP) erstellt"

# Config anzeigen
echo ""
echo "🔍 Aktuelle MQTT Config:"
tail -12 config.ini

# 5. MQTT Bridge laden
echo ""
echo "📥 Lade MQTT Bridge..."
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py -o mqtt_bridge.py
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/setup_mqtt_service.sh -o setup_mqtt_service.sh
chmod +x setup_mqtt_service.sh

echo "✅ MQTT Bridge geladen"

# 6. Service installieren
echo "⚙️ Installiere Service..."
bash setup_mqtt_service.sh

# 7. MQTT Verbindung testen
echo ""
echo "🧪 Teste MQTT Verbindung zu Home Assistant..."
echo "DEBUG: mosquitto_pub -h '$HA_IP' -u '$MQTT_USER' -P '***' -t 'pi5_heizung/test' -m 'connection_test'"

timeout 10 mosquitto_pub -h "$HA_IP" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/test" -m "connection_test" && {
    echo "✅ MQTT Test erfolgreich!"
} || {
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
