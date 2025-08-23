#!/bin/bash
# Quick Fix für pi5-sensors Service
# =================================

echo "🔧 Pi5-Sensors Service Quick Fix"
echo "================================"

# Prüfe ob Installation existiert
if [ ! -d "/home/pi/pi5-sensors" ]; then
    echo "❌ Basis-Installation fehlt!"
    echo "🔧 Installiere Basis-System..."
    curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash
    echo "✅ Basis-Installation abgeschlossen"
    exit 0
fi

cd /home/pi/pi5-sensors

# Docker Container sicherstellen
echo "🐳 Starte Docker Container..."
docker compose down
docker compose up -d
sleep 5

# Python venv prüfen/reparieren
echo "🐍 Prüfe Python Virtual Environment..."
if [ ! -f "venv/bin/python" ]; then
    echo "🔧 Repariere Python venv..."
    python -m venv venv --clear
    source venv/bin/activate
    pip install influxdb-client adafruit-circuitpython-dht
else
    echo "✅ Python venv OK"
fi

# Sensor Script prüfen
if [ ! -f "sensor_reader.py" ]; then
    echo "📄 Lade sensor_reader.py..."
    wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/sensor_reader.py -O sensor_reader.py
fi

# Config prüfen (aber nicht überschreiben falls MQTT konfiguriert)
if [ ! -f "config.ini" ]; then
    echo "📝 Erstelle config.ini..."
    cat > config.ini << EOF
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
EOF
fi

# Service Definition reparieren
echo "⚙️ Repariere Service Definition..."
sudo tee /etc/systemd/system/pi5-sensors.service > /dev/null <<EOF
[Unit]
Description=Pi5 Heizungs Messer - Sensor Reader
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/pi5-sensors
Environment=PATH=/home/pi/pi5-sensors/venv/bin
ExecStart=/home/pi/pi5-sensors/venv/bin/python /home/pi/pi5-sensors/sensor_reader.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=pi5-sensors

[Install]
WantedBy=multi-user.target
EOF

# Service neu laden und starten
echo "🔄 Service neu laden..."
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensors
sudo systemctl stop pi5-sensors
sleep 2
sudo systemctl start pi5-sensors

# Status prüfen
echo ""
echo "📋 Service Status:"
sudo systemctl status pi5-sensors --no-pager -l

# Kurzer Test
echo ""
echo "🧪 Quick Test..."
source venv/bin/activate
timeout 5 python sensor_reader.py test && {
    echo "✅ Sensor Test erfolgreich"
} || {
    echo "❌ Sensor Test fehlgeschlagen - prüfe Hardware"
}

echo ""
echo "✅ Quick Fix abgeschlossen!"
echo "🔧 Falls Probleme bestehen:"
echo "   sudo journalctl -u pi5-sensors -f"
