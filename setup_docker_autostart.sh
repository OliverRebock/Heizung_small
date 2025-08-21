#!/bin/bash
"""
Docker Setup und Autostart für Pi 5 InfluxDB Container
Erstellt systemd Service für automatischen Container-Start
"""

echo "🐳 Pi 5 InfluxDB Docker Autostart Setup"
echo "======================================"

# Prüfe Docker Installation
if ! command -v docker &> /dev/null; then
    echo "❌ Docker nicht installiert!"
    echo "💡 Führe zuerst install_sensors.sh aus"
    exit 1
fi

# In sensor-monitor-pi5 Verzeichnis wechseln
cd ~/sensor-monitor-pi5

# Prüfe docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml nicht gefunden!"
    echo "💡 Lade docker-compose.yml herunter..."
    wget -O docker-compose.yml https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/docker-compose.yml
fi

echo "📝 Erstelle systemd Service für InfluxDB Autostart..."

# Systemd Service erstellen
sudo tee /etc/systemd/system/pi5-influxdb.service > /dev/null << EOF
[Unit]
Description=Pi 5 InfluxDB Container Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/pi/sensor-monitor-pi5
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
User=pi
Group=pi

[Install]
WantedBy=multi-user.target
EOF

echo "🔧 Konfiguriere systemd Service..."

# Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable pi5-influxdb.service

echo "✅ systemd Service erstellt: pi5-influxdb.service"
echo ""
echo "🚀 Verfügbare Befehle:"
echo "💡 sudo systemctl start pi5-influxdb    # Container starten"
echo "💡 sudo systemctl stop pi5-influxdb     # Container stoppen"  
echo "💡 sudo systemctl status pi5-influxdb   # Status prüfen"
echo "💡 docker-compose ps                    # Container anzeigen"
echo ""

# Erste Ausführung
echo "🚀 Starte Container erstmalig..."
sudo systemctl start pi5-influxdb

# Status prüfen
sleep 5
echo "🔍 Container Status:"
docker-compose ps

echo ""
echo "✅ InfluxDB Autostart konfiguriert!"
echo "🌐 InfluxDB UI: http://localhost:8086"
echo "🌐 Grafana: http://localhost:3000"
echo "🔑 Login: pi5admin / pi5sensors2024"
