#!/bin/bash
# =============================================================================
# INSTALL SENSORS ONLY - Nur Pi5 Sensoren, KEIN Docker/Grafana
# =============================================================================
# Für Systeme mit bereits existierender InfluxDB/Grafana Installation
# Installiert NUR: Python Umgebung + Sensor Reader + Services
# =============================================================================

set -e

echo "🌡️ PI5 SENSORS ONLY INSTALLATION"
echo "================================="
echo "📦 Installiert NUR Sensoren - KEIN Docker/Grafana"
echo "🎯 Für Systeme mit existierender InfluxDB"
echo ""

# Parameter für existierende InfluxDB
INFLUX_URL=""
INFLUX_TOKEN=""
INFLUX_ORG=""
INFLUX_BUCKET=""

if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
    # Parameter-basiert: install_sensors_only.sh INFLUX_URL TOKEN ORG BUCKET
    INFLUX_URL="$1"
    INFLUX_TOKEN="$2"
    INFLUX_ORG="$3"
    INFLUX_BUCKET="$4"
    echo "📋 InfluxDB Parameter erkannt:"
    echo "   🗄️ URL: $INFLUX_URL"
    echo "   🔑 Token: ${INFLUX_TOKEN:0:10}..."
    echo "   🏢 Org: $INFLUX_ORG"
    echo "   📊 Bucket: $INFLUX_BUCKET"
elif [ -t 0 ]; then
    # Interaktiv
    echo ""
    echo "🗄️ Existierende InfluxDB Konfiguration:"
    read -p "   InfluxDB URL (z.B. http://localhost:8086): " INFLUX_URL
    if [ -z "$INFLUX_URL" ]; then
        echo "❌ InfluxDB URL ist erforderlich!"
        exit 1
    fi

    read -p "   InfluxDB Token: " INFLUX_TOKEN
    if [ -z "$INFLUX_TOKEN" ]; then
        echo "❌ InfluxDB Token ist erforderlich!"
        exit 1
    fi

    read -p "   InfluxDB Organization: " INFLUX_ORG
    if [ -z "$INFLUX_ORG" ]; then
        echo "❌ InfluxDB Organization ist erforderlich!"
        exit 1
    fi

    read -p "   InfluxDB Bucket: " INFLUX_BUCKET
    if [ -z "$INFLUX_BUCKET" ]; then
        echo "❌ InfluxDB Bucket ist erforderlich!"
        exit 1
    fi
else
    echo "❌ Keine Parameter angegeben und kein TTY verfügbar!"
    echo "Usage: $0 INFLUX_URL TOKEN ORG BUCKET"
    echo ""
    echo "Beispiele:"
    echo "$0 http://localhost:8086 myToken myOrg sensors"
    echo "$0 http://192.168.1.100:8086 influx-token homelab pi5-sensors"
    exit 1
fi

echo ""

# =============================================================================
# 1. SYSTEM VORBEREITEN (OHNE DOCKER!)
# =============================================================================
echo "🔧 System vorbereiten (OHNE Docker Installation)..."
sudo apt update -y
sudo apt install -y python3-pip python3-venv git curl wget

# GPIO für DS18B20 aktivieren
echo "🔌 GPIO aktivieren..."
if ! grep -q "dtoverlay=w1-gpio" /boot/firmware/config.txt; then
    echo "dtoverlay=w1-gpio,gpiopin=4" | sudo tee -a /boot/firmware/config.txt
    echo "   ✅ GPIO konfiguriert"
else
    echo "   ✅ GPIO bereits konfiguriert"
fi

# =============================================================================
# 2. PROJEKTORDNER ERSTELLEN
# =============================================================================
echo "📁 Projektordner erstellen..."
cd ~
if [ -d "pi5-sensors" ]; then
    echo "   ⚠️  Ordner pi5-sensors existiert bereits - Backup erstellen..."
    mv pi5-sensors pi5-sensors-backup-$(date +%Y%m%d-%H%M%S)
fi

mkdir -p pi5-sensors
cd pi5-sensors

# =============================================================================
# 3. PYTHON VENV UND PACKAGES (OHNE DOCKER!)
# =============================================================================
echo "🐍 Python Virtual Environment erstellen..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Python Packages installieren (Pi 5 optimiert, KEIN Docker)..."
pip install --upgrade pip

# NUR Sensor-relevante Packages
pip install influxdb-client RPi.GPIO adafruit-blinka
pip install adafruit-circuitpython-dht --force-reinstall

echo "   ✅ Python Packages installiert (OHNE Docker Dependencies)"

# =============================================================================
# 4. KONFIGURATIONSDATEI (FÜR EXISTIERENDE INFLUXDB)
# =============================================================================
echo "⚙️  Konfigurationsdatei für existierende InfluxDB erstellen..."
cat > config.ini << EOF
[sensors]
ds18b20_count = 8
dht22_gpio = 18

