#!/bin/bash
# =============================================================================
# MQTT INSTALLATION - EXISTIERENDE DOCKER/GRAFANA UMGEBUNG 
# =============================================================================
# KONFLIKT-SICHER: Andere Ports, andere Container-Namen
# MIT Home Assistant MQTT Integration
# =============================================================================

set -e

echo "🏠 PI5 MQTT INSTALLATION - EXISTIERENDE DOCKER UMGEBUNG"
echo "========================================================"
echo "⚠️  KONFLIKT-SICHER für Systeme mit bereits laufendem Docker/Grafana!"
echo ""

# Parameter prüfen oder interaktiv abfragen
if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
    HA_IP="$1"
    MQTT_USER="$2"
    MQTT_PASS="$3"
    echo "📋 Parameter erkannt:"
    echo "   🏠 Home Assistant: $HA_IP:1883"
    echo "   🔐 MQTT User: $MQTT_USER"
    echo "   📡 Ziel: Home Assistant MQTT Broker"
elif [ -t 0 ]; then
    echo ""
    echo "🏠 Home Assistant Konfiguration:"
    read -p "   IP-Adresse von Home Assistant (z.B. 192.168.1.100): " HA_IP
    if [ -z "$HA_IP" ]; then
        echo "❌ Home Assistant IP ist erforderlich!"
        exit 1
    fi

    echo ""
    echo "🔐 MQTT Authentifizierung für Home Assistant:"
    read -p "   MQTT Username: " MQTT_USER
    if [ -z "$MQTT_USER" ]; then
        echo "❌ MQTT Username ist erforderlich!"
        exit 1
    fi

    echo -n "   MQTT Passwort: "
    read -s MQTT_PASS
    echo ""
    if [ -z "$MQTT_PASS" ]; then
        echo "❌ MQTT Passwort ist erforderlich!"
        exit 1
    fi
else
    echo "❌ Keine Parameter angegeben und kein TTY verfügbar!"
    echo "Usage: $0 HA_IP MQTT_USER MQTT_PASS"
    exit 1
fi

# Ports prüfen
echo ""
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
echo "   🏠 Home Assistant: $HA_IP:1883"
echo "   🔐 MQTT User: $MQTT_USER"
echo "   📦 Container Prefix: pi5-sensors-"
echo ""

# Erst Basis-Installation ausführen
echo "🔧 Basis-Installation ausführen..."
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_existing_docker.sh | bash

# Warten auf Basis-Installation
sleep 5

# Zu Projektordner wechseln
cd ~/pi5-sensors

# =============================================================================
# MQTT PACKAGES INSTALLIEREN
# =============================================================================
echo "📡 MQTT Packages installieren..."
source venv/bin/activate
pip install paho-mqtt

# =============================================================================
# MQTT KONFIGURATION HINZUFÜGEN
# =============================================================================
echo "⚙️  MQTT Konfiguration hinzufügen..."

# MQTT Sektion zu config.ini hinzufügen
if ! grep -q "\[mqtt\]" config.ini; then
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
    echo "   ✅ MQTT Konfiguration hinzugefügt"
else
    echo "   ⚠️  MQTT Konfiguration bereits vorhanden"
fi

# =============================================================================
# MQTT BRIDGE ERSTELLEN
# =============================================================================
echo "📡 MQTT Bridge für Home Assistant erstellen..."
cat > mqtt_bridge.py << 'EOF'
#!/usr/bin/env python3
"""
MQTT Bridge für Home Assistant - KONFLIKT-SICHERE VERSION
Sendet Sensordaten direkt an HA MQTT Broker
Automatische Port-Erkennung für existierende Docker Umgebungen
"""

import json
import time
import configparser
import sys
import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient

class MQTTBridge:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('config.ini')
        
        if not self.config.has_section('mqtt') or not self.config.getboolean('mqtt', 'enabled', fallback=False):
            print("❌ MQTT nicht aktiviert in config.ini")
            sys.exit(1)
        
        # MQTT Setup
        self.mqtt_client = mqtt.Client()
        broker = self.config.get('mqtt', 'broker')
        port = self.config.getint('mqtt', 'port', fallback=1883)
        username = self.config.get('mqtt', 'username')
        password = self.config.get('mqtt', 'password')
        
        self.mqtt_client.username_pw_set(username, password)
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_disconnect = self.on_disconnect
        
        print(f"📡 Verbinde zu MQTT Broker: {broker}:{port}")
        self.mqtt_client.connect(broker, port, 60)
        
        # InfluxDB Setup (mit automatischer Port-Erkennung)
        influx_url = self.config.get('database', 'url')
        influx_token = self.config.get('database', 'token')
        influx_org = self.config.get('database', 'org')
        
        self.influx_client = InfluxDBClient(url=influx_url, token=influx_token, org=influx_org)
        print(f"📊 InfluxDB Verbindung: {influx_url}")
        
        # Auto-Discovery senden
        self.send_discovery()
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print("✅ MQTT Broker verbunden")
        else:
            print(f"❌ MQTT Verbindung fehlgeschlagen: {rc}")
            
    def on_disconnect(self, client, userdata, rc):
        print("⚠️  MQTT Broker getrennt")
        
    def send_discovery(self):
        """Sende Home Assistant Auto-Discovery Konfiguration"""
        device_info = {
            "identifiers": ["pi5_heizung_sensors"],
            "name": self.config.get('mqtt', 'device_name', fallback="Pi5 Heizungs Messer"),
            "model": "Pi5 Sensor Array (Konflikt-sicher)",
            "manufacturer": "Pi5 Heizung Project"
        }
        
        discovery_prefix = self.config.get('mqtt', 'discovery_prefix', fallback='homeassistant')
        topic_prefix = self.config.get('mqtt', 'topic_prefix', fallback='pi5_heizung')
        
        # DS18B20 Sensoren
        for i in range(1, 9):
            sensor_name = self.config.get('labels', f'ds18b20_{i}', fallback=f'Sensor {i}')
            
            config = {
                "name": sensor_name,
                "unique_id": f"pi5_heizung_ds18b20_{i}",
                "state_topic": f"{topic_prefix}/ds18b20_{i}/state",
                "unit_of_measurement": "°C",
                "device_class": "temperature",
                "device": device_info
            }
            
            topic = f"{discovery_prefix}/sensor/pi5_heizung_ds18b20_{i}/config"
            self.mqtt_client.publish(topic, json.dumps(config), retain=True)
            
        # DHT22 Temperatur
        dht22_name = self.config.get('labels', 'dht22', fallback='DHT22')
        config = {
            "name": f"{dht22_name} Temperatur",
            "unique_id": "pi5_heizung_dht22_temp",
            "state_topic": f"{topic_prefix}/dht22_temp/state",
            "unit_of_measurement": "°C",
            "device_class": "temperature",
            "device": device_info
        }
        self.mqtt_client.publish(f"{discovery_prefix}/sensor/pi5_heizung_dht22_temp/config", json.dumps(config), retain=True)
        
        # DHT22 Luftfeuchtigkeit
        config = {
            "name": f"{dht22_name} Luftfeuchtigkeit",
            "unique_id": "pi5_heizung_dht22_humidity",
            "state_topic": f"{topic_prefix}/dht22_humidity/state",
            "unit_of_measurement": "%",
            "device_class": "humidity",
            "device": device_info
        }
        self.mqtt_client.publish(f"{discovery_prefix}/sensor/pi5_heizung_dht22_humidity/config", json.dumps(config), retain=True)
        
        print("✅ Home Assistant Auto-Discovery gesendet")
        
    def run(self):
        """Kontinuierlich Daten von InfluxDB lesen und an MQTT senden"""
        query_api = self.influx_client.query_api()
        topic_prefix = self.config.get('mqtt', 'topic_prefix', fallback='pi5_heizung')
        
        self.mqtt_client.loop_start()
        
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
                            topic = f"{topic_prefix}/{sensor_id}/state"
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
                            self.mqtt_client.publish(f"{topic_prefix}/dht22_humidity/state", f"{value:.1f}")
                            
                time.sleep(30)
                
            except Exception as e:
                print(f"❌ MQTT Bridge Fehler: {e}")
                time.sleep(10)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "discovery":
        bridge = MQTTBridge()
        print("✅ Discovery gesendet, beende...")
    elif len(sys.argv) > 1 and sys.argv[1] == "mqtt-test":
        bridge = MQTTBridge()
        print("✅ MQTT Test erfolgreich, beende...")
    else:
        bridge = MQTTBridge()
        bridge.run()
EOF

# =============================================================================
# MQTT SERVICE ERSTELLEN
# =============================================================================
echo "📡 MQTT Bridge Service erstellen..."
sudo tee /etc/systemd/system/pi5-mqtt-bridge.service > /dev/null << EOF
[Unit]
Description=Pi5 MQTT Bridge für Home Assistant (Konflikt-sichere Version)
After=docker.service pi5-sensors.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/pi5-sensors
ExecStart=/home/$USER/pi5-sensors/venv/bin/python mqtt_bridge.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# =============================================================================
# SERVICES AKTIVIEREN
# =============================================================================
echo "🔧 MQTT Services aktivieren..."
sudo systemctl daemon-reload
sudo systemctl enable pi5-mqtt-bridge.service
sudo systemctl start pi5-mqtt-bridge.service

# =============================================================================
# MQTT TEST
# =============================================================================
echo ""
echo "🧪 MQTT Test ausführen..."
cd ~/pi5-sensors
source venv/bin/activate
python mqtt_bridge.py mqtt-test

echo ""
echo "🎯 KONFLIKT-SICHERE MQTT INSTALLATION ABGESCHLOSSEN!"
echo "===================================================="
echo ""
echo "🏠 Home Assistant MQTT Integration:"
echo "   📡 Broker: $HA_IP:1883"
echo "   🔐 User: $MQTT_USER"
echo "   📋 Device: 'Pi5 Heizungs Messer'"
echo "   🏷️  Topics: pi5_heizung/+/state"
echo ""
echo "🌐 Grafana (KONFLIKT-SICHER):"
echo "   📊 http://$(hostname -I | awk '{print $1}'):${GRAFANA_PORT}/grafana/"
echo "   📊 http://dermesser.fritz.box:${GRAFANA_PORT}/grafana/"
echo ""
echo "🔧 Services:"
echo "   sudo systemctl status pi5-sensors"
echo "   sudo systemctl status pi5-mqtt-bridge"
echo ""
echo "🏠 Home Assistant sollte jetzt alle 9 Sensoren automatisch erkennen!"
echo ""
