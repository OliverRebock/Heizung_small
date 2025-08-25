#!/bin/bash
# =============================================================================
# INSTALL SIMPLE - EXISTIERENDE DOCKER/GRAFANA UMGEBUNG
# =============================================================================
# Für Systeme wo bereits Docker und Grafana laufen!
# KONFLIKT-SICHER: Verwendet andere Ports und Container-Namen
# =============================================================================

set -e

echo "🚨 PI5 SENSOR INSTALLATION - EXISTIERENDE DOCKER UMGEBUNG"
echo "=========================================================="
echo "⚠️  SICHER für Systeme mit bereits laufendem Docker/Grafana!"
echo "📦 9 Sensoren + InfluxDB + Grafana (KONFLIKT-SICHERE Ports)"
echo ""

# Warnung anzeigen
echo "🔍 EXISTIERENDE DOCKER SERVICES PRÜFEN:"
echo "========================================"
docker ps | grep -E "(grafana|influxdb)" || echo "✅ Keine Konflikte erkannt"
echo ""

# Ports prüfen
echo "🌐 PORT-VERFÜGBARKEIT PRÜFEN:"
echo "============================="
if netstat -tuln | grep -q ":3000 "; then
    echo "⚠️  Port 3000 bereits belegt - verwende 3001 für Grafana"
    GRAFANA_PORT="3001"
else
    echo "✅ Port 3000 verfügbar"
    GRAFANA_PORT="3000"
fi

if netstat -tuln | grep -q ":8086 "; then
    echo "⚠️  Port 8086 bereits belegt - verwende 8087 für InfluxDB"
    INFLUX_PORT="8087"
else
    echo "✅ Port 8086 verfügbar"
    INFLUX_PORT="8086"
fi

echo ""
echo "📋 VERWENDETE KONFIGURATION:"
echo "   🔌 Grafana Port: $GRAFANA_PORT"
echo "   🔌 InfluxDB Port: $INFLUX_PORT"
echo "   📦 Container Prefix: pi5-sensors-"
echo ""

# =============================================================================
# 1. SYSTEM VORBEREITEN
# =============================================================================
echo "🔧 System vorbereiten..."
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
# 2. DOCKER PRÜFEN (NICHT NEU INSTALLIEREN!)
# =============================================================================
echo "🐳 Docker Status prüfen..."
if command -v docker &> /dev/null; then
    echo "   ✅ Docker bereits installiert"
    docker --version
else
    echo "   ❌ Docker nicht gefunden - installiere Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
fi

# User zur docker group hinzufügen (falls noch nicht)
if ! groups $USER | grep -q docker; then
    sudo usermod -aG docker $USER
    echo "   ✅ User zur docker group hinzugefügt"
fi

# =============================================================================
# 3. PROJEKTORDNER ERSTELLEN (KONFLIKT-SICHER)
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
# 4. DOCKER COMPOSE (KONFLIKT-SICHERE PORTS & CONTAINER NAMEN)
# =============================================================================
echo "🐳 Docker Compose mit KONFLIKT-SICHEREN Ports erstellen..."
cat > docker-compose.yml << EOF
services:
  influxdb:
    image: influxdb:2.7
    container_name: pi5-sensors-influxdb
    restart: unless-stopped
    ports:
      - "${INFLUX_PORT}:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=pi5sensors2024
      - DOCKER_INFLUXDB_INIT_ORG=pi5org
      - DOCKER_INFLUXDB_INIT_BUCKET=sensors
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=pi5-token-2024
    volumes:
      - pi5-sensors-influxdb-data:/var/lib/influxdb2
    networks:
      - pi5-sensors-network

  grafana:
    image: grafana/grafana:latest
    container_name: pi5-sensors-grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    environment:
      # 🌐 DOMAIN-SPEZIFISCHE KONFIGURATION für dermesser.fritz.box
      - GF_SERVER_DOMAIN=dermesser.fritz.box
      - GF_SERVER_ROOT_URL=http://dermesser.fritz.box:${GRAFANA_PORT}/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      
      # 🚨 NUCLEAR WELCOME SCREEN ELIMINATION
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_ANONYMOUS_ORG_NAME=Pi5SensorOrg
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_SECURITY_ALLOW_EMBEDDING=true
      - GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION=true
      - GF_SECURITY_ADMIN_USER=
      - GF_SECURITY_ADMIN_PASSWORD=
      
      # 🔧 ORGANIZATION FIX
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_USERS_ALLOW_ORG_CREATE=false
      - GF_USERS_AUTO_ASSIGN_ORG=true
      - GF_USERS_AUTO_ASSIGN_ORG_ROLE=Admin
      
      # 📊 ANALYTICS & FEATURES DISABLE
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_SNAPSHOTS_EXTERNAL_ENABLED=false
      - GF_FEATURE_TOGGLES_ENABLE=
      - GF_UNIFIED_ALERTING_ENABLED=false
      - GF_INSTALL_CHECK_FOR_UPDATES=false
      - GF_DATABASE_TYPE=sqlite3
    volumes:
      - pi5-sensors-grafana-data:/var/lib/grafana
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro
    depends_on:
      - influxdb
    networks:
      - pi5-sensors-network

