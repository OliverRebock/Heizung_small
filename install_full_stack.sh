#!/bin/bash
"""
Full-Stack Installation für Pi 5 Sensor Monitor
Installiert Sensoren + Docker + InfluxDB + Grafana + Web Dashboard
"""

echo "🚀 Pi 5 Sensor Monitor - Full-Stack Installation"
echo "================================================="
echo "Komplette Installation:"
echo "  🌡️ 8x DS18B20 + 1x DHT22 Sensoren"
echo "  🐳 Docker + InfluxDB + Grafana"
echo "  📊 Professionelle Dashboards"
echo "  🔍 Advanced Monitoring"
echo "  💾 Automatische Backups"
echo "  🌐 Web-Dashboard"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Prüfe Raspberry Pi 5
if ! grep -q "Raspberry Pi 5" /proc/cpuinfo; then
    echo -e "${YELLOW}⚠️  Warnung: Läuft nicht auf Raspberry Pi 5${NC}"
    echo "💡 Dieses Script ist für Pi 5 optimiert"
    read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Raspberry Pi 5 erkannt${NC}"
fi

# Prüfe verfügbaren Speicherplatz
echo -e "${BLUE}🔍 Prüfe System-Anforderungen...${NC}"
AVAILABLE_SPACE=$(df /home | awk 'NR==2 {print $4}')
REQUIRED_SPACE=3000000  # 3GB in KB für Full-Stack

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo -e "${RED}❌ Nicht genügend Speicherplatz verfügbar${NC}"
    echo "Benötigt: 3GB, Verfügbar: $(($AVAILABLE_SPACE / 1024 / 1024))GB"
    echo "💡 Speicherplatz freigeben und erneut versuchen"
    exit 1
else
    echo -e "${GREEN}✅ Ausreichend Speicherplatz verfügbar${NC}"
fi

# Bestätigung vom Benutzer
echo ""
echo -e "${YELLOW}📋 Was wird installiert:${NC}"
echo "  🌡️ Sensor-Hardware-Support (lgpio, CircuitPython)"
echo "  🐳 Docker + Docker Compose"
echo "  🗄️ InfluxDB 2.x (Zeitreihen-Datenbank)"
echo "  📊 Grafana (Visualisierung)"
echo "  🔍 Advanced Monitoring System"
echo "  💾 Automatisches Backup-System"
echo "  🌐 Web-Dashboard (Flask)"
echo "  ⚙️ Systemd Services für Autostart"
echo ""
echo -e "${YELLOW}⏱️ Geschätzte Installationszeit: 15-25 Minuten${NC}"
echo ""

read -p "Full-Stack Installation starten? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Installation abgebrochen"
    exit 0
fi

# Logging
LOG_FILE="/tmp/pi5_fullstack_install.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo ""
echo -e "${GREEN}🚀 Full-Stack Installation gestartet...${NC}"
echo "📄 Log-Datei: $LOG_FILE"
echo ""

# Schritt 1: Basis-Sensor-Installation
echo -e "${BLUE}📦 Schritt 1/6: Basis-Sensor-Installation${NC}"
if [ -f "install_sensors.sh" ]; then
    chmod +x install_sensors.sh
    # Auto-Yes für Docker-Installation
    echo "y" | ./install_sensors.sh
else
    echo "📥 Lade Sensor-Installations-Script..."
    wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors.sh
    chmod +x install_sensors.sh
    echo "y" | ./install_sensors.sh
fi

# Schritt 2: Docker Installation (falls nicht durch install_sensors.sh erfolgt)
echo -e "${BLUE}📦 Schritt 2/6: Docker-Überprüfung${NC}"
if ! command -v docker &> /dev/null; then
    echo "🐳 Docker wird installiert..."
    if [ -f "install_docker_influxdb.sh" ]; then
        chmod +x install_docker_influxdb.sh
        ./install_docker_influxdb.sh
    else
        wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_docker_influxdb.sh
        chmod +x install_docker_influxdb.sh
        ./install_docker_influxdb.sh
    fi
else
    echo -e "${GREEN}✅ Docker bereits installiert${NC}"
fi

# Schritt 3: Python Dependencies für erweiterte Features
echo -e "${BLUE}📦 Schritt 3/6: Erweiterte Python-Pakete${NC}"
cd ~/sensor-monitor-pi5
source venv/bin/activate

pip install --upgrade pip
pip install flask flask-socketio
pip install prometheus-client psutil
pip install pytest pytest-cov black flake8
pip install pyyaml click python-dotenv

# Schritt 4: Konfigurationsdateien erstellen
echo -e "${BLUE}⚙️ Schritt 4/6: Konfiguration${NC}"

# config.ini erstellen (falls nicht vorhanden)
if [ ! -f "config.ini" ]; then
    echo "📝 Erstelle config.ini..."
    cat > config.ini << 'EOF'
# Pi 5 Sensor Monitor Configuration
[hardware]
ds18b20_count = 8
ds18b20_gpio_pin = 4
dht22_gpio_pin = 18

[performance]
high_performance_mode = true
parallel_reading = true
read_timeout = 2.0

[monitoring]
default_interval = 30
log_level = "INFO"

[influxdb]
host = "localhost"
port = 8086
username = "pi5admin"
password = "pi5sensors2024"
org = "Pi5SensorOrg"
bucket = "sensor_data"
token = "pi5-sensor-token-2024-super-secret"

[grafana]
host = "localhost"
port = 3000
username = "pi5admin"
password = "pi5sensors2024"

