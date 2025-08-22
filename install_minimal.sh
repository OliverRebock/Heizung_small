#!/bin/bash
# =============================================================================
# MINIMAL INSTALLATION V2 - Pi 5 Sensor Monitor
# =============================================================================
# 🎯 Fokus: Docker + InfluxDB + 9 Sensoren + Grafana (no login)
# 
# Was wird installiert:
# - Docker + Docker Compose
# - InfluxDB Container 
# - Grafana Container (ohne Login)
# - Python Sensor Script mit allen 9 Sensoren (8x DS18B20 + 1x DHT22)
# - Autostart Service
# =============================================================================

echo "🚀 Pi 5 Sensor Monitor - MINIMAL INSTALLATION V2"
echo "================================================="
echo ""
echo "🎯 Installiert wird:"
echo "   🐳 Docker + InfluxDB + Grafana"
echo "   🌡️  9 Sensoren (8x DS18B20 + 1x DHT22)"
echo "   🏷️  Individualisierte Sensornamen"
echo "   🔓 Grafana ohne Login"
echo "   ⚡ Ein Service für alles"
echo ""

# =============================================================================
# 1. SYSTEM VORBEREITEN
# =============================================================================
echo "📦 Aktualisiere System..."
sudo apt update && sudo apt upgrade -y

# GPIO aktivieren
echo "🔌 Aktiviere GPIO..."
if ! grep -q "dtoverlay=w1-gpio,gpiopin=4" /boot/firmware/config.txt; then
    echo "dtoverlay=w1-gpio,gpiopin=4" | sudo tee -a /boot/firmware/config.txt
fi

# =============================================================================
# 2. DOCKER INSTALLIEREN & OPTIMIEREN
# =============================================================================
echo "🐳 Installiere Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

# Warte bis Docker vollständig gestartet ist
echo "⏳ Warte auf Docker Service..."
sudo systemctl enable docker
sleep 5

# Überprüfe Docker Status vor Konfiguration
if ! sudo systemctl is-active --quiet docker; then
    echo "🔄 Starte Docker Service..."
    sudo systemctl start docker
    sleep 10
fi

# 🔧 DOCKER FÜR RASPBERRY PI 5 OPTIMIEREN
echo "⚙️ Optimiere Docker für Raspberry Pi 5..."

# Erstelle optimierte Docker daemon Konfiguration (nur wenn Docker läuft)
if sudo systemctl is-active --quiet docker; then
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

    # Docker neustarten mit neuer Konfiguration
    echo "🔄 Neustarte Docker mit Optimierungen..."
    sudo systemctl restart docker
    
    # Warte und prüfe ob Docker erfolgreich neugestartet wurde
    sleep 10
    if ! sudo systemctl is-active --quiet docker; then
        echo "⚠️  Docker Neustart fehlgeschlagen, verwende Standard-Konfiguration..."
        sudo rm -f /etc/docker/daemon.json
        sudo systemctl restart docker
        sleep 5
    else
        echo "✅ Docker erfolgreich optimiert"
    fi
else
    echo "⚠️  Docker nicht aktiv, überspringe Optimierung..."
fi

# 📁 PERSISTENTE DATENVERZEICHNISSE ERSTELLEN
echo "📁 Erstelle persistente Datenverzeichnisse..."
sudo mkdir -p /opt/docker-data/{influxdb,grafana}

# Setze Berechtigungen für Grafana (ID 472) und InfluxDB (ID 1000)
echo "🔧 Setze Container-Berechtigungen..."
sudo chown -R 472:472 /opt/docker-data/grafana 2>/dev/null || sudo chown -R 1000:1000 /opt/docker-data/grafana
sudo chown -R 1000:1000 /opt/docker-data/influxdb
sudo chmod 755 /opt/docker-data/{influxdb,grafana}

echo "✅ Docker Optimierung abgeschlossen"

