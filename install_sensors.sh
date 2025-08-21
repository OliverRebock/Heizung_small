#!/bin/bash
"""
Installations-Script für 6x DS18B20 + 1x DHT22 Sensor-Monitor
Speziell optimiert für Raspberry Pi 5
"""

echo "🌡️ Sensor-Monitor Installation für Raspberry Pi 5"
echo "================================================="
echo "Hardware: 6x DS18B20 + 1x DHT22"
echo "Platform: Raspberry Pi 5 (optimiert)"
echo ""

# Prüfe ob als root ausgeführt
if [[ $EUID -eq 0 ]]; then
   echo "❌ Bitte NICHT als root ausführen!"
   echo "💡 Verwende: ./install_sensors.sh"
   exit 1
fi

# Prüfe Raspberry Pi 5
if ! grep -q "Raspberry Pi 5" /proc/cpuinfo; then
    echo "⚠️  Warnung: Läuft nicht auf Raspberry Pi 5"
    echo "💡 Dieses Script ist für Pi 5 optimiert"
    read -p "Trotzdem fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Raspberry Pi 5 erkannt - verwende optimierte Installation"
fi

echo "📦 1. System-Update für Pi 5..."
sudo apt update && sudo apt upgrade -y

echo "📦 2. Pi 5 spezifische Pakete installieren..."
sudo apt install -y python3 python3-pip python3-venv git
sudo apt install -y python3-dev python3-setuptools build-essential cmake
sudo apt install -y gpiod libgpiod-dev

echo "📁 3. Projekt-Verzeichnis erstellen..."
mkdir -p ~/sensor-monitor-pi5
cd ~/sensor-monitor-pi5

echo "🐍 4. Python Virtual Environment für Pi 5..."
python3 -m venv venv
source venv/bin/activate

echo "📚 5. Pi 5 optimierte Python-Bibliotheken..."
pip install --upgrade pip setuptools wheel

# Pi 5 GPIO-Bibliotheken (lgpio ist Pflicht!)
echo "   🔧 Installiere lgpio für Pi 5..."
pip install lgpio

echo "   🔧 Installiere CircuitPython für Pi 5..."
pip install adafruit-circuitpython-dht
pip install adafruit-blinka

echo "   🔧 Zusätzliche Pi 5 GPIO-Bibliotheken..."
pip install gpiozero
pip install RPi.GPIO  # Fallback

echo "   📊 InfluxDB Client für Datenbank-Integration..."
pip install influxdb-client

echo "🐳 7. Docker Installation für InfluxDB..."
# Prüfe ob Docker bereits installiert ist
if ! command -v docker &> /dev/null; then
    echo "   📦 Installiere Docker für Pi 5..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "   ✅ Docker installiert - Neuanmeldung erforderlich"
else
    echo "   ✅ Docker bereits installiert"
fi

# Docker Compose installieren/aktualisieren
if ! command -v docker-compose &> /dev/null; then
    echo "   📦 Installiere Docker Compose..."
    sudo apt install -y docker-compose-plugin
    # Fallback: Legacy docker-compose
    sudo pip3 install docker-compose
else
    echo "   ✅ Docker Compose bereits verfügbar"
fi

echo "🔧 8. 1-Wire Interface für Pi 5 konfigurieren..."

# Pi 5 verwendet /boot/firmware/config.txt
CONFIG_FILE="/boot/firmware/config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Pi 5 Config-Datei nicht gefunden: $CONFIG_FILE"
    echo "💡 Stelle sicher, dass du Raspberry Pi 5 verwendest"
    exit 1
fi

# Prüfe ob 1-Wire bereits konfiguriert
if ! grep -q "dtoverlay=w1-gpio" $CONFIG_FILE; then
    echo "   📝 Füge 1-Wire Konfiguration zu $CONFIG_FILE hinzu..."
    echo "" | sudo tee -a $CONFIG_FILE
    echo "# Sensor-Monitor für Pi 5" | sudo tee -a $CONFIG_FILE
    echo "dtoverlay=w1-gpio,gpiopin=4" | sudo tee -a $CONFIG_FILE
    echo "dtparam=i2c_arm=on" | sudo tee -a $CONFIG_FILE
    echo "dtparam=spi=on" | sudo tee -a $CONFIG_FILE
    REBOOT_NEEDED=true