[alerts]
temperature_high = 30.0
temperature_low = 10.0
humidity_high = 80.0
humidity_low = 30.0

[labels]
ds18b20_1 = "Vorlauf Heizkreis 1"
ds18b20_2 = "Rücklauf Heizkreis 1"
ds18b20_3 = "Vorlauf Heizkreis 2"
ds18b20_4 = "Rücklauf Heizkreis 2"
ds18b20_5 = "Warmwasser Speicher"
ds18b20_6 = "Außentemperatur"
ds18b20_7 = "Heizraum Ambient"
ds18b20_8 = "Pufferspeicher Oben"
dht22 = "Raumklima Heizraum"
EOF
fi

# Schritt 5: Erweiterte Python-Scripts herunterladen
echo -e "${BLUE}📥 Schritt 5/6: Erweiterte Scripts${NC}"

# Liste der erweiterten Scripts
scripts=(
    "individualized_sensors.py"
    "influxdb_individualized.py" 
    "advanced_monitoring.py"
    "web_dashboard.py"
    "backup_system.sh"
    "test_comprehensive.py"
    "requirements.txt"
)

for script in "${scripts[@]}"; do
    if [ ! -f "$script" ]; then
        echo "📥 Lade $script..."
        wget -q "https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/$script" || echo "⚠️  $script nicht verfügbar"
    fi
done

# Scripts ausführbar machen
chmod +x backup_system.sh 2>/dev/null

# Schritt 6: Services einrichten
echo -e "${BLUE}⚙️ Schritt 6/6: Services konfigurieren${NC}"

# Web-Dashboard Service
sudo tee /etc/systemd/system/pi5-web-dashboard.service > /dev/null << EOF
[Unit]
Description=Pi5 Sensor Web Dashboard
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/sensor-monitor-pi5
Environment=PATH=/home/pi/sensor-monitor-pi5/venv/bin
ExecStart=/home/pi/sensor-monitor-pi5/venv/bin/python web_dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Advanced Monitoring Service
sudo tee /etc/systemd/system/pi5-advanced-monitoring.service > /dev/null << EOF
[Unit]
Description=Pi5 Advanced Monitoring
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/sensor-monitor-pi5
Environment=PATH=/home/pi/sensor-monitor-pi5/venv/bin
ExecStart=/home/pi/sensor-monitor-pi5/venv/bin/python -c "
import time
from advanced_monitoring import AdvancedMonitoringService
from individualized_sensors import IndividualizedSensorManager

monitoring = AdvancedMonitoringService()
sensor_manager = IndividualizedSensorManager()

while True:
    try:
        sensor_data = sensor_manager.get_individualized_sensor_data()
        sensor_values = {k: v['value'] for k, v in sensor_data.items() if v and v['value'] is not None}
        monitoring.run_monitoring_cycle(sensor_values)
        time.sleep(30)
    except Exception as e:
        print(f'Monitoring error: {e}')
        time.sleep(60)
"
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Services aktivieren
sudo systemctl daemon-reload
sudo systemctl enable pi5-web-dashboard.service
sudo systemctl enable pi5-advanced-monitoring.service

# Docker Stack starten
echo -e "${BLUE}🐳 Docker Stack wird gestartet...${NC}"
if [ -f "docker-compose.yml" ]; then
    docker compose up -d
    sleep 10
    
    # Warten bis InfluxDB bereit ist
    echo "⏳ Warte auf InfluxDB..."
    timeout=60
    while [ $timeout -gt 0 ] && ! curl -s http://localhost:8086/ping > /dev/null; do
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if curl -s http://localhost:8086/ping > /dev/null; then
        echo -e "${GREEN}✅ InfluxDB ist bereit${NC}"
    else
        echo -e "${YELLOW}⚠️  InfluxDB Timeout - manuell prüfen${NC}"
    fi
fi

# Services starten
echo -e "${BLUE}🔄 Services werden gestartet...${NC}"
sudo systemctl start pi5-web-dashboard.service
sudo systemctl start pi5-advanced-monitoring.service

# Abschluss
echo ""
echo -e "${GREEN}🎉 Full-Stack Installation abgeschlossen!${NC}"
echo "================================================="
echo ""
echo -e "${GREEN}✅ Installierte Komponenten:${NC}"
echo "  🌡️ Sensor-Hardware-Support"
echo "  🐳 Docker + InfluxDB + Grafana"
echo "  🔍 Advanced Monitoring"
echo "  🌐 Web-Dashboard"
echo "  💾 Backup-System"
echo ""
echo -e "${BLUE}🌐 Web-Interfaces:${NC}"
echo "  📊 Grafana:      http://$(hostname -I | awk '{print $1}'):3000"
echo "  🗄️ InfluxDB:     http://$(hostname -I | awk '{print $1}'):8086"
echo "  🌐 Web-Dashboard: http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo -e "${BLUE}🔐 Standard-Anmeldung:${NC}"
echo "  Benutzer: pi5admin"
echo "  Passwort: pi5sensors2024"
echo ""
echo -e "${BLUE}📋 Nützliche Befehle:${NC}"
echo "  💡 sudo systemctl status pi5-web-dashboard"
echo "  💡 sudo systemctl status pi5-advanced-monitoring"
echo "  💡 docker compose ps"
echo "  💡 python individualized_sensors.py"
echo "  💡 ./backup_system.sh status"
echo ""
echo -e "${BLUE}🔄 Nach Neustart:${NC}"
echo "Alle Services starten automatisch!"
echo ""
echo -e "${GREEN}📄 Log-Datei: $LOG_FILE${NC}"