# =============================================================================
# 3. PROJEKTVERZEICHNIS ERSTELLEN
# =============================================================================
PROJECT_DIR="$HOME/sensor-monitor"
echo "📁 Erstelle Projektverzeichnis: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# =============================================================================
# 4. VERBESSERTE SCRIPTS KOPIEREN
# =============================================================================
echo "🐍 Kopiere verbesserte Sensor-Scripts (9 Sensoren)..."

# Prüfe ob wir im Git-Repo sind
if [ -f "../sensor_monitor_minimal.py" ]; then
    echo "   📋 Kopiere aus Git-Repository..."
    cp ../sensor_monitor_minimal.py sensor_monitor.py
    cp ../test_all_sensors.py .
    cp ../config_minimal.ini config.ini
    cp ../docker-compose-minimal.yml docker-compose.yml
else
    echo "   ⚠️  Git-Repository nicht gefunden, erstelle Standard-Dateien..."
    
    # Fallback: Standard config.ini erstellen
    cat > config.ini << 'EOF'
[database]
host = localhost
port = 8086
token = pi5-sensor-token-2024
org = pi5sensors
bucket = sensor_data

[sensors]
ds18b20_count = 8
dht22_gpio = 18

[labels]
ds18b20_1 = Vorlauf Heizkreis 1
ds18b20_2 = Rücklauf Heizkreis 1
ds18b20_3 = Vorlauf Heizkreis 2
ds18b20_4 = Rücklauf Heizkreis 2
ds18b20_5 = Warmwasser Speicher
ds18b20_6 = Außentemperatur
ds18b20_7 = Heizraum Ambient
ds18b20_8 = Pufferspeicher Oben
dht22 = Raumklima Heizraum
EOF

    # Fallback: Docker Compose erstellen
    cat > docker-compose.yml << 'EOF'
