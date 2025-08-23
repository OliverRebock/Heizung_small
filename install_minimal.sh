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
# 2. DOCKER PRÜFEN & INSTALLIEREN
# =============================================================================
echo "🐳 Prüfe Docker Installation..."

# Prüfe ob Docker bereits installiert ist
if command -v docker &> /dev/null; then
    echo "✅ Docker ist bereits installiert"
    DOCKER_VERSION=$(docker --version)
    echo "   📋 $DOCKER_VERSION"
    
    # Prüfe ob Docker läuft
    if sudo systemctl is-active --quiet docker; then
        echo "✅ Docker Service läuft bereits"
    else
        echo "🔄 Versuche Docker Service zu starten..."
        sudo systemctl enable docker
        sudo systemctl start docker
        sleep 5
        
        if sudo systemctl is-active --quiet docker; then
            echo "✅ Docker Service gestartet"
        else
            echo "❌ Docker Service konnte nicht gestartet werden"
            echo "🔍 Führe Docker-Diagnose aus..."
            
            # Zeige Docker-Status Details
            echo ""
            echo "📊 DOCKER SERVICE STATUS:"
            sudo systemctl status docker --no-pager -l || true
            echo ""
            echo "📋 DOCKER SERVICE LOGS:"
            sudo journalctl -u docker.service --no-pager -n 10 || true
            echo ""
            
            # Versuche Docker-Problem zu reparieren
            echo "🔧 Versuche Docker-Reparatur..."
            
            # Entferne problematische daemon.json falls vorhanden
            if [ -f "/etc/docker/daemon.json" ]; then
                echo "   ⚠️  Entferne problematische daemon.json..."
                sudo rm -f /etc/docker/daemon.json
            fi
            
            # Stoppe und starte Docker komplett neu
            echo "   🔄 Stoppe Docker komplett..."
            sudo systemctl stop docker.service || true
            sudo systemctl stop docker.socket || true
            sleep 3
            
            echo "   🔄 Starte Docker neu..."
            sudo systemctl start docker.service
            sleep 5
            
            if sudo systemctl is-active --quiet docker; then
                echo "   ✅ Docker-Reparatur erfolgreich!"
            else
                echo "   ❌ Docker-Reparatur fehlgeschlagen!"
                echo ""
                echo "🆘 DOCKER INSTALLATION ÜBERSPRUNGEN"
                echo "   Manuelle Docker-Reparatur erforderlich:"
                echo "   1. sudo apt remove docker-ce docker-ce-cli containerd.io"
                echo "   2. sudo apt autoremove"
                echo "   3. Neustart: sudo reboot"
                echo "   4. Dann install_minimal.sh erneut ausführen"
                echo ""
                echo "🔄 Installation wird OHNE Docker fortgesetzt..."
                echo "   (Nur Python Sensor-Monitor wird installiert)"
                DOCKER_INSTALLATION_FAILED=true
            fi
        fi
    fi
    
    # Prüfe Docker Compose nur wenn Docker läuft
    if sudo systemctl is-active --quiet docker; then
        if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
            echo "✅ Docker Compose verfügbar"
            COMPOSE_VERSION=$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null)
            echo "   📋 $COMPOSE_VERSION"
        else
            echo "⚠️  Docker Compose nicht gefunden, wird mit Docker installiert"
        fi
    fi
    
    DOCKER_ALREADY_INSTALLED=true
else
    echo "📦 Docker nicht gefunden, installiere Docker..."
    DOCKER_ALREADY_INSTALLED=false
    
    # Standard Docker Installation mit Fehlerbehandlung
    echo "   📥 Lade Docker-Installationsskript..."
    if curl -fsSL https://get.docker.com -o get-docker.sh; then
        echo "   🔧 Installiere Docker..."
        if sudo sh get-docker.sh; then
            sudo usermod -aG docker $USER
            echo "   ✅ Docker installiert"
        else
            echo "   ❌ Docker-Installation fehlgeschlagen!"
            echo "   🔄 Installation wird OHNE Docker fortgesetzt..."
            DOCKER_INSTALLATION_FAILED=true
        fi
        rm -f get-docker.sh
    else
        echo "   ❌ Docker-Installationsskript konnte nicht heruntergeladen werden!"
        echo "   🔄 Installation wird OHNE Docker fortgesetzt..."
        DOCKER_INSTALLATION_FAILED=true
    fi
