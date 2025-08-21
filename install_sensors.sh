#!/bin/bash
"""
Installations-Script für 6x DS18B20 + 1x DHT22 Sensor-Monitor
Speziell optimiert für Raspberry Pi 5
"""

echo "🌡️  Sensor-Monitor Installation für Raspberry Pi 5"
echo "================================================="
echo "Hardware: 6x DS18B20 + 1x DHT22"
echo "Platform: Raspberry Pi 5 (optimiert)"
echo ""

# Prüfe ob als root ausgeführt
if [[ $EUID -eq 0 ]]; then
   echo "❌ Bitte NICHT als root ausführen!"
   echo "💡 Verwende: ./install_sensors_pi5.sh"
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

echo "🔧 6. 1-Wire Interface für Pi 5 konfigurieren..."

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

echo "⚡ 7. Pi 5 Performance-Optimierungen..."
echo "   📝 GPU-Memory für headless Betrieb optimieren..."
if ! grep -q "gpu_mem=16" $CONFIG_FILE; then
    echo "gpu_mem=16" | sudo tee -a $CONFIG_FILE
fi

echo "   📝 USB-Power für stabile Sensoren..."
if ! grep -q "max_usb_current=1" $CONFIG_FILE; then
    echo "max_usb_current=1" | sudo tee -a $CONFIG_FILE
fi

echo "� 8. GPIO-Berechtigungen für Pi 5..."
sudo usermod -a -G gpio $USER
sudo usermod -a -G dialout $USER

echo "� 9. Pi 5 Test-Scripts erstellen..."
cat > test_sensors_pi5.sh << 'EOF'
#!/bin/bash
echo "🌡️ Sensor-Test für Raspberry Pi 5"
cd ~/sensor-monitor-pi5
source venv/bin/activate
python sensor_monitor_pi5.py
EOF

chmod +x test_sensors_pi5.sh

cat > start_monitoring_pi5.sh << 'EOF'
#!/bin/bash
echo "🔄 Kontinuierliche Überwachung - Pi 5"
cd ~/sensor-monitor-pi5
source venv/bin/activate
python sensor_monitor_pi5.py
EOF

chmod +x start_monitoring_pi5.sh

echo "🔍 10. Pi 5 Hardware-Check..."
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
    echo "💡 ./pi5_hardware_check.sh"
    echo "💡 ./test_sensors_pi5.sh"
else
    echo "🚀 Sofort starten:"
    echo "💡 ./pi5_hardware_check.sh"
    echo "💡 ./test_sensors_pi5.sh"
fi

echo ""
echo "📊 Pi 5 manuelle Tests:"
echo "💡 cd ~/sensor-monitor-pi5"
echo "💡 source venv/bin/activate"
echo "💡 python sensor_monitor_pi5.py"
echo ""

# Pi 5 spezifischer Sensor-Check
./pi5_hardware_check.sh

echo ""
echo "🎉 Raspberry Pi 5 Installation erfolgreich!"
echo "🔋 Pi 5 Performance-Features aktiviert"
