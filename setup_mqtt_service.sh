#!/bin/bash
# Pi5 Heizungs Messer - MQTT Service Setup
# ========================================

echo "🏠 Pi5 Heizungs Messer → Home Assistant MQTT Service Setup"
echo "=========================================================="

# Variablen
INSTALL_DIR="/home/pi/pi5-sensors"
SERVICE_FILE="/etc/systemd/system/pi5-mqtt-bridge.service"
VENV_PATH="$INSTALL_DIR/venv"

# Prüfe ob Installationsordner existiert
if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ Sensor-Installation nicht gefunden in $INSTALL_DIR"
    echo "   Führe zuerst install_simple.sh aus!"
    exit 1
fi

echo "📦 Installiere MQTT Bridge Dependencies..."

# Aktiviere Virtual Environment
source "$VENV_PATH/bin/activate"

# Installiere MQTT Dependencies
pip install paho-mqtt influxdb-client

echo "⚙️ Erstelle MQTT Bridge Service..."

# Erstelle Systemd Service
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Pi5 Heizungs Messer MQTT Bridge
After=network.target influxdb.service mosquitto.service
Wants=influxdb.service mosquitto.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$VENV_PATH/bin
ExecStart=$VENV_PATH/bin/python $INSTALL_DIR/mqtt_bridge.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=pi5-mqtt-bridge

[Install]
WantedBy=multi-user.target
EOF

echo "📋 Kopiere Konfigurationsdateien..."

# Kopiere MQTT Bridge Files
cp mqtt_bridge.py "$INSTALL_DIR/"
cp mqtt_config.ini "$INSTALL_DIR/config.ini"

# Setze Berechtigungen
chmod +x "$INSTALL_DIR/mqtt_bridge.py"
chown pi:pi "$INSTALL_DIR/mqtt_bridge.py"
chown pi:pi "$INSTALL_DIR/config.ini"

echo "🔧 Aktiviere MQTT Bridge Service..."

# Systemd reload und Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable pi5-mqtt-bridge.service

echo ""
echo "✅ MQTT Bridge Service installiert!"
echo ""
echo "📋 Verfügbare Kommandos:"
echo "   sudo systemctl start pi5-mqtt-bridge     # Service starten"
echo "   sudo systemctl stop pi5-mqtt-bridge      # Service stoppen"
echo "   sudo systemctl status pi5-mqtt-bridge    # Service Status"
echo "   sudo systemctl restart pi5-mqtt-bridge   # Service neustarten"
echo "   sudo journalctl -u pi5-mqtt-bridge -f    # Live Logs"
echo ""
echo "🧪 Test-Kommandos:"
echo "   cd $INSTALL_DIR"
echo "   source venv/bin/activate"
echo "   python mqtt_bridge.py test              # Test-Modus"
echo ""
echo "⚙️ Konfiguration anpassen:"
echo "   nano $INSTALL_DIR/config.ini            # MQTT Einstellungen"
echo ""
echo "🏠 Home Assistant Integration:"
echo "   1. Installiere MQTT Broker: bash install_mqtt.sh"
echo "   2. Starte MQTT Bridge: sudo systemctl start pi5-mqtt-bridge"
echo "   3. Home Assistant erkennt Sensoren automatisch"
echo "   4. Überprüfe MQTT Topics: mosquitto_sub -t 'pi5_heizung/+/state'"
echo ""
echo "📡 MQTT Topics:"
echo "   pi5_heizung/28-0000000001/state  # HK1 Vorlauf"
echo "   pi5_heizung/28-0000000002/state  # HK1 Rücklauf"
echo "   pi5_heizung/dht22_temperature/state  # DHT22 Temperatur"
echo "   pi5_heizung/dht22_humidity/state     # DHT22 Luftfeuchtigkeit"
echo ""