fi

# Stelle sicher dass Docker läuft (falls Installation erfolgreich war)
if [ "${DOCKER_INSTALLATION_FAILED:-false}" != "true" ]; then
    echo "⏳ Überprüfe Docker Service Status..."
    
    # Prüfe aktuellen Docker Status ohne enable (das löst den Fehler aus!)
    if sudo systemctl is-active --quiet docker; then
        echo "✅ Docker läuft bereits"
        DOCKER_READY=true
    else
        echo "🔄 Docker läuft nicht, versuche Start..."
        
        # Versuche Docker zu starten ohne systemctl enable
        if sudo systemctl start docker 2>/dev/null; then
            sleep 5
            if sudo systemctl is-active --quiet docker; then
                echo "✅ Docker erfolgreich gestartet"
                DOCKER_READY=true
            else
                echo "❌ Docker start fehlgeschlagen"
                DOCKER_READY=false
            fi
        else
            echo "❌ Docker kann nicht gestartet werden"
            DOCKER_READY=false
        fi
    fi
    
    # Falls Docker immer noch nicht läuft, markiere als fehlgeschlagen
    if [ "${DOCKER_READY:-false}" != "true" ]; then
        echo "⚠️  Docker ist nicht verfügbar - Installation ohne Docker fortsetzen"
        DOCKER_INSTALLATION_FAILED=true
        DOCKER_READY=false
    fi
else
    echo "⚠️  Docker-Installation wurde übersprungen"
    DOCKER_READY=false
fi

# =============================================================================
# 3. DOCKER OPTIMIERUNG (NUR WENN DOCKER SICHER LÄUFT)
# =============================================================================
if [ "${DOCKER_READY:-false}" = "true" ]; then
    echo "⚙️ Optimiere Docker für Raspberry Pi 5..."

    # ÜBERSPRINGEN: Docker daemon.json Optimierung bei Problemen
    echo "⚠️  Docker-Optimierung übersprungen (um Stabilitätsprobleme zu vermeiden)"
    echo "   💡 Docker läuft mit Standard-Konfiguration"

    # 📁 PERSISTENTE DATENVERZEICHNISSE ERSTELLEN (nur wenn Docker läuft)
    echo "📁 Erstelle persistente Datenverzeichnisse..."
    sudo mkdir -p /opt/docker-data/{influxdb,grafana}

    # Setze Berechtigungen für Grafana (ID 472) und InfluxDB (ID 1000)
    echo "🔧 Setze Container-Berechtigungen..."
    sudo chown -R 472:472 /opt/docker-data/grafana 2>/dev/null || sudo chown -R 1000:1000 /opt/docker-data/grafana
    sudo chown -R 1000:1000 /opt/docker-data/influxdb
    sudo chmod 755 /opt/docker-data/{influxdb,grafana}

    echo "✅ Docker Basis-Konfiguration abgeschlossen"
else
    echo "⚠️  Docker-Optimierung übersprungen (Docker nicht verfügbar)"
fi

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
    
    # Docker-Compose nur kopieren wenn Docker verfügbar ist
    if [ "${DOCKER_READY:-false}" = "true" ]; then
        cp ../docker-compose-minimal.yml docker-compose.yml
        echo "   📦 Docker-Compose Konfiguration kopiert"
    else
        echo "   ⚠️  Docker-Compose übersprungen (Docker nicht verfügbar)"
    fi
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

    # Fallback: Docker Compose erstellen (nur wenn Docker verfügbar ist)
    if [ "${DOCKER_READY:-false}" = "true" ]; then
        echo "   📦 Erstelle Docker-Compose Fallback..."
        cat > docker-compose.yml << 'EOF'