else
    echo "   ✅ 1-Wire bereits konfiguriert"
    REBOOT_NEEDED=false
fi

# Module für Pi 5 konfigurieren
echo "   📝 Konfiguriere Kernel-Module für Pi 5..."
if ! grep -q "w1-gpio" /etc/modules; then
    echo "w1-gpio" | sudo tee -a /etc/modules
fi

if ! grep -q "w1-therm" /etc/modules; then
    echo "w1-therm" | sudo tee -a /etc/modules
fi

echo "⚡ 9. Pi 5 Performance-Optimierungen..."
echo "   📝 GPU-Memory für headless Betrieb optimieren..."
if ! grep -q "gpu_mem=16" $CONFIG_FILE; then
    echo "gpu_mem=16" | sudo tee -a $CONFIG_FILE
fi

echo "   📝 USB-Power für stabile Sensoren..."
if ! grep -q "max_usb_current=1" $CONFIG_FILE; then
    echo "max_usb_current=1" | sudo tee -a $CONFIG_FILE
fi

echo "👥 10. GPIO-Berechtigungen für Pi 5..."
sudo usermod -a -G gpio $USER
sudo usermod -a -G dialout $USER

echo "📄 11. Python-Scripts herunterladen..."
# Sensor-Monitor Script
wget -O sensor_monitor.py https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/sensor_monitor.py
chmod +x sensor_monitor.py

# Test-Script
wget -O test_sensors_fixed.py https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/test_sensors_fixed.py  
chmod +x test_sensors_fixed.py

# InfluxDB Integration
wget -O sensor_influxdb.py https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/sensor_influxdb.py
chmod +x sensor_influxdb.py

# Docker Compose für InfluxDB
wget -O docker-compose.yml https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/docker-compose.yml

echo "📄 12. Pi 5 Test-Scripts erstellen..."
cat > test_sensors.sh << 'EOF'
#!/bin/bash
echo "🌡️ Sensor-Test für Raspberry Pi 5"
echo "================================"
cd ~/sensor-monitor-pi5
source venv/bin/activate

echo "Führe einmalige Sensor-Messung durch..."
python sensor_monitor.py single
EOF

chmod +x test_sensors.sh

cat > start_monitoring.sh << 'EOF'
#!/bin/bash
echo "🔄 Kontinuierliche Überwachung - Pi 5"
echo "===================================="
cd ~/sensor-monitor-pi5
source venv/bin/activate

echo "Verfügbare Monitoring-Modi:"
echo "1. 30 Sekunden Intervall (empfohlen)"
echo "2. 60 Sekunden Intervall" 
echo "3. 300 Sekunden Intervall (5 Min)"
echo "4. High-Performance Modus (10s)"

read -p "Wähle Modus (1-4): " mode

case $mode in
    1)
        echo "⏰ Starte 30s Monitoring..."
        python sensor_monitor.py continuous 30
        ;;
    2)
        echo "⏰ Starte 60s Monitoring..."
        python sensor_monitor.py continuous 60
        ;;
    3)
        echo "⏰ Starte 300s Monitoring..."
        python sensor_monitor.py continuous 300
        ;;
    4)
        echo "⚡ Starte High-Performance Modus..."
        python sensor_monitor.py continuous 10
        ;;
    *)
        echo "❌ Ungültige Auswahl"
        exit 1
        ;;
esac
EOF

chmod +x start_monitoring.sh

cat > start_influxdb_monitoring.sh << 'EOF'
#!/bin/bash
echo "🗄️ InfluxDB Monitoring - Pi 5"
echo "============================"
cd ~/sensor-monitor-pi5
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

echo "🔍 13. Pi 5 Hardware-Check..."
echo "    📝 Erstelle Pi 5 Hardware-Check Script..."
cat > pi5_hardware_check.sh << 'EOF'
#!/bin/bash
echo "🔧 Raspberry Pi 5 Hardware-Check"
echo "================================"

echo "🖥️  System-Info:"
cat /proc/cpuinfo | grep "Model"
echo ""

echo "🔌 GPIO-Status:"
if command -v pinout &> /dev/null; then
    echo "   ✅ pinout verfügbar"
