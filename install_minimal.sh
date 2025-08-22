#!/bin/bash
# =============================================================================
# MINIMAL INSTALLATION - Pi 5 Sensor Monitor
# =============================================================================
# 🎯 Fokus: Docker + InfluxDB + Individualisierte Sensoren + Grafana (no login)
# 
# Was wird installiert:
# - Docker + Docker Compose
# - InfluxDB Container 
# - Grafana Container (ohne Login)
# - Python Sensor Script mit individualisierten Namen
# - Autostart Service
# =============================================================================

echo "🚀 Pi 5 Sensor Monitor - MINIMAL INSTALLATION"
echo "=============================================="
echo ""
echo "🎯 Installiert wird:"
echo "   🐳 Docker + InfluxDB + Grafana"
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
# 2. DOCKER INSTALLIEREN
# =============================================================================
echo "🐳 Installiere Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

# =============================================================================
# 3. PROJEKTVERZEICHNIS ERSTELLEN
# =============================================================================
PROJECT_DIR="$HOME/sensor-monitor"
echo "📁 Erstelle Projektverzeichnis: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# =============================================================================
# 4. SENSOR KONFIGURATION KOPIEREN
# =============================================================================
echo "📋 Erstelle Sensor-Konfiguration..."

# config.ini mit individualisierten Namen
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

# =============================================================================
# 5. HAUPTSENSOR SCRIPT ERSTELLEN
# =============================================================================
echo "🐍 Erstelle Sensor-Script..."

cat > sensor_monitor.py << 'EOF'
#!/usr/bin/env python3
"""
🌡️ Pi 5 Sensor Monitor - MINIMAL VERSION
Fokus: InfluxDB + Individualisierte Sensoren
"""

import os
import sys
import time
import glob
import lgpio
import configparser
from datetime import datetime
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

class MinimalSensorMonitor:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('config.ini')
        self.setup_influxdb()
        self.sensor_labels = dict(self.config.items('labels'))
        
    def setup_influxdb(self):
        """InfluxDB Verbindung"""
        self.influx_client = InfluxDBClient(
            url=f"http://{self.config['database']['host']}:{self.config['database']['port']}",
            token=self.config['database']['token'],
            org=self.config['database']['org']
        )
        self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)
        
    def get_ds18b20_sensors(self):
        """DS18B20 Sensoren finden"""
        devices = glob.glob('/sys/bus/w1/devices/28-*')
        sensors = {}
        
        for i, device in enumerate(devices[:8], 1):
            sensor_id = f"ds18b20_{i}"
            label = self.sensor_labels.get(sensor_id, f"DS18B20_{i}")
            sensors[device] = {"id": sensor_id, "label": label}
            
        return sensors
        
    def read_ds18b20(self, device_path):
        """DS18B20 Temperatur lesen"""
        try:
            with open(f"{device_path}/w1_slave", 'r') as f:
                data = f.read()
            if 'YES' in data:
                temp_pos = data.find('t=') + 2
                temp_c = float(data[temp_pos:]) / 1000.0
                return round(temp_c, 2)
        except:
            return None
            
    def read_dht22(self):
        """DHT22 lesen"""
        try:
            import adafruit_dht
            dht = adafruit_dht.DHT22(int(self.config['sensors']['dht22_gpio']))
            temp = dht.temperature
            humidity = dht.humidity
            return round(temp, 2) if temp else None, round(humidity, 2) if humidity else None
        except:
            return None, None
            
    def read_all_sensors(self):
        """Alle Sensoren auslesen"""
        measurements = []
        timestamp = datetime.utcnow()
        
        # DS18B20 Sensoren
        ds18b20_sensors = self.get_ds18b20_sensors()
        for device_path, sensor_info in ds18b20_sensors.items():
            temp = self.read_ds18b20(device_path)
            if temp is not None:
                point = Point("temperature") \
                    .tag("sensor", sensor_info["id"]) \
                    .tag("label", sensor_info["label"]) \
                    .tag("type", "DS18B20") \
                    .field("value", temp) \
                    .time(timestamp)
                measurements.append(point)
                print(f"📏 {sensor_info['label']}: {temp}°C")
                
        # DHT22 Sensor
        temp, humidity = self.read_dht22()
        dht_label = self.sensor_labels.get('dht22', 'DHT22')
        
        if temp is not None:
            point = Point("temperature") \
                .tag("sensor", "dht22") \
                .tag("label", dht_label) \
                .tag("type", "DHT22") \
                .field("value", temp) \
                .time(timestamp)
            measurements.append(point)
            print(f"📏 {dht_label} Temp: {temp}°C")
            
        if humidity is not None:
            point = Point("humidity") \
                .tag("sensor", "dht22") \
                .tag("label", dht_label) \
                .tag("type", "DHT22") \
                .field("value", humidity) \
                .time(timestamp)
            measurements.append(point)
            print(f"📏 {dht_label} Humidity: {humidity}%")
            
        return measurements
        
    def write_to_influxdb(self, measurements):
        """Daten zu InfluxDB schreiben"""
        try:
            self.write_api.write(
                bucket=self.config['database']['bucket'],
                org=self.config['database']['org'],
                record=measurements
            )
            print(f"✅ {len(measurements)} Messungen gespeichert")
        except Exception as e:
            print(f"❌ InfluxDB Fehler: {e}")
            
    def monitor_continuous(self, interval=30):
        """Kontinuierliches Monitoring"""
        print(f"🔄 Starte kontinuierliches Monitoring (alle {interval}s)")
        print("📊 Individualisierte Sensornamen aktiv!")
        print("-" * 50)
        
        while True:
            try:
                measurements = self.read_all_sensors()
                if measurements:
                    self.write_to_influxdb(measurements)
                print("-" * 50)
                time.sleep(interval)
            except KeyboardInterrupt:
                print("\n🛑 Monitoring gestoppt")
                break
            except Exception as e:
                print(f"❌ Fehler: {e}")
                time.sleep(5)

