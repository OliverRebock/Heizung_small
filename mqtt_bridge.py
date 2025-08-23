#!/usr/bin/env python3
"""
Pi5 Heizungs Messer → Home Assistant MQTT Bridge
=================================================

Liest Temperaturen aus InfluxDB und sendet sie via MQTT an Home Assistant.
Auto-Discovery für Home Assistant Sensoren inklusive.

Autor: Pi5 Heizungs Messer Project
"""

import json
import time
import logging
from datetime import datetime
from typing import Dict, List, Optional
import configparser

try:
    from influxdb_client import InfluxDBClient
    INFLUXDB_AVAILABLE = True
except ImportError:
    INFLUXDB_AVAILABLE = False
    print("❌ InfluxDB Client nicht verfügbar - installiere: pip install influxdb-client")

try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False
    print("❌ MQTT Client nicht verfügbar - installiere: pip install paho-mqtt")

# =============================================================================
# LOGGING SETUP
# =============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/home/pi/pi5-sensors/mqtt_bridge.log')
    ]
)
logger = logging.getLogger(__name__)

class Pi5MqttBridge:
    """MQTT Bridge für Pi5 Heizungs Messer → Home Assistant"""
    
    def __init__(self, config_file='config.ini'):
        """Initialisiere MQTT Bridge"""
        self.config = configparser.ConfigParser()
        self.config.read(config_file)
        
        # MQTT Konfiguration
        self.mqtt_broker = self.config.get('mqtt', 'broker', fallback='localhost')
        self.mqtt_port = self.config.getint('mqtt', 'port', fallback=1883)
        self.mqtt_username = self.config.get('mqtt', 'username', fallback='')
        self.mqtt_password = self.config.get('mqtt', 'password', fallback='')
        self.mqtt_prefix = self.config.get('mqtt', 'topic_prefix', fallback='pi5_heizung')
        
        # InfluxDB Konfiguration
        self.influx_url = f"http://{self.config.get('database', 'host', fallback='localhost')}:8086"
        self.influx_token = self.config.get('database', 'token', fallback='pi5-token-2024')
        self.influx_org = self.config.get('database', 'org', fallback='pi5org')
        self.influx_bucket = self.config.get('database', 'bucket', fallback='sensors')
        
        # Sensor Labels
        self.sensor_labels = {}
        if self.config.has_section('labels'):
            self.sensor_labels = dict(self.config.items('labels'))
        
        # MQTT Client
        self.mqtt_client = None
        self.influx_client = None
        
        # Home Assistant Device Info
        self.device_info = {
            "identifiers": ["pi5_heizungs_messer"],
            "name": "Pi5 Heizungs Messer",
            "model": "Raspberry Pi 5",
            "manufacturer": "Pi5 Heizung Project",
            "sw_version": "1.0.0"
        }
        
        logger.info("🌡️ Pi5 MQTT Bridge initialisiert")
        logger.info(f"   📡 MQTT Broker: {self.mqtt_broker}:{self.mqtt_port}")
        logger.info(f"   🗄️ InfluxDB: {self.influx_url}")
        logger.info(f"   🏷️ Sensoren: {len(self.sensor_labels)}")

    def setup_mqtt(self):
        """MQTT Client setup"""
        if not MQTT_AVAILABLE:
            logger.error("❌ MQTT Client nicht verfügbar!")
            return False
            
        try:
            self.mqtt_client = mqtt.Client()
            
            # Callback functions
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
            self.mqtt_client.on_publish = self.on_mqtt_publish
            
            # Authentication falls konfiguriert
            if self.mqtt_username and self.mqtt_password:
                self.mqtt_client.username_pw_set(self.mqtt_username, self.mqtt_password)
                logger.info("🔐 MQTT Authentifizierung aktiviert")
            
            # Verbinden
            logger.info(f"🔌 Verbinde zu MQTT Broker {self.mqtt_broker}:{self.mqtt_port}")
            self.mqtt_client.connect(self.mqtt_broker, self.mqtt_port, 60)
            self.mqtt_client.loop_start()
            
            return True
            
        except Exception as e:
            logger.error(f"❌ MQTT Setup fehlgeschlagen: {e}")
            return False

    def setup_influxdb(self):
        """InfluxDB Client setup"""
        if not INFLUXDB_AVAILABLE:
            logger.error("❌ InfluxDB Client nicht verfügbar!")
            return False
            
        try:
            self.influx_client = InfluxDBClient(
                url=self.influx_url,
                token=self.influx_token,
                org=self.influx_org
            )
            
            # Health Check
            health = self.influx_client.health()
            if health.status == "pass":
                logger.info("✅ InfluxDB Verbindung erfolgreich")
                return True
            else:
                logger.error(f"❌ InfluxDB Health Check fehlgeschlagen: {health.status}")
                return False
                
        except Exception as e:
            logger.error(f"❌ InfluxDB Setup fehlgeschlagen: {e}")
            return False

    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT Connect Callback"""
        if rc == 0:
            logger.info("✅ MQTT Broker verbunden")
            # Home Assistant Auto-Discovery senden
            self.publish_discovery()
        else:
            logger.error(f"❌ MQTT Verbindung fehlgeschlagen: {rc}")

    def on_mqtt_disconnect(self, client, userdata, rc):
        """MQTT Disconnect Callback"""
        logger.warning(f"⚠️ MQTT Verbindung getrennt: {rc}")

    def on_mqtt_publish(self, client, userdata, mid):
        """MQTT Publish Callback"""
        logger.debug(f"📤 MQTT Nachricht gesendet: {mid}")

    def publish_discovery(self):
        """Home Assistant Auto-Discovery konfigurieren"""
        logger.info("🏠 Sende Home Assistant Auto-Discovery...")
        
        for sensor_id, sensor_name in self.sensor_labels.items():
            if sensor_id == 'dht22':
                # DHT22 Temperatur
                self.publish_sensor_discovery(
                    sensor_id="dht22_temperature",
                    sensor_name=f"{sensor_name} Temperatur",
                    device_class="temperature",
                    unit_of_measurement="°C",
                    value_template="{{ value_json.temperature }}"
                )
                
                # DHT22 Luftfeuchtigkeit
                self.publish_sensor_discovery(
                    sensor_id="dht22_humidity", 
                    sensor_name=f"{sensor_name} Luftfeuchtigkeit",
                    device_class="humidity",
                    unit_of_measurement="%",
                    value_template="{{ value_json.humidity }}"
                )
            else:
                # DS18B20 Temperatursensoren
                self.publish_sensor_discovery(
                    sensor_id=sensor_id,
                    sensor_name=sensor_name,
                    device_class="temperature",
                    unit_of_measurement="°C",
                    value_template="{{ value_json.temperature }}"
                )

    def publish_sensor_discovery(self, sensor_id: str, sensor_name: str, 
                                device_class: str, unit_of_measurement: str,
                                value_template: str):
        """Einzelnen Sensor für Home Assistant Discovery konfigurieren"""
        
        discovery_topic = f"homeassistant/sensor/{self.mqtt_prefix}_{sensor_id}/config"
        state_topic = f"{self.mqtt_prefix}/{sensor_id}/state"
        
        discovery_payload = {
            "name": sensor_name,
            "unique_id": f"{self.mqtt_prefix}_{sensor_id}",
            "state_topic": state_topic,
            "device_class": device_class,
            "unit_of_measurement": unit_of_measurement,
            "value_template": value_template,
            "device": self.device_info,
            "availability": [
                {
                    "topic": f"{self.mqtt_prefix}/status",
                    "payload_available": "online",
                    "payload_not_available": "offline"
                }
            ]
        }
        
        self.mqtt_client.publish(
            discovery_topic,
            json.dumps(discovery_payload),
            retain=True
        )
        
        logger.debug(f"📡 Discovery: {sensor_name} → {discovery_topic}")

    def get_latest_sensor_data(self) -> Dict[str, float]:
        """Aktuelle Sensor-Daten aus InfluxDB lesen"""
        try:
            query_api = self.influx_client.query_api()
            
            # Query für alle Temperatursensoren
            temp_query = f'''
            from(bucket: "{self.influx_bucket}")
              |> range(start: -5m)
              |> filter(fn: (r) => r["_measurement"] == "temperature")
              |> group(columns: ["name"])
              |> last()
            '''
            
            # Query für Luftfeuchtigkeit
            humidity_query = f'''
            from(bucket: "{self.influx_bucket}")
              |> range(start: -5m)
              |> filter(fn: (r) => r["_measurement"] == "humidity")
              |> group(columns: ["name"])
              |> last()
            '''
            
            sensor_data = {}
            
            # Temperaturen lesen
            temp_result = query_api.query(temp_query)
            for table in temp_result:
                for record in table.records:
                    sensor_name = record.values["name"]
                    temperature = record.values["_value"]
                    
                    # Sensor-ID aus Label-Mapping finden
                    sensor_id = None
                    for id, name in self.sensor_labels.items():
                        if name == sensor_name:
                            sensor_id = id
                            break
                    
                    if sensor_id:
                        sensor_data[sensor_id] = {"temperature": temperature}
            
            # Luftfeuchtigkeit lesen  
            humidity_result = query_api.query(humidity_query)
            for table in humidity_result:
                for record in table.records:
                    sensor_name = record.values["name"]
                    humidity = record.values["_value"]
                    
                    # DHT22 Sensor
                    if sensor_name == self.sensor_labels.get('dht22', ''):
                        if 'dht22' in sensor_data:
                            sensor_data['dht22']['humidity'] = humidity
                        else:
                            sensor_data['dht22'] = {"humidity": humidity}
            
            logger.info(f"📊 {len(sensor_data)} Sensoren gelesen")
            return sensor_data
            
        except Exception as e:
            logger.error(f"❌ Fehler beim Lesen der Sensor-Daten: {e}")
            return {}

    def publish_sensor_data(self, sensor_data: Dict):
        """Sensor-Daten via MQTT senden"""
        
        # Status als "online" senden
        self.mqtt_client.publish(f"{self.mqtt_prefix}/status", "online", retain=True)
        
        for sensor_id, data in sensor_data.items():
            if sensor_id == 'dht22':
                # DHT22 - separate Topics für Temperatur und Luftfeuchtigkeit
                if 'temperature' in data:
                    topic = f"{self.mqtt_prefix}/dht22_temperature/state"
                    payload = {"temperature": data['temperature']}
                    self.mqtt_client.publish(topic, json.dumps(payload))
                    
                if 'humidity' in data:
                    topic = f"{self.mqtt_prefix}/dht22_humidity/state"
                    payload = {"humidity": data['humidity']}
                    self.mqtt_client.publish(topic, json.dumps(payload))
            else:
                # DS18B20 Temperatursensoren
                if 'temperature' in data:
                    topic = f"{self.mqtt_prefix}/{sensor_id}/state"
                    payload = {"temperature": data['temperature']}
                    self.mqtt_client.publish(topic, json.dumps(payload))
        
        logger.info(f"📤 {len(sensor_data)} Sensor-Updates via MQTT gesendet")

    def run_once(self):
        """Einmalige Datenübertragung"""
        sensor_data = self.get_latest_sensor_data()
        if sensor_data:
            self.publish_sensor_data(sensor_data)
        else:
            logger.warning("⚠️ Keine Sensor-Daten verfügbar")

    def run_continuous(self, interval: int = 30):
        """Kontinuierliche Datenübertragung"""
        logger.info(f"🔄 Starte kontinuierliche MQTT Übertragung (alle {interval}s)")
        
        try:
            while True:
                self.run_once()
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logger.info("👋 MQTT Bridge beendet durch Benutzer")
        except Exception as e:
            logger.error(f"❌ Fehler in kontinuierlicher Schleife: {e}")
        finally:
            # Cleanup
            if self.mqtt_client:
                self.mqtt_client.publish(f"{self.mqtt_prefix}/status", "offline", retain=True)
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            if self.influx_client:
                self.influx_client.close()

def main():
    """Hauptfunktion"""
    import sys
    
    if not INFLUXDB_AVAILABLE or not MQTT_AVAILABLE:
        print("❌ Erforderliche Dependencies fehlen!")
        print("   pip install influxdb-client paho-mqtt")
        sys.exit(1)
    
    # Bridge initialisieren
    bridge = Pi5MqttBridge()
    
    # Verbindungen setup
    if not bridge.setup_mqtt():
        print("❌ MQTT Setup fehlgeschlagen!")
        sys.exit(1)
        
    if not bridge.setup_influxdb():
        print("❌ InfluxDB Setup fehlgeschlagen!")
        sys.exit(1)
    
    # Warten bis MQTT verbunden
    time.sleep(2)
    
    # Ausführungsmodus
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        print("🧪 Test-Modus: Einmalige Datenübertragung")
        bridge.run_once()
    else:
        print("🔄 Kontinuierlicher Modus")
        bridge.run_continuous()

if __name__ == "__main__":
    main()
