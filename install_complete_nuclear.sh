#!/bin/bash
# =============================================================================
# NUCLEAR COMPLETE INSTALLATION - Pi5 mit 9 Sensoren (WELCOME SCREEN KILLER)
# =============================================================================
# Features:
# - 8x DS18B20 + 1x DHT22
# - InfluxDB + Grafana (NUCLEAR Anti-Welcome-Screen)
# - MQTT für Home Assistant (optional)
# - Alle bisherigen Bugfixes integriert
# =============================================================================

set -e  # Beende bei Fehlern

echo "🚨 NUCLEAR Pi5 Sensor Installation (WELCOME SCREEN KILLER)"
echo "=========================================================="
echo "📦 9 Sensoren + InfluxDB + Grafana (BRUTAL ANTI-WELCOME)"
echo ""

# Parameter für MQTT (optional)
INSTALL_MQTT=false
if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
    INSTALL_MQTT=true
    HA_IP="$1"
    MQTT_USER="$2"
    MQTT_PASS="$3"
    echo "🏠 MQTT für Home Assistant wird installiert:"
    echo "   📡 Home Assistant: $HA_IP:1883"
    echo "   🔐 MQTT User: $MQTT_USER"
    echo ""
fi

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
# 2. DOCKER INSTALLIEREN
# =============================================================================
echo "🐳 Docker installieren..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "   ✅ Docker installiert"
else
    echo "   ✅ Docker bereits vorhanden"
fi

# User zur docker group hinzufügen
if ! groups $USER | grep -q docker; then
    sudo usermod -aG docker $USER
    echo "   ✅ User zur docker group hinzugefügt"
fi

# =============================================================================
# 3. PROJEKTORDNER ERSTELLEN
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
# 4. DOCKER COMPOSE (NUCLEAR GRAFANA CONFIGURATION)
# =============================================================================
echo "🐳 Docker Compose mit NUCLEAR Grafana erstellen..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  influxdb:
    image: influxdb:2.7
    container_name: pi5-influxdb
    restart: unless-stopped
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=pi5sensors2024
      - DOCKER_INFLUXDB_INIT_ORG=pi5org
      - DOCKER_INFLUXDB_INIT_BUCKET=sensors
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=pi5-token-2024
    volumes:
      - influxdb-data:/var/lib/influxdb2

  grafana:
    image: grafana/grafana:latest
    container_name: pi5-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      # 🚨 NUCLEAR WELCOME SCREEN ELIMINATION
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_SECURITY_ALLOW_EMBEDDING=true
      - GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION=true
      - GF_SECURITY_ADMIN_USER=
      - GF_SECURITY_ADMIN_PASSWORD=
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_SNAPSHOTS_EXTERNAL_ENABLED=false
      - GF_FEATURE_TOGGLES_ENABLE=
      - GF_UNIFIED_ALERTING_ENABLED=false
      - GF_INSTALL_CHECK_FOR_UPDATES=false
      - GF_DATABASE_TYPE=sqlite3
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  grafana-data:
EOF

# =============================================================================
# 5. NUCLEAR GRAFANA CONFIGURATION
# =============================================================================
echo "🚨 NUCLEAR Grafana Konfiguration (BRUTAL WELCOME SCREEN KILLER)..."
mkdir -p grafana
cat > grafana/grafana.ini << 'EOL'
# NUCLEAR GRAFANA CONFIGURATION - ULTIMATE WELCOME SCREEN KILLER
# Alle möglichen Disables für komplette Welcome Screen Elimination

[server]
http_port = 3000
domain = localhost
root_url = %(protocol)s://%(domain)s/grafana/
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
app_tls_skip_verify_insecure = false

[install]
check_for_updates = false

[database]
type = sqlite3
host = 127.0.0.1:3306
name = grafana
user = root
password = 

[analytics]
reporting_enabled = false
check_for_updates = false

[snapshots]
external_enabled = false

[feature_toggles]
enable = 

[unified_alerting]
enabled = false

[alerting]
enabled = false

[explore]
enabled = true

[help]
enabled = false
EOL

# =============================================================================
# 6. PYTHON VENV UND PACKAGES
# =============================================================================
echo "🐍 Python Virtual Environment erstellen..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Python Packages installieren (Pi 5 optimiert)..."
pip install --upgrade pip

# Spezielle Pi 5 Installation für Adafruit DHT
pip install influxdb-client RPi.GPIO adafruit-blinka
pip install adafruit-circuitpython-dht --force-reinstall

# MQTT Bridge (falls gewünscht)
if [ "$INSTALL_MQTT" = true ]; then
    echo "📡 MQTT Packages installieren..."
    pip install paho-mqtt
fi

# =============================================================================
# 7. KONFIGURATIONSDATEI
# =============================================================================
echo "⚙️  Konfigurationsdatei erstellen..."
cat > config.ini << 'EOF'
[sensors]
ds18b20_count = 8
dht22_gpio = 18

[database]
url = http://localhost:8086
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