if __name__ == "__main__":
    monitor = MinimalSensorMonitor()
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        print("🧪 Teste Sensoren...")
        measurements = monitor.read_all_sensors()
        print(f"✅ {len(measurements)} Sensoren gefunden")
    else:
        monitor.monitor_continuous()
EOF

# =============================================================================
# 6. DOCKER COMPOSE ERSTELLEN (MINIMAL)
# =============================================================================
echo "🐳 Erstelle Docker Compose..."

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

  grafana:
    image: grafana/grafana:10.2.0
    container_name: pi5-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=pi5sensors2024
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_SECURITY_ALLOW_EMBEDDING=true
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  grafana-data:
EOF

# =============================================================================
# 7. PYTHON VIRTUAL ENVIRONMENT ERSTELLEN (WICHTIG FÜR DHT22!)
# =============================================================================
echo "🐍 Erstelle Python Virtual Environment (für DHT22 Sensor)..."
sudo apt install -y python3-pip python3-venv python3-dev

# Virtual Environment erstellen
python3 -m venv venv
source venv/bin/activate

# Dependencies in venv installieren
echo "📦 Installiere Dependencies in venv..."
pip install --upgrade pip
pip install influxdb-client lgpio adafruit-circuitpython-dht configparser

echo "✅ Python Virtual Environment mit Dependencies erstellt"

# =============================================================================
# 8. SYSTEMD SERVICE ERSTELLEN (MIT VENV!)
# =============================================================================
echo "⚙️ Erstelle Systemd Service (mit Python venv)..."

sudo tee /etc/systemd/system/pi5-sensor-minimal.service > /dev/null << EOF
[Unit]
Description=Pi 5 Sensor Monitor (Minimal with venv)
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
# 9. DOCKER CONTAINER STARTEN
# =============================================================================
echo "🚀 Starte Docker Container..."
docker compose up -d

# Warten bis Container bereit sind
echo "⏳ Warte auf Container..."
sleep 30

# =============================================================================
# 10. TEST AUSFÜHREN (MIT VENV)
# =============================================================================
echo "🧪 Teste Installation (mit venv)..."

# Test mit venv Python ausführen
echo "🔬 Teste Sensor Script mit venv..."
source venv/bin/activate
python sensor_monitor.py test

# =============================================================================
# 11. FERTIG!
# =============================================================================
echo ""
echo "🎉 INSTALLATION ABGESCHLOSSEN!"
echo "=============================="
echo ""
echo "✅ Was wurde installiert:"
echo "   🐳 Docker + InfluxDB + Grafana"
echo "   🏷️  Individualisierte Sensornamen"
echo "   🔓 Grafana OHNE Login"
echo "   ⚙️  Systemd Service"
echo ""
echo "🌐 Verfügbare Services:"
echo "   📊 Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "   🗄️  InfluxDB: http://$(hostname -I | awk '{print $1}'):8086"
echo ""
echo "🔧 Wichtige Befehle:"
echo "   Service starten: sudo systemctl start pi5-sensor-minimal"
echo "   Service stoppen: sudo systemctl stop pi5-sensor-minimal"
echo "   Logs anzeigen:   sudo journalctl -u pi5-sensor-minimal -f"
echo "   Sensoren testen: cd $PROJECT_DIR && python3 sensor_monitor.py test"
echo ""
echo "⚠️  NEUSTART ERFORDERLICH für GPIO!"
read -p "🔄 Jetzt neu starten? (ja/nein): " reboot_now
if [ "$reboot_now" = "ja" ]; then
    sudo reboot
fi

echo "🚀 Projekt bereit! Nach Neustart startet alles automatisch."
EOF
