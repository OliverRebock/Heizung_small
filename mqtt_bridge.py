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
import os
import sys
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
        
        # Config-Datei suchen
        config_paths = [
            config_file,
            '/home/pi/pi5-sensors/config.ini',
            './mqtt_config.ini',
            './config.ini'
        ]
        
        config_found = False
        for path in config_paths:
            if os.path.exists(path):
                self.config.read(path)
                config_found = True
                logger.info(f"📋 Konfiguration geladen: {path}")
                break
        
        if not config_found:
            logger.error("❌ Keine Konfigurationsdatei gefunden!")
            logger.error("   Erwartete Pfade: " + ", ".join(config_paths))
            sys.exit(1)
        
        # MQTT Konfiguration
        self.mqtt_broker = self.config.get('mqtt', 'broker', fallback='localhost')
        self.mqtt_port = self.config.getint('mqtt', 'port', fallback=1883)
        self.mqtt_username = self.config.get('mqtt', 'username', fallback='')
        self.mqtt_password = self.config.get('mqtt', 'password', fallback='')
        self.mqtt_prefix = self.config.get('mqtt', 'topic_prefix', fallback='pi5_heizung')
        
        # Home Assistant Konfiguration
        self.ha_ip = self.config.get('homeassistant', 'ip', fallback='192.168.1.100')
        self.ha_discovery = self.config.getboolean('homeassistant', 'mqtt_discovery', fallback=True)
        
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
        logger.info(f"   🏠 Home Assistant: {self.ha_ip}")
        logger.info(f"   🗄️ InfluxDB: {self.influx_url}")
        logger.info(f"   🏷️ Sensoren: {len(self.sensor_labels)}")
        if self.mqtt_username:
            logger.info(f"   🔐 MQTT Auth: {self.mqtt_username}")
        else:
            logger.info("   🔓 MQTT Auth: Keine")

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
            # Status senden
            self.mqtt_client.publish(f"{self.mqtt_prefix}/status", "online", retain=True)
            # Home Assistant Auto-Discovery senden
            logger.info("🏠 Sende Home Assistant Auto-Discovery...")
            self.publish_discovery()
        else:
            logger.error(f"❌ MQTT Verbindung fehlgeschlagen: {rc}")
            if rc == 1:
                logger.error("   → Falsche Protokoll-Version")
            elif rc == 2:
                logger.error("   → Ungültige Client-ID")
            elif rc == 3:
                logger.error("   → Server nicht verfügbar")
            elif rc == 4:
                logger.error("   → Falsche Anmeldedaten")
            elif rc == 5:
                logger.error("   → Nicht autorisiert")

    def on_mqtt_disconnect(self, client, userdata, rc):
        """MQTT Disconnect Callback"""
        if rc != 0:
            logger.warning(f"⚠️ MQTT Verbindung getrennt: {rc}")
        else:
            logger.info("👋 MQTT Verbindung sauber getrennt")

    def on_mqtt_publish(self, client, userdata, mid):
        """MQTT Publish Callback"""
        logger.debug(f"📤 MQTT Nachricht gesendet: {mid}")

    def publish_discovery(self):
        """Home Assistant Auto-Discovery konfigurieren"""
        try:
            logger.info("🏠 Sende Home Assistant Auto-Discovery...")
            discovery_count = 0
            
            for sensor_id, sensor_name in self.sensor_labels.items():
                if sensor_id == 'dht22':
                    # DHT22 Temperatur
                    success1 = self.publish_sensor_discovery(
                        sensor_id="dht22_temperature",
                        sensor_name=f"{sensor_name} Temperatur",
                        device_class="temperature",
                        unit_of_measurement="°C",
                        value_template="{{ value_json.temperature }}",
                        icon="mdi:thermometer"
                    )
                    
                    # DHT22 Luftfeuchtigkeit
                    success2 = self.publish_sensor_discovery(
                        sensor_id="dht22_humidity", 
                        sensor_name=f"{sensor_name} Luftfeuchtigkeit",
                        device_class="humidity",
                        unit_of_measurement="%",
                        value_template="{{ value_json.humidity }}",
                        icon="mdi:water-percent"
                    )
                    
                    if success1 and success2:
                        discovery_count += 2
                else:
                    # DS18B20 Temperatursensoren
                    success = self.publish_sensor_discovery(
                        sensor_id=sensor_id,
                        sensor_name=sensor_name,
                        device_class="temperature",
                        unit_of_measurement="°C",
                        value_template="{{ value_json.temperature }}",
                        icon="mdi:thermometer"
                    )
                    
                    if success:
                        discovery_count += 1
            
            logger.info(f"✅ {discovery_count} Discovery-Nachrichten gesendet")
            
            # Kurz warten und dann erste Daten senden
            time.sleep(1)
            self.run_once()
            
        except Exception as e:
            logger.error(f"❌ Fehler bei Auto-Discovery: {e}")

    def publish_sensor_discovery(self, sensor_id: str, sensor_name: str, 
                                device_class: str, unit_of_measurement: str,
                                value_template: str, icon: str = None):
        """Einzelnen Sensor für Home Assistant Discovery konfigurieren"""
        
        try:
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
                ],
                "expire_after": 300  # Sensor als offline nach 5 Minuten ohne Update
            }
            
            if icon:
                discovery_payload["icon"] = icon
            
            # Discovery-Nachricht senden
            result = self.mqtt_client.publish(
                discovery_topic,
                json.dumps(discovery_payload),
                retain=True
            )
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"📡 Discovery OK: {sensor_name} → {discovery_topic}")
                return True
            else:
                logger.error(f"❌ Discovery FEHLER: {sensor_name} → {result.rc}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Discovery Fehler für {sensor_name}: {e}")
            return False

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
        
        published_count = 0
        
        for sensor_id, data in sensor_data.items():
            try:
                if sensor_id == 'dht22':
                    # DHT22 - separate Topics für Temperatur und Luftfeuchtigkeit
                    if 'temperature' in data:
                        topic = f"{self.mqtt_prefix}/dht22_temperature/state"
                        payload = {"temperature": round(data['temperature'], 1)}
                        result = self.mqtt_client.publish(topic, json.dumps(payload))
                        if result.rc == mqtt.MQTT_ERR_SUCCESS:
                            logger.info(f"📤 DHT22 Temp: {payload['temperature']}°C → {topic}")
                            published_count += 1
                        else:
                            logger.error(f"❌ MQTT Publish Fehler: {result.rc}")
                        
                    if 'humidity' in data:
                        topic = f"{self.mqtt_prefix}/dht22_humidity/state"
                        payload = {"humidity": round(data['humidity'], 1)}
                        result = self.mqtt_client.publish(topic, json.dumps(payload))
                        if result.rc == mqtt.MQTT_ERR_SUCCESS:
                            logger.info(f"📤 DHT22 Hum: {payload['humidity']}% → {topic}")
                            published_count += 1
                        else:
                            logger.error(f"❌ MQTT Publish Fehler: {result.rc}")
                else:
                    # DS18B20 Temperatursensoren
                    if 'temperature' in data:
                        sensor_name = self.sensor_labels.get(sensor_id, sensor_id)
                        topic = f"{self.mqtt_prefix}/{sensor_id}/state"
                        payload = {"temperature": round(data['temperature'], 1)}
                        result = self.mqtt_client.publish(topic, json.dumps(payload))
                        if result.rc == mqtt.MQTT_ERR_SUCCESS:
                            logger.info(f"📤 {sensor_name}: {payload['temperature']}°C → {topic}")
                            published_count += 1
                        else:
                            logger.error(f"❌ MQTT Publish Fehler: {result.rc}")
                            
            except Exception as e:
                logger.error(f"❌ Fehler beim Senden von {sensor_id}: {e}")
        
        logger.info(f"✅ {published_count} MQTT Updates erfolgreich gesendet")

    def run_once(self):
        """Einmalige Datenübertragung"""
        logger.info("🔄 Lese Sensor-Daten...")
        sensor_data = self.get_latest_sensor_data()
        if sensor_data:
            self.publish_sensor_data(sensor_data)
        else:
            logger.warning("⚠️ Keine Sensor-Daten verfügbar")
            # Status als offline senden wenn keine Daten
            self.mqtt_client.publish(f"{self.mqtt_prefix}/status", "offline", retain=True)

    def run_continuous(self, interval: int = 30):
        """Kontinuierliche Datenübertragung"""
        logger.info(f"🔄 Starte kontinuierliche MQTT Übertragung (alle {interval}s)")
        
        # Discovery alle 10 Minuten erneut senden (für Robustheit)
        discovery_interval = 600  # 10 Minuten
        last_discovery = 0
        
        try:
            while True:
                current_time = time.time()
                
                # Regelmäßige Discovery (alle 10 Minuten)
                if current_time - last_discovery > discovery_interval:
                    logger.info("🔄 Sende Auto-Discovery erneut...")
                    self.publish_discovery()
                    last_discovery = current_time
                
                # Normale Datenübertragung
                self.run_once()
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logger.info("👋 MQTT Bridge beendet durch Benutzer")
        except Exception as e:
            logger.error(f"❌ Fehler in kontinuierlicher Schleife: {e}")
        finally:
            # Cleanup
            if self.mqtt_client:
                logger.info("🧹 MQTT Cleanup...")
                self.mqtt_client.publish(f"{self.mqtt_prefix}/status", "offline", retain=True)
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            if self.influx_client:
                logger.info("🧹 InfluxDB Cleanup...")
                self.influx_client.close()

