#!/usr/bin/env python3
"""
MQTT Debug Tool für Pi5 Heizungs Messer
=======================================

Debug-Tool um MQTT Verbindung und Home Assistant Integration zu testen.
"""

import json
import time
import configparser
import os
import sys

try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False
    print("❌ MQTT Client nicht verfügbar - installiere: pip install paho-mqtt")
    sys.exit(1)

def load_config():
    """Konfiguration laden"""
    config = configparser.ConfigParser()
    
    config_paths = [
        '/home/pi/pi5-sensors/config.ini',
        './config.ini',
        './mqtt_config.ini'
    ]
    
    for path in config_paths:
        if os.path.exists(path):
            config.read(path)
            print(f"📋 Konfiguration geladen: {path}")
            return config
    
    print("❌ Keine Konfigurationsdatei gefunden!")
    return None

def test_mqtt_basic(config):
    """Grundlegende MQTT Verbindung testen"""
    print("\n🔌 MQTT Verbindungstest")
    print("=" * 50)
    
    broker = config.get('mqtt', 'broker', fallback='localhost')
    port = config.getint('mqtt', 'port', fallback=1883)
    username = config.get('mqtt', 'username', fallback='')
    password = config.get('mqtt', 'password', fallback='')
    
    print(f"📡 Broker: {broker}:{port}")
    if username:
        print(f"🔐 User: {username}")
    else:
        print("🔓 Keine Authentifizierung")
    
    # MQTT Client erstellen
    client = mqtt.Client()
    
    # Callbacks
    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print("✅ MQTT Verbindung erfolgreich!")
        else:
            print(f"❌ MQTT Verbindung fehlgeschlagen: {rc}")
            
    def on_disconnect(client, userdata, rc):
        print(f"🔌 MQTT Verbindung getrennt: {rc}")
        
    def on_publish(client, userdata, mid):
        print(f"📤 Nachricht gesendet: {mid}")
    
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_publish = on_publish
    
    # Authentifizierung
    if username and password:
        client.username_pw_set(username, password)
    
    try:
        # Verbinden
        client.connect(broker, port, 60)
        client.loop_start()
        
        # Warten auf Verbindung
        time.sleep(2)
        
        # Test-Nachricht senden
        print("📤 Sende Test-Nachricht...")
        client.publish("pi5_heizung/test", "MQTT Test OK")
        
        time.sleep(1)
        
        # Cleanup
        client.loop_stop()
        client.disconnect()
        
        return True
        
    except Exception as e:
        print(f"❌ MQTT Fehler: {e}")
        return False

def test_home_assistant_discovery(config):
    """Home Assistant Auto-Discovery testen"""
    print("\n🏠 Home Assistant Discovery Test")
    print("=" * 50)
    
    broker = config.get('mqtt', 'broker', fallback='localhost')
    port = config.getint('mqtt', 'port', fallback=1883)
    username = config.get('mqtt', 'username', fallback='')
    password = config.get('mqtt', 'password', fallback='')
    topic_prefix = config.get('mqtt', 'topic_prefix', fallback='pi5_heizung')
    
    # Sensor Labels
    sensor_labels = {}
    if config.has_section('labels'):
        sensor_labels = dict(config.items('labels'))
    
    print(f"🏷️ Sensoren: {len(sensor_labels)}")
    for sensor_id, sensor_name in sensor_labels.items():
        print(f"   {sensor_id}: {sensor_name}")
    
    # MQTT Client
    client = mqtt.Client()
    
    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print("✅ MQTT verbunden - sende Discovery...")
            send_discovery(client, topic_prefix, sensor_labels)
        else:
            print(f"❌ MQTT Verbindung fehlgeschlagen: {rc}")
    
    client.on_connect = on_connect
    
    if username and password:
        client.username_pw_set(username, password)
    
    try:
        client.connect(broker, port, 60)
        client.loop_start()
        time.sleep(3)
        client.loop_stop()
        client.disconnect()
        
    except Exception as e:
        print(f"❌ Discovery Fehler: {e}")