volumes:
  pi5-sensors-influxdb-data:
  pi5-sensors-grafana-data:

networks:
  pi5-sensors-network:
    driver: bridge
EOF

# =============================================================================
# 5. GRAFANA KONFIGURATION (KONFLIKT-SICHER)
# =============================================================================
echo "🚨 KONFLIKT-SICHERE Grafana Konfiguration..."
mkdir -p grafana
cat > grafana/grafana.ini << EOF
# GRAFANA CONFIGURATION - KONFLIKT-SICHER für existierende Docker Umgebung
# Port: ${GRAFANA_PORT} (konflikatfrei)

[server]
http_port = 3000
domain = dermesser.fritz.box
root_url = http://dermesser.fritz.box:${GRAFANA_PORT}/grafana/
serve_from_sub_path = true
enable_gzip = true

[auth]
disable_login_form = true
disable_signout_menu = true

[auth.anonymous]
enabled = true
org_name = Pi5SensorOrg
org_role = Admin
hide_version = true

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Admin
default_theme = dark

[security]
allow_embedding = true
cookie_secure = false
cookie_samesite = lax
disable_initial_admin_creation = true
admin_user = 
admin_password = 

[plugins]
enable_alpha = false

[install]
check_for_updates = false

[database]
type = sqlite3

[analytics]
reporting_enabled = false
check_for_updates = false

[feature_toggles]
enable = 

[unified_alerting]
enabled = false
EOF

# =============================================================================
# 6. PYTHON VENV UND PACKAGES
# =============================================================================
echo "🐍 Python Virtual Environment erstellen..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Python Packages installieren (Pi 5 optimiert)..."
pip install --upgrade pip
pip install influxdb-client RPi.GPIO adafruit-blinka
pip install adafruit-circuitpython-dht --force-reinstall

# =============================================================================
# 7. KONFIGURATIONSDATEI (KONFLIKT-SICHERE PORTS)
# =============================================================================
echo "⚙️  Konfigurationsdatei erstellen..."
cat > config.ini << EOF
[sensors]
ds18b20_count = 8
dht22_gpio = 18

[database]
url = http://localhost:${INFLUX_PORT}
token = pi5-token-2024
org = pi5org
bucket = sensors

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

# =============================================================================
# 8. SENSOR READER (KONFLIKT-SICHERE URL)
# =============================================================================
echo "📊 Sensor Reader erstellen..."
cat > sensor_reader.py << 'EOF'
#!/usr/bin/env python3
"""
Pi5 Sensor Reader - KONFLIKT-SICHERE VERSION
Automatische Port-Erkennung für existierende Docker Umgebungen
"""

import time
import glob
import configparser
import sys
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