services:
  influxdb:
    image: influxdb:2.7
    container_name: pi5-influxdb
    restart: unless-stopped
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=pi5admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=pi5sensors2024
      - DOCKER_INFLUXDB_INIT_ORG=pi5sensors
      - DOCKER_INFLUXDB_INIT_BUCKET=sensor_data
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=pi5-sensor-token-2024
    volumes:
      - influxdb-data:/var/lib/influxdb2
    # 🔧 RASPBERRY PI OPTIMIERUNGEN
    logging: *default-logging
    healthcheck:
      test: ["CMD", "influx", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  grafana:
    image: grafana/grafana:10.2.0
    container_name: pi5-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      # 🔓 GRAFANA OHNE LOGIN
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_SECURITY_ALLOW_EMBEDDING=true
      - GF_SECURITY_ADMIN_PASSWORD=pi5sensors2024
      # 🚀 PERFORMANCE OPTIMIERUNGEN FÜR PI 5
      - GF_RENDERING_SERVER_URL=
      - GF_RENDERING_CALLBACK_URL=
      - GF_LOG_LEVEL=warn
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
    volumes:
      - grafana-data:/var/lib/grafana
    # 🔧 RASPBERRY PI OPTIMIERUNGEN  
    logging: *default-logging
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    depends_on:
      influxdb:
        condition: service_healthy

volumes:
  influxdb-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/docker-data/influxdb
  grafana-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/docker-data/grafana

# 📊 DOCKER HEALTHCHECKS & LOGGING
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
EOF

    echo "   ❌ WARNUNG: Standard-Script verwendet, nicht das verbesserte!"
    echo "   💡 Für 9-Sensor Support: git clone ausführen vor Installation"
fi

echo "✅ Scripts bereit"

# =============================================================================
# 5. PYTHON VIRTUAL ENVIRONMENT ERSTELLEN (WICHTIG FÜR DHT22!)
# =============================================================================
echo "🐍 Erstelle Python Virtual Environment (für 9 Sensoren)..."
sudo apt install -y python3-pip python3-venv python3-dev

# Virtual Environment erstellen
python3 -m venv venv
source venv/bin/activate

# Dependencies in venv installieren
echo "📦 Installiere Dependencies in venv..."
pip install --upgrade pip
pip install influxdb-client lgpio adafruit-circuitpython-dht adafruit-blinka configparser

echo "✅ Python Virtual Environment mit Dependencies erstellt"

# =============================================================================
# 6. SYSTEMD SERVICE ERSTELLEN (MIT VENV!)
# =============================================================================
echo "⚙️ Erstelle Systemd Service (mit Python venv)..."

sudo tee /etc/systemd/system/pi5-sensor-minimal.service > /dev/null << EOF
[Unit]
Description=Pi 5 Sensor Monitor (9 Sensors with venv)
After=docker.service network.target
Requires=docker.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$PROJECT_DIR
ExecStartPre=/bin/sleep 30
ExecStartPre=/usr/bin/docker compose up -d
ExecStart=$PROJECT_DIR/venv/bin/python sensor_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensor-minimal.service

# =============================================================================
# 7. DOCKER CONTAINER STARTEN (MIT HEALTHCHECKS)
# =============================================================================
echo "🚀 Starte Docker Container mit Healthchecks..."
docker compose up -d

# Warten bis Container gesund sind
echo "⏳ Warte auf Container Healthchecks..."
echo "   📊 InfluxDB Healthcheck..."
while ! docker compose exec influxdb influx ping > /dev/null 2>&1; do
    echo "   ⏳ InfluxDB startet noch..."
    sleep 5
done
echo "   ✅ InfluxDB ist bereit"

echo "   📈 Grafana Healthcheck..."
while ! curl -f http://localhost:3000/api/health > /dev/null 2>&1; do
    echo "   ⏳ Grafana startet noch..."
    sleep 5
done
echo "   ✅ Grafana ist bereit"

# =============================================================================
# 8. TEST AUSFÜHREN (MIT VENV)
# =============================================================================
echo "🧪 Teste Installation (9 Sensoren)..."

# Test mit venv Python ausführen
echo "🔬 Teste alle 9 Sensoren..."
source venv/bin/activate

# Prüfe ob verbessertes Test-Script verfügbar ist
if [ -f "test_all_sensors.py" ]; then
    python test_all_sensors.py
else
    echo "   ⚠️  Verwende Standard-Test..."
    if [ -f "sensor_monitor.py" ]; then
        python sensor_monitor.py test
    else
        echo "   ❌ Kein Test-Script gefunden!"
    fi
fi

# =============================================================================
# 9. FERTIG!
# =============================================================================
echo ""
echo "🎉 INSTALLATION ABGESCHLOSSEN!"
echo "=============================="
echo ""
echo "✅ Was wurde installiert:"
echo "   🐳 Docker + InfluxDB + Grafana"
echo "   🌡️  Support für 9 Sensoren (8x DS18B20 + 1x DHT22)"
echo "   🏷️  Individualisierte Sensornamen"
echo "   🔓 Grafana OHNE Login"
echo "   ⚙️  Systemd Service mit venv"
echo ""
echo "🌐 Verfügbare Services:"
echo "   📊 Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "   🗄️  InfluxDB: http://$(hostname -I | awk '{print $1}'):8086"
echo ""
echo "🔧 Wichtige Befehle:"
echo "   Service starten: sudo systemctl start pi5-sensor-minimal"
echo "   Service stoppen: sudo systemctl stop pi5-sensor-minimal"
echo "   Logs anzeigen:   sudo journalctl -u pi5-sensor-minimal -f"
echo "   9 Sensoren test: cd $PROJECT_DIR && source venv/bin/activate && python test_all_sensors.py"
echo ""
echo "⚠️  NEUSTART ERFORDERLICH für GPIO!"
read -p "🔄 Jetzt neu starten? (ja/nein): " reboot_now
if [ "$reboot_now" = "ja" ]; then
    sudo reboot
fi

echo "🚀 Projekt bereit! Nach Neustart startet alles automatisch."
echo "🎯 Erwartung: 9 Sensoren = 10 Messwerte (8x DS18B20 + DHT22 Temp + DHT22 Humidity)"
