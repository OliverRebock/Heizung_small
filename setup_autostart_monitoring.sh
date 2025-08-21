#!/bin/bash
#
# Pi 5 Sensor-Monitor - Kompletter Autostart Setup
# Richtet Container-Autostart + Sensor-Monitoring ein
#

echo "🚀 Pi 5 Sensor-Monitor - Autostart Konfiguration"
echo "=============================================="
echo ""

# Prüfe ob im richtigen Verzeichnis
if [ ! -f "sensor_influxdb.py" ]; then
    echo "❌ Fehler: sensor_influxdb.py nicht gefunden!"
    echo "💡 Führe dieses Script im sensor-monitor-pi5 Verzeichnis aus"
    echo "💡 cd ~/sensor-monitor-pi5 && ./setup_autostart_monitoring.sh"
    exit 1
fi

# Prüfe ob Docker Container verfügbar
if [ ! -f "docker-compose.yml" ]; then
    echo "⚠️  Docker-Installation nicht gefunden"
    echo "💡 Führe zuerst die Docker-Installation aus:"
    echo "💡 ./install_docker_influxdb.sh"
    exit 1
fi

echo "🔧 1. Docker Container Autostart einrichten..."
if [ -f "./setup_docker_autostart.sh" ]; then
    ./setup_docker_autostart.sh
    echo "✅ Container-Autostart konfiguriert"
else
    echo "❌ setup_docker_autostart.sh nicht gefunden"
    exit 1
fi

echo ""
echo "🔧 2. Sensor-Monitoring Service erstellen..."

# Systemd Service für kontinuierliche Sensor-Überwachung
sudo tee /etc/systemd/system/pi5-sensor-monitoring.service > /dev/null << EOF
[Unit]
Description=Pi 5 Sensor Monitoring - InfluxDB Logger (30s Intervall)
After=network.target pi5-sensor-containers.service
Wants=pi5-sensor-containers.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$HOME/sensor-monitor-pi5
Environment=PATH=$HOME/sensor-monitor-pi5/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$HOME/sensor-monitor-pi5/venv/bin/python sensor_influxdb.py continuous 30
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service-Datei erstellt: /etc/systemd/system/pi5-sensor-monitoring.service"

echo ""
echo "🔧 3. Services aktivieren und starten..."

# Systemd neu laden und Services aktivieren
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensor-monitoring
sudo systemctl start pi5-sensor-monitoring

# Kurz warten und Status prüfen
sleep 3

echo ""
echo "🔍 4. Service-Status prüfen..."

# Container Service Status
echo "📦 Container Service Status:"
sudo systemctl is-active pi5-sensor-containers.service 2>/dev/null && echo "✅ pi5-sensor-containers: AKTIV" || echo "❌ pi5-sensor-containers: INAKTIV"

# Monitoring Service Status  
echo "📊 Monitoring Service Status:"
sudo systemctl is-active pi5-sensor-monitoring.service 2>/dev/null && echo "✅ pi5-sensor-monitoring: AKTIV" || echo "❌ pi5-sensor-monitoring: INAKTIV"

echo ""
echo "🔍 5. Docker Container Status..."
docker compose ps 2>/dev/null || echo "⚠️  Docker Container nicht verfügbar"

echo ""
echo "✅ Autostart-Konfiguration abgeschlossen!"
echo ""
echo "📋 Nützliche Befehle:"
echo "💡 sudo systemctl status pi5-sensor-monitoring     # Service Status"
echo "💡 sudo journalctl -u pi5-sensor-monitoring -f     # Live-Logs"
echo "💡 docker compose ps                               # Container Status"
echo "💡 python sensor_influxdb.py test                  # InfluxDB Test"
echo ""
echo "🌐 Web-Interfaces:"
echo "💡 InfluxDB: http://localhost:8086 (pi5admin/pi5sensors2024)"
echo "💡 Grafana: http://localhost:3000 (pi5admin/pi5sensors2024)"
echo ""
echo "🔄 Nach einem Neustart werden automatisch gestartet:"
echo "   1. Docker Container (InfluxDB + Grafana)"
echo "   2. Sensor-Monitoring (alle 30 Sekunden → InfluxDB)"
echo ""