# MQTT Konfiguration hinzufügen (falls gewünscht)
if [ "$INSTALL_MQTT" = true ]; then
    echo "" >> config.ini
    echo "[mqtt]" >> config.ini
    echo "enabled = true" >> config.ini
    echo "broker = $HA_IP" >> config.ini
    echo "port = 1883" >> config.ini
    echo "username = $MQTT_USER" >> config.ini
    echo "password = $MQTT_PASS" >> config.ini
    echo "topic_prefix = pi5_heizung" >> config.ini
    echo "discovery_prefix = homeassistant" >> config.ini
    echo "device_name = Pi5 Heizungs Messer" >> config.ini
fi

# =============================================================================
# 8. SENSOR READER (NUCLEAR VERSION)
# =============================================================================
echo "📊 Sensor Reader erstellen..."
cat > sensor_reader.py << 'EOF'
#!/usr/bin/env python3
"""
Pi5 Sensor Reader - NUCLEAR VERSION
Optimiert für Raspberry Pi 5 mit 8x DS18B20 + 1x DHT22
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
        """InfluxDB Verbindung"""
        self.client = InfluxDBClient(
            url="http://localhost:8086",
            token="pi5-token-2024",
            org="pi5org"
        )
        self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
        
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
        """Schreibe Sensordaten zu InfluxDB"""
        points = []
        
        # DS18B20 Sensoren
        for sensor in sensors:
            point = Point("temperature") \
                .tag("sensor_id", sensor['sensor_id']) \
                .tag("sensor_name", sensor['name']) \
                .tag("sensor_type", "DS18B20") \
                .field("value", sensor['temperature']) \
                .time(time.time_ns(), WritePrecision.NS)
            points.append(point)
            
        # DHT22 Sensor
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
        
        # DS18B20 Sensoren lesen
        ds18b20_sensors = self.read_ds18b20_sensors()
        
        # DHT22 Sensor lesen
        dht22_data = self.read_dht22()
        
        # Zu InfluxDB schreiben
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
# 9. MQTT BRIDGE (falls gewünscht)
# =============================================================================
if [ "$INSTALL_MQTT" = true ]; then
    echo "📡 MQTT Bridge für Home Assistant erstellen..."
    cat > mqtt_bridge.py << 'EOF'
#!/usr/bin/env python3
"""
MQTT Bridge für Home Assistant - Sendet Sensordaten direkt an HA MQTT Broker
"""

import json
import time
import configparser
import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient

class MQTTBridge:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('config.ini')
        
        # MQTT Setup
        self.mqtt_client = mqtt.Client()
        broker = self.config.get('mqtt', 'broker')
        port = self.config.getint('mqtt', 'port', fallback=1883)
        username = self.config.get('mqtt', 'username')
        password = self.config.get('mqtt', 'password')
        
        self.mqtt_client.username_pw_set(username, password)
        self.mqtt_client.connect(broker, port, 60)
        
        # InfluxDB Setup
        self.influx_client = InfluxDBClient(
            url="http://localhost:8086",
            token="pi5-token-2024",
            org="pi5org"
        )
        
        self.send_discovery()
        
    def send_discovery(self):
        """Sende Home Assistant Auto-Discovery Konfiguration"""
        device_info = {
            "identifiers": ["pi5_heizung_sensors"],
            "name": "Pi5 Heizungs Messer",
            "model": "Pi5 Sensor Array",
            "manufacturer": "Pi5 Heizung Project"
        }
        
        # DS18B20 Sensoren
        for i in range(1, 9):
            sensor_name = self.config.get('labels', f'ds18b20_{i}', fallback=f'Sensor {i}')
            
            config = {
                "name": sensor_name,
                "unique_id": f"pi5_heizung_ds18b20_{i}",
                "state_topic": f"pi5_heizung/ds18b20_{i}/state",
                "unit_of_measurement": "°C",
                "device_class": "temperature",
                "device": device_info
            }
            
            topic = f"homeassistant/sensor/pi5_heizung_ds18b20_{i}/config"
            self.mqtt_client.publish(topic, json.dumps(config), retain=True)
            
        # DHT22 Temperatur
        config = {
            "name": self.config.get('labels', 'dht22', fallback='DHT22') + " Temperatur",
            "unique_id": "pi5_heizung_dht22_temp",
            "state_topic": "pi5_heizung/dht22_temp/state",
            "unit_of_measurement": "°C",
            "device_class": "temperature",
            "device": device_info
        }
        self.mqtt_client.publish("homeassistant/sensor/pi5_heizung_dht22_temp/config", json.dumps(config), retain=True)
        
        # DHT22 Luftfeuchtigkeit
        config = {
            "name": self.config.get('labels', 'dht22', fallback='DHT22') + " Luftfeuchtigkeit",
            "unique_id": "pi5_heizung_dht22_humidity",
            "state_topic": "pi5_heizung/dht22_humidity/state",
            "unit_of_measurement": "%",
            "device_class": "humidity",
            "device": device_info
        }
        self.mqtt_client.publish("homeassistant/sensor/pi5_heizung_dht22_humidity/config", json.dumps(config), retain=True)
        
        print("✅ Home Assistant Auto-Discovery gesendet")
        
    def run(self):
        """Kontinuierlich Daten von InfluxDB lesen und an MQTT senden"""
        query_api = self.influx_client.query_api()
        
        while True:
            try:
                # Neueste Temperaturdaten
                temp_query = '''
                from(bucket: "sensors")
                |> range(start: -1m)
                |> filter(fn: (r) => r._measurement == "temperature")
                |> last()
                '''
                
                temp_result = query_api.query(temp_query)
                
                for table in temp_result:
                    for record in table.records:
                        sensor_id = record.values.get("sensor_id")
                        value = record.values.get("_value")
                        
                        if sensor_id and value is not None:
                            topic = f"pi5_heizung/{sensor_id}/state"
                            self.mqtt_client.publish(topic, f"{value:.1f}")
                            
                # Luftfeuchtigkeit
                humidity_query = '''
                from(bucket: "sensors")
                |> range(start: -1m)
                |> filter(fn: (r) => r._measurement == "humidity")
                |> last()
                '''
                
                humidity_result = query_api.query(humidity_query)
                
                for table in humidity_result:
                    for record in table.records:
                        value = record.values.get("_value")
                        if value is not None:
                            self.mqtt_client.publish("pi5_heizung/dht22_humidity/state", f"{value:.1f}")
                            
                time.sleep(30)
                
            except Exception as e:
                print(f"❌ MQTT Bridge Fehler: {e}")
                time.sleep(10)

if __name__ == "__main__":
    bridge = MQTTBridge()
    bridge.run()
EOF
fi

# =============================================================================
# 10. SYSTEMD SERVICE
# =============================================================================
echo "⚙️  Systemd Service erstellen..."
sudo tee /etc/systemd/system/pi5-sensors.service > /dev/null << EOF
[Unit]
Description=Pi5 Sensor Reader
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

# MQTT Service (falls gewünscht)
if [ "$INSTALL_MQTT" = true ]; then
    echo "📡 MQTT Bridge Service erstellen..."
    sudo tee /etc/systemd/system/pi5-mqtt-bridge.service > /dev/null << EOF
[Unit]
Description=Pi5 MQTT Bridge für Home Assistant
After=docker.service pi5-sensors.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/pi5-sensors
ExecStart=/home/$USER/pi5-sensors/venv/bin/activate && /home/$USER/pi5-sensors/venv/bin/python mqtt_bridge.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
fi

# =============================================================================
# 11. DOCKER STARTEN
# =============================================================================
echo "🐳 Docker Container starten (NUCLEAR GRAFANA)..."
sudo docker compose down -v 2>/dev/null || true
sudo docker compose up -d

# Warten auf Container
echo "⏳ Warte auf Container..."
sleep 10

# =============================================================================
# 12. SERVICES AKTIVIEREN
# =============================================================================
echo "🔧 Services aktivieren..."
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensors.service
sudo systemctl start pi5-sensors.service

if [ "$INSTALL_MQTT" = true ]; then
    sudo systemctl enable pi5-mqtt-bridge.service
    sudo systemctl start pi5-mqtt-bridge.service
fi

# =============================================================================
# 13. TEST & INFORMATION
# =============================================================================
echo ""
echo "🎯 NUCLEAR INSTALLATION ABGESCHLOSSEN!"
echo "======================================"
echo ""
echo "📊 Grafana (NUCLEAR ANTI-WELCOME): http://$(hostname -I | awk '{print $1}'):3000"
echo "📊 Grafana Subpath: http://$(hostname -I | awk '{print $1}'):3000/grafana/"
echo "🗄️  InfluxDB: http://$(hostname -I | awk '{print $1}'):8086 (admin/pi5sensors2024)"
echo ""

if [ "$INSTALL_MQTT" = true ]; then
    echo "🏠 Home Assistant MQTT:"
    echo "   📡 Broker: $HA_IP:1883"
    echo "   🔐 User: $MQTT_USER"
    echo "   📋 Device: 'Pi5 Heizungs Messer'"
    echo ""
fi

echo "🔧 Services:"
echo "   sudo systemctl status pi5-sensors"
if [ "$INSTALL_MQTT" = true ]; then
    echo "   sudo systemctl status pi5-mqtt-bridge"
fi
echo ""

echo "🌡️  Test ausführen:"
echo "   cd ~/pi5-sensors && source venv/bin/activate && python sensor_reader.py test"
echo ""

# Sensor Test
echo "🧪 Führe Sensor-Test aus..."
cd ~/pi5-sensors
source venv/bin/activate
python sensor_reader.py test

echo ""
echo "✅ NUCLEAR INSTALLATION ERFOLGREICH!"
echo "🚨 Grafana sollte OHNE Welcome Screen starten!"
echo ""

if [ "$INSTALL_MQTT" = true ]; then
    echo "🏠 Home Assistant Integration sollte automatisch erkannt werden!"
fi

echo "🔄 Neustart empfohlen für GPIO-Aktivierung:"
echo "   sudo reboot"