[database]
url = $INFLUX_URL
token = $INFLUX_TOKEN
org = $INFLUX_ORG
bucket = $INFLUX_BUCKET

[labels]
ds18b20_1 = HK1 Vorlauf
ds18b20_2 = HK1 Rücklauf
ds18b20_3 = HK2 Vorlauf
ds18b20_4 = HK2 Rücklauf
ds18b20_5 = HK3 Vorlauf
ds18b20_6 = HK3 Rücklauf
ds18b20_7 = HK4 Vorlauf
ds18b20_8 = HK4 Rücklauf
dht22 = Raumklima Heizraum
EOF

echo "   ✅ Konfiguration erstellt für:"
echo "      URL: $INFLUX_URL"
echo "      Bucket: $INFLUX_BUCKET"

# =============================================================================
# 5. SENSOR READER (STANDALONE VERSION)
# =============================================================================
echo "📊 Sensor Reader erstellen (Standalone, KEIN Docker)..."
cat > sensor_reader.py << 'EOF'
#!/usr/bin/env python3
"""
Pi5 Sensor Reader - STANDALONE VERSION (KEIN Docker)
Für existierende InfluxDB Installationen
Optimiert für Raspberry Pi 5 mit 8x DS18B20 + 1x DHT22
"""

import time
import glob
import configparser
import sys
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

