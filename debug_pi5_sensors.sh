#!/bin/bash
# Debug pi5-sensors Service
# ========================

echo "🔍 Pi5-Sensors Service Debug"
echo "============================"

# Service Status prüfen
echo "📋 Service Status:"
sudo systemctl status pi5-sensors.service --no-pager -l

echo ""
echo "📋 Service Logs (letzte 20 Zeilen):"
sudo journalctl -u pi5-sensors.service --no-pager -l -n 20

echo ""
echo "🔍 Prüfe Installation..."

# Prüfe ob Verzeichnis existiert
if [ ! -d "/home/pi/pi5-sensors" ]; then
    echo "❌ /home/pi/pi5-sensors existiert nicht!"
    echo "   Führe zuerst aus: curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
    exit 1
fi

cd /home/pi/pi5-sensors

# Prüfe wichtige Dateien
echo ""
echo "📂 Dateien prüfen:"
if [ -f "sensor_reader.py" ]; then
    echo "✅ sensor_reader.py vorhanden"
else
    echo "❌ sensor_reader.py fehlt!"
fi

if [ -f "config.ini" ]; then
    echo "✅ config.ini vorhanden"
else
    echo "❌ config.ini fehlt!"
fi

if [ -d "venv" ]; then
    echo "✅ venv Verzeichnis vorhanden"
else
    echo "❌ venv Verzeichnis fehlt!"
fi

# Prüfe Python venv
echo ""
echo "🐍 Python Virtual Environment prüfen:"
if [ -f "venv/bin/python" ]; then
    echo "✅ Python venv OK"
    source venv/bin/activate
    echo "🐍 Python Version: $(python --version)"
    echo "📦 Installierte Packages:"
    pip list | grep -E "(influxdb|adafruit)"
else
    echo "❌ Python venv defekt!"
fi

# Prüfe Docker Container
echo ""
echo "🐳 Docker Container prüfen:"
docker compose ps

# Prüfe InfluxDB Erreichbarkeit
echo ""
echo "🗄️ InfluxDB Test:"
timeout 5 curl -s http://localhost:8086/health && {
    echo "✅ InfluxDB erreichbar"
} || {
    echo "❌ InfluxDB nicht erreichbar"
}

# Sensor Test
echo ""
echo "🌡️ Sensor Test:"
if [ -f "venv/bin/python" ] && [ -f "sensor_reader.py" ]; then
    source venv/bin/activate
    timeout 10 python sensor_reader.py test && {
        echo "✅ Sensor Test erfolgreich"
    } || {
        echo "❌ Sensor Test fehlgeschlagen"
    }
else
    echo "❌ Kann Sensor Test nicht ausführen"
fi

# Service Definition prüfen
echo ""
echo "⚙️ Service Definition:"
if [ -f "/etc/systemd/system/pi5-sensors.service" ]; then
    echo "✅ Service-Datei vorhanden"
    echo "📋 Service Inhalt:"
    cat /etc/systemd/system/pi5-sensors.service
else
    echo "❌ Service-Datei fehlt!"
    echo "🔧 Service neu erstellen..."
    
    # Service neu erstellen
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

    echo "✅ Service-Datei neu erstellt"
    sudo systemctl daemon-reload
fi

echo ""
echo "🔧 Reparatur-Vorschläge:"
echo "1. Docker Container starten: cd /home/pi/pi5-sensors && docker compose up -d"
echo "2. Python venv reparieren: cd /home/pi/pi5-sensors && python -m venv venv --clear"
echo "3. Service neu laden: sudo systemctl daemon-reload && sudo systemctl enable pi5-sensors"
echo "4. Basis-Installation wiederholen: curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
