#!/bin/bash
# Ultra-Simple MQTT Installation für Pi5 Heizungs Messer
set -e

echo "🏠 Pi5 MQTT Installation für Home Assistant"
echo "=========================================="

# Parameter prüfen oder interaktiv abfragen
if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
    # Parameter-basiert: install_mqtt_ultra_simple.sh HA_IP MQTT_USER MQTT_PASS
    HA_IP="$1"
    MQTT_USER="$2"
    MQTT_PASS="$3"
    echo "📋 Parameter erkannt:"
    echo "   🏠 Home Assistant: $HA_IP:1883"
    echo "   🔐 MQTT User: $MQTT_USER"
    echo "   📡 Ziel: Home Assistant MQTT Broker"
elif [ -t 0 ]; then
    # Interaktiv (nur wenn TTY verfügbar)
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
else
    # Curl | bash ohne TTY
    echo ""
    echo "❌ Für curl | bash Installation bitte Parameter verwenden:"
    echo ""
    echo "🔧 Parameter-Installation:"
    echo "   curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh | bash -s -- HA_IP MQTT_USER MQTT_PASS"
    echo ""
    echo "📋 Beispiel:"
    echo "   curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh | bash -s -- 192.168.1.100 mqtt_user mqtt_pass"
    echo ""
    echo "🔧 Oder interaktiv installieren:"
    echo "   wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh"
    echo "   chmod +x install_mqtt_ultra_simple.sh"
    echo "   ./install_mqtt_ultra_simple.sh"
    echo ""
    exit 1
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

echo "   ✅ config.ini für Home Assistant ($HA_IP) erstellt"

# 5. MQTT Bridge Script kopieren
echo "� Kopiere MQTT Bridge Script..."
wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py -O ~/pi5-sensors/mqtt_bridge.py
wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_debug.py -O ~/pi5-sensors/mqtt_debug.py
chmod +x ~/pi5-sensors/mqtt_bridge.py
chmod +x ~/pi5-sensors/mqtt_debug.py

echo "🧪 MQTT Debug Tools installiert:"
echo "   ~/pi5-sensors/mqtt_debug.py - MQTT Verbindungstest"
echo "   python ~/pi5-sensors/mqtt_bridge.py mqtt-test - MQTT Bridge Test"
echo "   python ~/pi5-sensors/mqtt_bridge.py discovery - Nur Discovery senden"

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
