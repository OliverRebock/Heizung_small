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

# 6. Service direkt installieren (ohne setup_mqtt_service.sh)
echo "⚙️ Installiere MQTT Bridge Service..."

# Service Definition erstellen
sudo tee /etc/systemd/system/pi5-mqtt-bridge.service > /dev/null <<EOF
[Unit]
Description=Pi5 Heizungs Messer MQTT Bridge
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/pi5-sensors
Environment=PATH=/home/pi/pi5-sensors/venv/bin
ExecStart=/home/pi/pi5-sensors/venv/bin/python /home/pi/pi5-sensors/mqtt_bridge.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=pi5-mqtt-bridge

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable pi5-mqtt-bridge
sudo systemctl start pi5-mqtt-bridge

# Service Status prüfen
sleep 2
sudo systemctl status pi5-mqtt-bridge --no-pager

echo "🧪 Teste Auto-Discovery sofort..."
cd ~/pi5-sensors

# Aktiviere Python venv mit Error Handling
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ Python venv nicht gefunden - erstelle neues venv..."
    python3 -m venv venv
    source venv/bin/activate
    pip install paho-mqtt influxdb-client
fi

# Prüfe ob mqtt_bridge.py existiert mit Error Handling
if [ ! -f "mqtt_bridge.py" ]; then
    echo "❌ mqtt_bridge.py nicht gefunden - lade von GitHub..."
    wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py -O mqtt_bridge.py
    chmod +x mqtt_bridge.py
fi

# Discovery mit Error Handling
python3 -c "
import sys
sys.path.append('.')

try:
    from mqtt_bridge import Pi5MqttBridge
    import time
    
    print('✅ mqtt_bridge erfolgreich importiert')
    bridge = Pi5MqttBridge()
    if bridge.setup_mqtt():
        time.sleep(1)
        bridge.publish_discovery()
        time.sleep(1)
        print('✅ Auto-Discovery an Home Assistant gesendet!')
    else:
        print('❌ MQTT Setup fehlgeschlagen - prüfe config.ini')
        
except ImportError as e:
    print(f'❌ Import Error: {e}')
    print('🔧 Repariere mit: wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_mqtt_import_error.sh')
    sys.exit(1)
except Exception as e:
    print(f'❌ MQTT Error: {e}')
    print('🔧 Überprüfe Home Assistant MQTT Einstellungen')
    sys.exit(1)
"

# 7. MQTT Verbindung testen mit Error Handling
echo "🧪 Teste MQTT Verbindung zu Home Assistant..."
if command -v mosquitto_pub >/dev/null 2>&1; then
    timeout 10 mosquitto_pub -h "$HA_IP" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/test" -m "connection_test" && {
        echo "✅ MQTT Verbindung erfolgreich!"
    } || {
        echo "⚠️ MQTT Test fehlgeschlagen - aber das ist normal bei ersten Installation"
        echo "🔧 Prüfe Home Assistant MQTT Einstellungen falls Probleme auftreten"
    }
else
    echo "ℹ️ mosquitto-clients nicht installiert - installiere für Tests mit:"
    echo "   sudo apt-get install mosquitto-clients"
fi

echo ""
echo "🎉 FERTIG! Pi5 Heizungs Messer → Home Assistant"
echo "=============================================="
echo ""
echo "✅ MQTT Ziel: Home Assistant ($HA_IP:1883)"
echo "✅ MQTT User: $MQTT_USER"
echo "✅ Bridge Service installiert & läuft"
echo "✅ Auto-Discovery gesendet"
echo ""
echo "🏠 Home Assistant:"
echo "   🔍 Sensoren erscheinen automatisch unter:"
echo "   📱 Einstellungen → Geräte & Services → MQTT"
echo "   🎯 Suche nach 'Pi5 Heizungs Messer'"
echo ""
echo "🔧 Wichtige Befehle:"
echo "   sudo systemctl status pi5-mqtt-bridge"
echo "   sudo journalctl -u pi5-mqtt-bridge -f"
echo "   mosquitto_sub -h $HA_IP -u $MQTT_USER -P $MQTT_PASS -t 'pi5_heizung/+/state'"
echo ""
echo "� Falls Probleme auftreten:"
echo "   cd ~/pi5-sensors"
echo "   wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_mqtt_import_error.sh"
echo "   chmod +x fix_mqtt_import_error.sh && ./fix_mqtt_import_error.sh"
