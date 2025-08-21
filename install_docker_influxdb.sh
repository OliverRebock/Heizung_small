#!/bin/bash
#
# Docker + InfluxDB Installation für Raspberry Pi 5
# Erweitert das Sensor-System um Datenbank-Integration
#

echo "🐳 Docker + InfluxDB Installation für Raspberry Pi 5"
echo "=================================================="
echo "Erweitert das Pi 5 Sensor-System um Datenbank-Logging"
echo ""

# Prüfe ob Sensor-System bereits installiert ist
if [ ! -d "$HOME/sensor-monitor-pi5" ]; then
    echo "❌ Sensor-System nicht gefunden!"
    echo "💡 Führe zuerst die Basis-Installation aus:"
    echo "💡 curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors.sh | bash"
    exit 1
fi

# In sensor-monitor-pi5 Verzeichnis wechseln
cd "$HOME/sensor-monitor-pi5"

echo "🔍 1. System-Anforderungen prüfen..."

# Prüfe verfügbaren Speicherplatz (Docker braucht ~2GB)
AVAILABLE_SPACE=$(df /home | awk 'NR==2 {print $4}')
REQUIRED_SPACE=2000000  # 2GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "⚠️  Warnung: Wenig Speicherplatz verfügbar"
    echo "💡 Docker + InfluxDB benötigen ~2GB freien Speicher"
    read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Ausreichend Speicherplatz verfügbar"
fi

# Prüfe ob als root ausgeführt
if [[ $EUID -eq 0 ]]; then
   echo "❌ Bitte NICHT als root ausführen!"
   echo "💡 Verwende: ./install_docker_influxdb.sh"
   exit 1
fi

echo "🐳 2. Docker Installation..."

# Prüfe ob Docker bereits installiert ist
if command -v docker &> /dev/null; then
    echo "✅ Docker bereits installiert"
    DOCKER_VERSION=$(docker --version)
    echo "   📦 Version: $DOCKER_VERSION"
else
    echo "📦 Installiere Docker für Raspberry Pi 5..."
    
    # Offizielle Docker Installation für Pi 5
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    
    # Benutzer zur docker Gruppe hinzufügen
    sudo usermod -aG docker $USER
    
    # Aufräumen
    rm get-docker.sh
    
    echo "✅ Docker installiert"
    echo "⚠️  Neuanmeldung erforderlich für Docker-Berechtigungen"
    REBOOT_NEEDED=true
fi

echo "🔧 3. Docker Compose Installation..."

# Prüfe Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose bereits verfügbar"
    COMPOSE_VERSION=$(docker-compose --version)
    echo "   📦 Version: $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
    echo "✅ Docker Compose Plugin verfügbar"
    COMPOSE_VERSION=$(docker compose version)
    echo "   📦 Version: $COMPOSE_VERSION"
else
    echo "📦 Installiere Docker Compose..."
    
    # Zuerst versuchen: Plugin Installation
    sudo apt update
    sudo apt install -y docker-compose-plugin
    
    # Fallback: Legacy docker-compose via pip
    if ! docker compose version &> /dev/null; then
        echo "   📦 Installiere Legacy Docker Compose..."
        sudo pip3 install docker-compose
    fi
    
    echo "✅ Docker Compose installiert"
fi

echo "🗄️  4. InfluxDB Dateien herunterladen..."

# Docker Compose für InfluxDB + Grafana
if [ ! -f "docker-compose.yml" ]; then
    echo "   📦 Lade docker-compose.yml..."
    wget -O docker-compose.yml https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/docker-compose.yml
else
    echo "   ✅ docker-compose.yml bereits vorhanden"
fi

# InfluxDB Integration Script
if [ ! -f "sensor_influxdb.py" ]; then
    echo "   📦 Lade sensor_influxdb.py..."
    wget -O sensor_influxdb.py https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/sensor_influxdb.py
    chmod +x sensor_influxdb.py
else
    echo "   ✅ sensor_influxdb.py bereits vorhanden"
fi

# Docker Autostart Script
if [ ! -f "setup_docker_autostart.sh" ]; then
    echo "   📦 Lade setup_docker_autostart.sh..."
    wget -O setup_docker_autostart.sh https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/setup_docker_autostart.sh
    chmod +x setup_docker_autostart.sh