class Pi5SensorReaderStandalone:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('config.ini')
        self.setup_influxdb()
        
    def setup_influxdb(self):
        """InfluxDB Verbindung zu existierender Installation"""
        url = self.config.get('database', 'url')
        token = self.config.get('database', 'token')
        org = self.config.get('database', 'org')
        
        print(f"📊 Verbinde zu existierender InfluxDB: {url}")
        print(f"🏢 Organisation: {org}")
        print(f"📦 Bucket: {self.config.get('database', 'bucket')}")
        
        try:
            self.client = InfluxDBClient(url=url, token=token, org=org)
            self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
            
            # Verbindung testen
            health = self.client.health()
            print(f"✅ InfluxDB Status: {health.status}")
            
        except Exception as e:
            print(f"❌ InfluxDB Verbindung fehlgeschlagen: {e}")
            print("   Prüfe URL, Token und Netzwerk-Verbindung")
            sys.exit(1)
        
    def read_ds18b20_sensors(self):
        """Lese alle DS18B20 Sensoren"""
        sensors = []
        devices = glob.glob('/sys/bus/w1/devices/28-*')
        
        if not devices:
            print("   ⚠️  Keine DS18B20 Sensoren gefunden - prüfe GPIO Konfiguration")
        
        for i, device in enumerate(devices[:8], 1):
            try:
                with open(f"{device}/w1_slave", 'r') as f:
                    data = f.read()
                if 'YES' in data:
                    temp_pos = data.find('t=') + 2
                    temp = float(data[temp_pos:]) / 1000.0
                    
                    name = self.config.get('labels', f'ds18b20_{i}', fallback=f'Sensor {i}')
                    sensors.append({
                        'name': name,
                        'temperature': temp,
                        'sensor_id': f'ds18b20_{i}'
                    })
                    print(f"   DS18B20 {i}: {temp:.1f}°C ({name})")
            except Exception as e:
                print(f"   ❌ DS18B20 {i}: {e}")
                
        return sensors
        
    def read_dht22(self):
        """Lese DHT22 Sensor - Pi 5 optimiert"""
        dht = None
        try:
            import adafruit_dht
            import board
            
            dht = adafruit_dht.DHT22(board.D18, use_pulseio=False)
            
            # 5 Versuche für Pi 5
            for attempt in range(5):
                try:
                    temp = dht.temperature
                    humidity = dht.humidity
                    
                    if temp is not None and humidity is not None:
                        name = self.config.get('labels', 'dht22', fallback='DHT22')
                        print(f"   DHT22: {temp:.1f}°C, {humidity:.1f}% ({name})")
                        return {
                            'name': name,
                            'temperature': temp,
                            'humidity': humidity,
                            'sensor_id': 'dht22'
                        }
                        
                except RuntimeError as e:
                    if attempt < 4:
                        time.sleep(1)
                        continue
                    else:
                        print(f"   ❌ DHT22: {e}")
                        
        except ImportError:
            print("   ⚠️  DHT22: Adafruit DHT library nicht verfügbar")
        except Exception as e:
            print(f"   ❌ DHT22: {e}")
        finally:
            if dht:
                dht.exit()
                
        return None
        
    def write_to_influxdb(self, sensors, dht_data):
        """Schreibe Sensordaten zu existierender InfluxDB"""
        points = []
        bucket = self.config.get('database', 'bucket')
        
        # DS18B20 Sensoren
        for sensor in sensors:
            point = Point("temperature") \
                .tag("sensor_id", sensor['sensor_id']) \
                .tag("sensor_name", sensor['name']) \
                .tag("sensor_type", "DS18B20") \
                .tag("source", "pi5-sensors-standalone") \
                .field("value", sensor['temperature']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(point)
            
        # DHT22 Sensor
        if dht_data:
            temp_point = Point("temperature") \
                .tag("sensor_id", dht_data['sensor_id']) \
                .tag("sensor_name", dht_data['name']) \
                .tag("sensor_type", "DHT22") \
                .tag("source", "pi5-sensors-standalone") \
                .field("value", dht_data['temperature']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(temp_point)
            
            humidity_point = Point("humidity") \
                .tag("sensor_id", dht_data['sensor_id']) \
                .tag("sensor_name", dht_data['name']) \
                .tag("sensor_type", "DHT22") \
                .tag("source", "pi5-sensors-standalone") \
                .field("value", dht_data['humidity']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(humidity_point)
            
        try:
            self.write_api.write(bucket=bucket, record=points)
            print(f"   ✅ {len(points)} Datenpunkte zu '{bucket}' geschrieben")
        except Exception as e:
            print(f"   ❌ InfluxDB Schreibfehler: {e}")
            
    def run_once(self):
        """Führe eine Sensor-Lesung durch"""
        print(f"🌡️  Sensor-Lesung {time.strftime('%H:%M:%S')} (Standalone)")
        
        # DS18B20 Sensoren lesen
        ds18b20_sensors = self.read_ds18b20_sensors()
        
        # DHT22 Sensor lesen
        dht22_data = self.read_dht22()
        
        # Zu existierender InfluxDB schreiben
        self.write_to_influxdb(ds18b20_sensors, dht22_data)
        
        return len(ds18b20_sensors) + (1 if dht22_data else 0)
        
    def run_continuous(self):
        """Kontinuierliche Sensor-Überwachung"""
        print("🚀 Starte kontinuierliche Sensor-Überwachung (Standalone)")
        print("   📊 Schreibt zu existierender InfluxDB")
        print("   ⏱️  Interval: 30 Sekunden")
        print("   🛑 Ctrl+C zum Beenden")
        print("")
        
        while True:
            try:
                count = self.run_once()
                print(f"   📊 {count} Sensoren gelesen")
                print("")
                time.sleep(30)
            except KeyboardInterrupt:
                print("\n👋 Sensor-Überwachung beendet")
                break
            except Exception as e:
                print(f"   ❌ Fehler: {e}")
                time.sleep(10)

if __name__ == "__main__":
    reader = Pi5SensorReaderStandalone()
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        reader.run_once()
    else:
        reader.run_continuous()
EOF

# =============================================================================
# 6. SYSTEMD SERVICE (STANDALONE)
# =============================================================================
echo "⚙️  Systemd Service erstellen (Standalone, KEIN Docker)..."
sudo tee /etc/systemd/system/pi5-sensors-standalone.service > /dev/null << EOF
[Unit]
Description=Pi5 Sensor Reader Standalone (KEIN Docker)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/pi5-sensors
ExecStart=/home/$USER/pi5-sensors/venv/bin/python sensor_reader.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# =============================================================================
# 7. SERVICES AKTIVIEREN
# =============================================================================
echo "🔧 Services aktivieren..."
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensors-standalone.service
sudo systemctl start pi5-sensors-standalone.service

# =============================================================================
# 8. VERBINDUNGSTEST
# =============================================================================
echo ""
echo "🧪 InfluxDB Verbindungstest..."
cd ~/pi5-sensors
source venv/bin/activate
python sensor_reader.py test

echo ""
echo "🎯 SENSORS ONLY INSTALLATION ABGESCHLOSSEN!"
echo "=========================================="
echo ""
echo "✅ INSTALLIERT:"
echo "   🌡️  Pi5 Sensor Reader (8x DS18B20 + 1x DHT22)"
echo "   🐍 Python Virtual Environment"
echo "   ⚙️  Systemd Service (pi5-sensors-standalone)"
echo ""
echo "❌ NICHT INSTALLIERT:"
echo "   🐳 Docker (verwendet existierende Installation)"
echo "   📊 Grafana (verwendet existierende Installation)"
echo "   🗄️  InfluxDB (verwendet existierende Installation)"
echo ""
echo "📊 DATEN WERDEN GESCHRIEBEN ZU:"
echo "   🗄️  InfluxDB: $INFLUX_URL"
echo "   📦 Bucket: $INFLUX_BUCKET"
echo "   🏷️  Tag: source=pi5-sensors-standalone"
echo ""
echo "🔧 Service Commands:"
echo "   sudo systemctl status pi5-sensors-standalone"
echo "   sudo journalctl -u pi5-sensors-standalone -f"
echo ""
echo "🔄 Neustart empfohlen für GPIO-Aktivierung:"
echo "   sudo reboot"