def send_discovery(client, topic_prefix, sensor_labels):
    """Discovery-Nachrichten senden"""
    
    device_info = {
        "identifiers": ["pi5_heizungs_messer"],
        "name": "Pi5 Heizungs Messer",
        "model": "Raspberry Pi 5",
        "manufacturer": "Pi5 Heizung Project",
        "sw_version": "1.0.0"
    }
    
    discovery_count = 0
    
    for sensor_id, sensor_name in sensor_labels.items():
        if sensor_id == 'dht22':
            # DHT22 Temperatur
            discovery_topic = f"homeassistant/sensor/{topic_prefix}_dht22_temperature/config"
            state_topic = f"{topic_prefix}/dht22_temperature/state"
            
            payload = {
                "name": f"{sensor_name} Temperatur",
                "unique_id": f"{topic_prefix}_dht22_temperature",
                "state_topic": state_topic,
                "device_class": "temperature",
                "unit_of_measurement": "°C",
                "value_template": "{{ value_json.temperature }}",
                "device": device_info,
                "icon": "mdi:thermometer"
            }
            
            client.publish(discovery_topic, json.dumps(payload), retain=True)
            print(f"📡 Discovery: {sensor_name} Temperatur → {discovery_topic}")
            discovery_count += 1
            
            # DHT22 Luftfeuchtigkeit
            discovery_topic = f"homeassistant/sensor/{topic_prefix}_dht22_humidity/config"
            state_topic = f"{topic_prefix}/dht22_humidity/state"
            
            payload = {
                "name": f"{sensor_name} Luftfeuchtigkeit",
                "unique_id": f"{topic_prefix}_dht22_humidity",
                "state_topic": state_topic,
                "device_class": "humidity",
                "unit_of_measurement": "%",
                "value_template": "{{ value_json.humidity }}",
                "device": device_info,
                "icon": "mdi:water-percent"
            }
            
            client.publish(discovery_topic, json.dumps(payload), retain=True)
            print(f"📡 Discovery: {sensor_name} Luftfeuchtigkeit → {discovery_topic}")
            discovery_count += 1
            
        else:
            # DS18B20 Temperatursensoren
            discovery_topic = f"homeassistant/sensor/{topic_prefix}_{sensor_id}/config"
            state_topic = f"{topic_prefix}/{sensor_id}/state"
            
            payload = {
                "name": sensor_name,
                "unique_id": f"{topic_prefix}_{sensor_id}",
                "state_topic": state_topic,
                "device_class": "temperature",
                "unit_of_measurement": "°C",
                "value_template": "{{ value_json.temperature }}",
                "device": device_info,
                "icon": "mdi:thermometer"
            }
            
            client.publish(discovery_topic, json.dumps(payload), retain=True)
            print(f"📡 Discovery: {sensor_name} → {discovery_topic}")
            discovery_count += 1
    
    print(f"✅ {discovery_count} Discovery-Nachrichten gesendet")
    
    # Test-Daten senden
    print("📤 Sende Test-Daten...")
    client.publish(f"{topic_prefix}/status", "online", retain=True)
    
    # Test-Temperaturen
    test_data = [
        ("ds18b20_1", 21.5),
        ("ds18b20_2", 45.2),
        ("dht22_temperature", 23.1),
        ("dht22_humidity", 65.3)
    ]
    
    for sensor_id, value in test_data:
        if "humidity" in sensor_id:
            topic = f"{topic_prefix}/{sensor_id}/state"
            payload = {"humidity": value}
        else:
            topic = f"{topic_prefix}/{sensor_id}/state"
            payload = {"temperature": value}
        
        client.publish(topic, json.dumps(payload))
        print(f"📤 Test-Daten: {sensor_id} = {value} → {topic}")

def main():
    """Hauptfunktion"""
    print("🧪 Pi5 MQTT Debug Tool")
    print("=" * 50)
    
    # Konfiguration laden
    config = load_config()
    if not config:
        sys.exit(1)
    
    # MQTT Grundtest
    if test_mqtt_basic(config):
        print("✅ MQTT Grundtest erfolgreich")
    else:
        print("❌ MQTT Grundtest fehlgeschlagen")
        sys.exit(1)
    
    # Home Assistant Discovery Test
    test_home_assistant_discovery(config)
    
    print("\n🎯 Debug abgeschlossen!")
    print("📋 Nächste Schritte:")
    print("   1. Prüfe Home Assistant Logs")
    print("   2. Schaue in Settings → Devices & Services → MQTT")
    print("   3. Prüfe MQTT Topics in MQTT Explorer oder HA")

if __name__ == "__main__":
    main()