else
    echo "   ✅ setup_docker_autostart.sh bereits vorhanden"
fi

echo "🐍 5. Python InfluxDB Client installieren..."

# Virtual Environment aktivieren
source venv/bin/activate

# InfluxDB Client installieren
pip install influxdb-client

echo "   ✅ InfluxDB Client installiert"

echo "📄 6. InfluxDB Scripts erstellen..."

# InfluxDB Monitoring Script erstellen/aktualisieren
cat > start_influxdb_monitoring.sh << 'EOF'
#!/bin/bash
echo "🗄️ InfluxDB Monitoring - Pi 5"
echo "============================"
cd "$HOME/sensor-monitor-pi5"
source venv/bin/activate

echo "Verfügbare InfluxDB Modi:"
echo "1. 30 Sekunden → InfluxDB (empfohlen)"
echo "2. 60 Sekunden → InfluxDB" 
echo "3. Test InfluxDB Verbindung"
echo "4. Einmalige Messung → InfluxDB"

read -p "Wähle Modus (1-4): " mode

case $mode in
    1)
        echo "⏰ Starte 30s InfluxDB Monitoring..."
        python sensor_influxdb.py continuous 30
        ;;
    2)
        echo "⏰ Starte 60s InfluxDB Monitoring..."
        python sensor_influxdb.py continuous 60
        ;;
    3)
        echo "🔍 Teste InfluxDB Verbindung..."
        python sensor_influxdb.py test
        ;;
    4)
        echo "📊 Einmalige InfluxDB Messung..."
        python sensor_influxdb.py single
        ;;
    *)
        echo "❌ Ungültige Auswahl"
        exit 1
        ;;
esac
EOF

chmod +x start_influxdb_monitoring.sh

echo "🔍 7. Docker-Test (falls möglich)..."

# Teste Docker (nur wenn Benutzer in docker Gruppe ist)
if groups $USER | grep -q docker; then
    echo "   🔍 Teste Docker..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        echo "   ✅ Docker funktioniert"
        DOCKER_WORKING=true
    else
        echo "   ⚠️  Docker-Test fehlgeschlagen - Neuanmeldung erforderlich"
        DOCKER_WORKING=false
    fi
else
    echo "   ⚠️  Docker-Berechtigungen noch nicht aktiv - Neuanmeldung erforderlich"
    DOCKER_WORKING=false
    REBOOT_NEEDED=true
fi

echo ""
echo "✅ Docker + InfluxDB Installation abgeschlossen!"
echo ""

if [ "$REBOOT_NEEDED" = true ] || [ "$DOCKER_WORKING" = false ]; then
    echo "⚠️  NEUANMELDUNG/NEUSTART ERFORDERLICH!"
    echo "💡 Docker-Berechtigungen werden erst nach Neuanmeldung aktiv"
    echo ""
    echo "Nach Neuanmeldung/Neustart:"
    echo "💡 cd \$HOME/sensor-monitor-pi5"
    echo "💡 docker-compose up -d  # Container starten"
    echo "💡 ./setup_docker_autostart.sh  # Autostart einrichten"
    echo "💡 ./start_influxdb_monitoring.sh  # Monitoring starten"
else
    echo "🚀 Container können sofort gestartet werden:"
    echo "💡 docker-compose up -d"
    echo "💡 ./setup_docker_autostart.sh"
    echo "💡 ./start_influxdb_monitoring.sh"
    
    # Automatisch Container starten (falls Docker funktioniert)
    echo ""
    read -p "Container jetzt starten? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Starte InfluxDB Container..."
        docker-compose up -d
        sleep 5
        echo "🔍 Container Status:"
        docker-compose ps
    fi
fi

echo ""
echo "🌐 Nach Container-Start verfügbar:"
echo "💡 InfluxDB UI: http://localhost:8086"
echo "💡 Grafana: http://localhost:3000"
echo "💡 Login: pi5admin / pi5sensors2024"
echo ""
echo "📊 InfluxDB Monitoring:"
echo "💡 python sensor_influxdb.py continuous 30  # 30s Intervall"
echo "💡 python sensor_influxdb.py test           # Verbindungstest"
echo ""
echo "🎉 Installation erfolgreich!"