class Pi5SensorReader:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('config.ini')
        self.setup_influxdb()
        
    def setup_influxdb(self):
        """InfluxDB Verbindung mit automatischer Port-Erkennung"""
        url = self.config.get('database', 'url')
        token = self.config.get('database', 'token')
        org = self.config.get('database', 'org')
        
        self.client = InfluxDBClient(url=url, token=token, org=org)
        self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
        print(f"   📊 InfluxDB Verbindung: {url}")
        
    def read_ds18b20_sensors(self):
        """Lese alle DS18B20 Sensoren"""
        sensors = []
        devices = glob.glob('/sys/bus/w1/devices/28-*')
        
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
        """Schreibe Sensordaten zu InfluxDB"""
        points = []
        
        for sensor in sensors:
            point = Point("temperature") \
                .tag("sensor_id", sensor['sensor_id']) \
                .tag("sensor_name", sensor['name']) \
                .tag("sensor_type", "DS18B20") \
                .field("value", sensor['temperature']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(point)
            
        if dht_data:
            temp_point = Point("temperature") \
                .tag("sensor_id", dht_data['sensor_id']) \
                .tag("sensor_name", dht_data['name']) \
                .tag("sensor_type", "DHT22") \
                .field("value", dht_data['temperature']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(temp_point)
            
            humidity_point = Point("humidity") \
                .tag("sensor_id", dht_data['sensor_id']) \
                .tag("sensor_name", dht_data['name']) \
                .tag("sensor_type", "DHT22") \
                .field("value", dht_data['humidity']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(humidity_point)
            
        try:
            self.write_api.write(bucket="sensors", record=points)
            print(f"   ✅ {len(points)} Datenpunkte geschrieben")
        except Exception as e:
            print(f"   ❌ InfluxDB Fehler: {e}")
            
    def run_once(self):
        """Führe eine Sensor-Lesung durch"""
        print(f"🌡️  Sensor-Lesung {time.strftime('%H:%M:%S')}")
        
        ds18b20_sensors = self.read_ds18b20_sensors()
        dht22_data = self.read_dht22()
        self.write_to_influxdb(ds18b20_sensors, dht22_data)
        
        return len(ds18b20_sensors) + (1 if dht22_data else 0)
        
    def run_continuous(self):
        """Kontinuierliche Sensor-Überwachung"""
        print("🚀 Starte kontinuierliche Sensor-Überwachung")
        print("   Interval: 30 Sekunden")
        print("   Ctrl+C zum Beenden")
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
    reader = Pi5SensorReader()
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        reader.run_once()
    else:
        reader.run_continuous()
EOF

# =============================================================================
# 9. SYSTEMD SERVICE (KONFLIKT-SICHER)
# =============================================================================
echo "⚙️  Systemd Service erstellen..."
sudo tee /etc/systemd/system/pi5-sensors.service > /dev/null << EOF
[Unit]
Description=Pi5 Sensor Reader (Konflikt-sichere Version)
After=docker.service
Requires=docker.service

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
# 10. DOCKER STARTEN (KONFLIKT-SICHER)
# =============================================================================
echo "🐳 Docker Container starten (KONFLIKT-SICHERE Ports)..."
docker compose up -d

echo "⏳ Warte auf Container..."
sleep 15

# =============================================================================
# 11. SERVICES AKTIVIEREN
# =============================================================================
echo "🔧 Services aktivieren..."
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensors.service
sudo systemctl start pi5-sensors.service

# =============================================================================
# 12. KONFLIKT-CHECK & INFORMATION
# =============================================================================
echo ""
echo "🎯 KONFLIKT-SICHERE INSTALLATION ABGESCHLOSSEN!"
echo "==============================================="
echo ""
echo "🔍 EXISTIERENDE DOCKER SERVICES:"
docker ps | grep -E "(grafana|influxdb)" | head -10
echo ""
echo "📊 DEINE PI5 SENSOR SERVICES:"
echo "   🌐 Grafana: http://$(hostname -I | awk '{print $1}'):${GRAFANA_PORT}/grafana/"
echo "   🌐 Grafana (Domain): http://dermesser.fritz.box:${GRAFANA_PORT}/grafana/"
echo "   🗄️  InfluxDB: http://$(hostname -I | awk '{print $1}'):${INFLUX_PORT} (admin/pi5sensors2024)"
echo ""
echo "🐳 CONTAINER NAMEN (konfliktfrei):"
echo "   📦 pi5-sensors-grafana (Port ${GRAFANA_PORT})"
echo "   📦 pi5-sensors-influxdb (Port ${INFLUX_PORT})"
echo ""
echo "🔧 Services:"
echo "   sudo systemctl status pi5-sensors"
echo ""

# Sensor Test
echo "🧪 Führe Sensor-Test aus..."
cd ~/pi5-sensors
source venv/bin/activate
python sensor_reader.py test

echo ""
echo "✅ KONFLIKT-SICHERE INSTALLATION ERFOLGREICH!"
echo "🚨 Verwendet EIGENE Ports und Container-Namen!"
echo ""
echo "🔄 Neustart empfohlen für GPIO-Aktivierung:"
echo "   sudo reboot"