else
    echo "   📦 Installiere gpio-tools..."
    sudo apt install -y python3-gpiozero
fi

echo "🌡️  1-Wire Interface:"
if [ -d "/sys/bus/w1/devices/" ]; then
    SENSOR_COUNT=$(ls /sys/bus/w1/devices/28-* 2>/dev/null | wc -l)
    echo "   📊 DS18B20 Sensoren gefunden: $SENSOR_COUNT"
    if [ $SENSOR_COUNT -gt 0 ]; then
        echo "   📝 Sensor-IDs:"
        ls /sys/bus/w1/devices/28-* 2>/dev/null | sed 's|.*/||' | head -6
    fi
else
    echo "   ❌ 1-Wire Interface nicht verfügbar"
    echo "   💡 Neustart erforderlich: sudo reboot"
fi

echo ""
echo "🐍 Python-Umgebung:"
cd ~/sensor-monitor-pi5
source venv/bin/activate
python3 -c "
try:
    import lgpio
    print('   ✅ lgpio verfügbar')
except ImportError:
    print('   ❌ lgpio fehlt')

try:
    import board
    import adafruit_dht
    print('   ✅ CircuitPython DHT verfügbar')
except ImportError:
    print('   ❌ CircuitPython DHT fehlt')

try:
    import gpiozero
    print('   ✅ gpiozero verfügbar')
except ImportError:
    print('   ❌ gpiozero fehlt')
"

echo ""
echo "✅ Pi 5 Hardware-Check abgeschlossen"
EOF

chmod +x pi5_hardware_check.sh

echo ""
echo "✅ Installation für Raspberry Pi 5 abgeschlossen!"
echo ""
echo "📋 Pi 5 Verdrahtungs-Check:"
echo "DS18B20 Sensoren (1-Wire Bus):"
echo "  VDD (rot)     → 3.3V (Pin 1)"
echo "  GND (schwarz) → GND (Pin 6)"
echo "  Data (gelb)   → GPIO 4 (Pin 7) + 4.7kΩ Pull-up"
echo ""
echo "DHT22 Sensor (Pi 5 optimiert):"
echo "  VCC → 3.3V (Pin 17)"
echo "  GND → GND (Pin 20)" 
echo "  Data → GPIO 18 (Pin 12) + 10kΩ Pull-up (empfohlen)"
echo ""

if [ "$REBOOT_NEEDED" = true ]; then
    echo "⚠️  NEUSTART ERFORDERLICH für Pi 5!"
    echo "💡 Führe aus: sudo reboot"
    echo ""
    echo "Nach dem Neustart:"
    echo "💡 cd ~/sensor-monitor-pi5"
    echo "💡 docker-compose up -d  # InfluxDB Container starten"
    echo "💡 ./pi5_hardware_check.sh"
    echo "💡 ./test_sensors.sh"
    echo "💡 ./start_influxdb_monitoring.sh  # InfluxDB Integration"
else
    echo "🚀 Sofort starten:"
    echo "💡 ./pi5_hardware_check.sh"
    echo "💡 ./test_sensors.sh"
    echo ""
    echo "🐳 InfluxDB Container starten:"
    echo "💡 docker-compose up -d"
    echo "💡 ./start_influxdb_monitoring.sh"
fi

echo ""
echo "📊 Pi 5 manuelle Tests:"
echo "💡 cd ~/sensor-monitor-pi5"
echo "💡 source venv/bin/activate"
echo "💡 python sensor_monitor.py"
echo ""
echo "🗄️ InfluxDB Integration:"
echo "💡 docker-compose up -d  # Container starten"
echo "💡 python sensor_influxdb.py single  # Test"
echo "💡 python sensor_influxdb.py continuous 30  # Dauerhaft"
echo ""
echo "🌐 Web-Interfaces:"
echo "💡 InfluxDB UI: http://localhost:8086"
echo "💡 Grafana: http://localhost:3000"
echo "💡 Login: pi5admin / pi5sensors2024"
echo ""

# Pi 5 spezifischer Sensor-Check
./pi5_hardware_check.sh

echo ""
echo "🎉 Raspberry Pi 5 Installation erfolgreich!"
echo "🔋 Pi 5 Performance-Features aktiviert"