def test_mqtt_connection(bridge):
    """Test MQTT Verbindung und Discovery"""
    logger.info("🧪 MQTT Verbindungstest...")
    
    # MQTT Connection Test
    if not bridge.setup_mqtt():
        logger.error("❌ MQTT Setup fehlgeschlagen!")
        return False
    
    # Warten auf Verbindung
    logger.info("⏳ Warte auf MQTT Verbindung...")
    time.sleep(3)
    
    # Discovery Test
    logger.info("🧪 Teste Auto-Discovery...")
    bridge.publish_discovery()
    
    # Test-Daten senden
    logger.info("🧪 Sende Test-Daten...")
    test_data = {
        'ds18b20_1': {'temperature': 21.5},
        'ds18b20_2': {'temperature': 45.2},
        'dht22': {'temperature': 23.1, 'humidity': 65.3}
    }
    bridge.publish_sensor_data(test_data)
    
    logger.info("✅ MQTT Test abgeschlossen!")
    time.sleep(2)
    
    # Cleanup
    if bridge.mqtt_client:
        bridge.mqtt_client.publish(f"{bridge.mqtt_prefix}/status", "offline", retain=True)
        bridge.mqtt_client.loop_stop()
        bridge.mqtt_client.disconnect()
    
    return True

def main():
    """Hauptfunktion"""
    import sys
    
    if not INFLUXDB_AVAILABLE or not MQTT_AVAILABLE:
        print("❌ Erforderliche Dependencies fehlen!")
        print("   pip install influxdb-client paho-mqtt")
        sys.exit(1)
    
    # Bridge initialisieren
    bridge = Pi5MqttBridge()
    
    # Ausführungsmodus prüfen
    if len(sys.argv) > 1:
        mode = sys.argv[1].lower()
        
        if mode == "test":
            print("🧪 Test-Modus: Einmalige Datenübertragung")
            if not bridge.setup_influxdb():
                print("❌ InfluxDB Setup fehlgeschlagen!")
                sys.exit(1)
            if not bridge.setup_mqtt():
                print("❌ MQTT Setup fehlgeschlagen!")
                sys.exit(1)
            time.sleep(2)
            bridge.run_once()
            
        elif mode == "mqtt-test":
            print("🧪 MQTT Test-Modus: Verbindung und Discovery testen")
            test_mqtt_connection(bridge)
            
        elif mode == "discovery":
            print("🏠 Discovery-Modus: Nur Auto-Discovery senden")
            if not bridge.setup_mqtt():
                print("❌ MQTT Setup fehlgeschlagen!")
                sys.exit(1)
            time.sleep(2)
            bridge.publish_discovery()
            time.sleep(2)
            
        else:
            print(f"❌ Unbekannter Modus: {mode}")
            print("   Verfügbare Modi: test, mqtt-test, discovery")
            sys.exit(1)
    else:
        # Kontinuierlicher Modus
        print("🔄 Kontinuierlicher Modus")
        
        # Verbindungen setup
        if not bridge.setup_mqtt():
            print("❌ MQTT Setup fehlgeschlagen!")
            sys.exit(1)
            
        if not bridge.setup_influxdb():
            print("❌ InfluxDB Setup fehlgeschlagen!")
            sys.exit(1)
        
        # Warten bis MQTT verbunden
        time.sleep(2)
        
        # Kontinuierlich laufen
        bridge.run_continuous()

if __name__ == "__main__":
    main()