# 📊 DOCKER HEALTHCHECKS & LOGGING (MUSS AM ANFANG STEHEN!)
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

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

EOF
    else
        echo "   ⚠️  Docker-Compose Fallback übersprungen (Docker nicht verfügbar)"
    fi

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
# 6. SYSTEMD SERVICE ERSTELLEN (MIT/OHNE DOCKER)
# =============================================================================
echo "⚙️ Erstelle Systemd Service (mit Python venv)..."

if [ "${DOCKER_READY:-false}" = "true" ]; then
    # Service mit Docker-Abhängigkeit
    sudo tee /etc/systemd/system/pi5-sensor-minimal.service > /dev/null << EOF
[Unit]
Description=Pi 5 Sensor Monitor (9 Sensors with venv + Docker)
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
    echo "   ✅ Service mit Docker-Integration erstellt"
else
    # Service nur mit Python (ohne Docker)
    sudo tee /etc/systemd/system/pi5-sensor-minimal.service > /dev/null << EOF
[Unit]
Description=Pi 5 Sensor Monitor (9 Sensors with venv, standalone)
After=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python sensor_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    echo "   ✅ Service ohne Docker-Abhängigkeit erstellt"
    echo "   ⚠️  HINWEIS: Sensordaten werden nur lokal gespeichert (kein InfluxDB)"
fi

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensor-minimal.service

# =============================================================================
# 7. DOCKER CONTAINER STARTEN (NUR WENN DOCKER VERFÜGBAR)
# =============================================================================
if [ "${DOCKER_READY:-false}" = "true" ]; then
    echo "🚀 Starte Docker Container mit Healthchecks..."
    docker compose up -d

    # Warten bis Container gesund sind
    echo "⏳ Warte auf Container Healthchecks..."
    echo "   📊 InfluxDB Healthcheck..."
    HEALTHCHECK_RETRIES=0
    while ! docker compose exec -T influxdb influx ping > /dev/null 2>&1; do
        echo "   ⏳ InfluxDB startet noch... ($((++HEALTHCHECK_RETRIES))/12)"
        sleep 5
        if [ $HEALTHCHECK_RETRIES -ge 12 ]; then
            echo "   ⚠️  InfluxDB Healthcheck Timeout, aber fortfahren..."
            break
        fi
    done
    
    if [ $HEALTHCHECK_RETRIES -lt 12 ]; then
        echo "   ✅ InfluxDB ist bereit"
    fi

    echo "   📈 Grafana Healthcheck..."
    HEALTHCHECK_RETRIES=0
    while ! curl -f http://localhost:3000/api/health > /dev/null 2>&1; do
        echo "   ⏳ Grafana startet noch... ($((++HEALTHCHECK_RETRIES))/12)"
        sleep 5
        if [ $HEALTHCHECK_RETRIES -ge 12 ]; then
            echo "   ⚠️  Grafana Healthcheck Timeout, aber fortfahren..."
            break
        fi
    done
    
    if [ $HEALTHCHECK_RETRIES -lt 12 ]; then
        echo "   ✅ Grafana ist bereit"
    fi
    
    echo "✅ Docker Container gestartet"
else
    echo "⚠️  Docker Container Start übersprungen (Docker nicht verfügbar)"
    echo "   💡 Nur Python Sensor-Monitor wird verwendet"
fi

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
echo "✅ Was wurde installiert/konfiguriert:"
if [ "${DOCKER_READY:-false}" = "true" ]; then
    if [ "$DOCKER_ALREADY_INSTALLED" = true ]; then
        echo "   🐳 Docker (bereits vorhanden) + InfluxDB + Grafana"
    else
        echo "   🐳 Docker (neu installiert) + InfluxDB + Grafana"
    fi
    echo "   🌡️  Support für 9 Sensoren (8x DS18B20 + 1x DHT22)"
    echo "   🏷️  Individualisierte Sensornamen"
    echo "   🔓 Grafana OHNE Login"
    echo "   ⚙️  Systemd Service mit venv + Docker"
else
    echo "   ⚠️  Docker NICHT verfügbar - Standalone Installation"
    echo "   🌡️  Support für 9 Sensoren (8x DS18B20 + 1x DHT22)"
    echo "   🏷️  Individualisierte Sensornamen"  
    echo "   📝 Sensor-Daten werden lokal gespeichert"
    echo "   ⚙️  Systemd Service mit venv (ohne Docker)"
fi
echo ""
if [ "${DOCKER_READY:-false}" = "true" ]; then
    echo "🌐 Verfügbare Services:"
    echo "   📊 Grafana: http://$(hostname -I | awk '{print $1}'):3000"
    echo "   🗄️  InfluxDB: http://$(hostname -I | awk '{print $1}'):8086"
else
    echo "⚠️  Web-Services nicht verfügbar (Docker-Problem):"
    echo "   � Grafana: Nicht verfügbar"
    echo "   🗄️  InfluxDB: Nicht verfügbar"
    echo "   💡 Sensor-Daten werden nur lokal geloggt"
fi
echo ""
echo "�🔧 Wichtige Befehle:"
echo "   Service starten: sudo systemctl start pi5-sensor-minimal"
echo "   Service stoppen: sudo systemctl stop pi5-sensor-minimal"
echo "   Logs anzeigen:   sudo journalctl -u pi5-sensor-minimal -f"
echo "   9 Sensoren test: cd $PROJECT_DIR && source venv/bin/activate && python test_all_sensors.py"
if [ "${DOCKER_READY:-false}" = "true" ]; then
    echo "   Docker monitor:  cd $PROJECT_DIR && ./docker_monitor.sh"
else
    echo "   Docker diagnose: ./docker_diagnose.sh"
fi
echo ""
echo "🐳 Docker Status:"
echo "   Version: $(docker --version 2>/dev/null || echo 'Nicht verfügbar')"
echo "   Status:  $(sudo systemctl is-active docker 2>/dev/null && echo '✅ Aktiv' || echo '❌ Inaktiv')"
echo "   User:    $(groups $USER | grep -q docker && echo '✅ Docker-Gruppe' || echo '⚠️  Neustart für Docker-Gruppe nötig')"
echo ""
echo "⚠️  HINWEISE:"
if [ "${DOCKER_READY:-false}" = "true" ]; then
    if [ "$DOCKER_ALREADY_INSTALLED" = true ]; then
        echo "   🐳 Docker war bereits installiert - nur konfiguriert"
        echo "   🔄 Neustart empfohlen für GPIO (falls nicht schon aktiviert)"
    else
        echo "   🔄 NEUSTART ERFORDERLICH für Docker-Gruppe und GPIO!"
    fi
    echo "   📋 Nach Neustart startet alles automatisch"
else
    echo "   ❌ Docker-Installation fehlgeschlagen"
    echo "   🔧 Verwende './docker_diagnose.sh' für Fehlerbehebung"
    echo "   🌡️  Sensor-Monitor läuft trotzdem (ohne Web-Interface)"
    echo "   🔄 Neustart empfohlen für GPIO"
fi
echo ""
read -p "🔄 Jetzt neu starten? (ja/nein): " reboot_now
if [ "$reboot_now" = "ja" ]; then
    sudo reboot
fi

echo "🚀 Projekt bereit! Nach Neustart startet alles automatisch."
echo "🎯 Erwartung: 9 Sensoren = 10 Messwerte (8x DS18B20 + DHT22 Temp + DHT22 Humidity)"
