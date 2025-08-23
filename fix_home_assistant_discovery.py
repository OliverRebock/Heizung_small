#!/usr/bin/env python3
"""
Home Assistant MQTT Discovery Fix
=================================

Dedicated script to send MQTT Discovery messages to Home Assistant
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
        './config.ini'
    ]
    
    for path in config_paths:
        if os.path.exists(path):
            config.read(path)
            print(f"📋 Konfiguration geladen: {path}")
            return config
    
    print("❌ Keine Konfigurationsdatei gefunden!")
    return None

def send_discovery_messages(config):
    """Sende alle Discovery-Nachrichten"""
    
    # MQTT Config
    broker = config.get('mqtt', 'broker', fallback='localhost')
    port = config.getint('mqtt', 'port', fallback=1883)
    username = config.get('mqtt', 'username', fallback='')
    password = config.get('mqtt', 'password', fallback='')
    topic_prefix = config.get('mqtt', 'topic_prefix', fallback='pi5_heizung')
    
    # Sensor Labels
    sensor_labels = {}
    if config.has_section('labels'):
        sensor_labels = dict(config.items('labels'))
    
    print(f"📡 MQTT: {broker}:{port} (User: {username})")
    print(f"🏷️ Sensoren: {len(sensor_labels)}")
    
    # Device Info für Home Assistant
    device_info = {
        "identifiers": ["pi5_heizungs_messer"],
        "name": "Pi5 Heizungs Messer", 
        "model": "Raspberry Pi 5",
        "manufacturer": "Pi5 Heizung Project",
        "sw_version": "1.0.0",
        "suggested_area": "Heizungsraum"
    }
    
    # MQTT Client erstellen
    client = mqtt.Client()
    
    # Connection Callback
    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print("✅ MQTT verbunden")
            send_all_discoveries(client, topic_prefix, sensor_labels, device_info)
        else:
            print(f"❌ MQTT Fehler: {rc}")
    
    def on_publish(client, userdata, mid):
        print(f"📤 Nachricht {mid} gesendet")
    
    client.on_connect = on_connect
    client.on_publish = on_publish
    
    # Authentifizierung
    if username and password:
        client.username_pw_set(username, password)
        print("🔐 MQTT Auth aktiviert")
    
    try:
        # Verbinden
        client.connect(broker, port, 60)
        client.loop_start()
        
        # Warten auf Discovery
        time.sleep(5)
        
        # Status online senden
        client.publish(f"{topic_prefix}/status", "online", retain=True)
        print("📡 Status: online")
        
        # Test-Daten senden
        print("📊 Sende Test-Daten...")
        for sensor_id in sensor_labels.keys():
            if sensor_id == 'dht22':
                client.publish(f"{topic_prefix}/dht22_temperature/state", '{"temperature": 23.5}')
                client.publish(f"{topic_prefix}/dht22_humidity/state", '{"humidity": 65.2}')
            else:
                client.publish(f"{topic_prefix}/{sensor_id}/state", '{"temperature": 21.5}')
        
        time.sleep(2)
        
        # Cleanup
        client.loop_stop()
        client.disconnect()
        
    except Exception as e:
        print(f"❌ MQTT Fehler: {e}")

def send_all_discoveries(client, topic_prefix, sensor_labels, device_info):
    """Alle Discovery-Nachrichten senden"""
    
    discovery_count = 0
    
    for sensor_id, sensor_name in sensor_labels.items():
        print(f"🔧 Konfiguriere Sensor: {sensor_id} ({sensor_name})")
        
        if sensor_id == 'dht22':
            # DHT22 Temperatur
            send_discovery(
                client=client,
                entity_id=f"{topic_prefix}_dht22_temperature",
                name=f"{sensor_name} Temperatur",
                state_topic=f"{topic_prefix}/dht22_temperature/state",
                device_class="temperature",
                unit="°C",
                value_template="{{ value_json.temperature }}",
                device_info=device_info,
                topic_prefix=topic_prefix,
                icon="mdi:thermometer"
            )
            discovery_count += 1
            
            # DHT22 Luftfeuchtigkeit  
            send_discovery(
                client=client,
                entity_id=f"{topic_prefix}_dht22_humidity",
                name=f"{sensor_name} Luftfeuchtigkeit",
                state_topic=f"{topic_prefix}/dht22_humidity/state",
                device_class="humidity",
                unit="%",
                value_template="{{ value_json.humidity }}",
                device_info=device_info,
                topic_prefix=topic_prefix,
                icon="mdi:water-percent"
            )
            discovery_count += 1
            
        else:
            # DS18B20 Temperatursensoren
            send_discovery(
                client=client,
                entity_id=f"{topic_prefix}_{sensor_id}",
                name=sensor_name,
                state_topic=f"{topic_prefix}/{sensor_id}/state",
                device_class="temperature",
                unit="°C", 
                value_template="{{ value_json.temperature }}",
                device_info=device_info,
                topic_prefix=topic_prefix,
                icon="mdi:thermometer"
            )
            discovery_count += 1
    
    print(f"✅ {discovery_count} Discovery-Nachrichten gesendet")

def send_discovery(client, entity_id, name, state_topic, device_class, unit, 
                  value_template, device_info, topic_prefix, icon=None):
    """Einzelne Discovery-Nachricht senden"""
    
    # Discovery Topic (Home Assistant Standard)
    discovery_topic = f"homeassistant/sensor/{entity_id}/config"
    
    # Discovery Payload
    payload = {
        "name": name,
        "unique_id": entity_id,
        "state_topic": state_topic,
        "device_class": device_class,
        "unit_of_measurement": unit,
        "value_template": value_template,
        "device": device_info,
        "availability": [
            {
                "topic": f"{topic_prefix}/status",
                "payload_available": "online",
                "payload_not_available": "offline"
            }
        ],
        "expire_after": 300,  # 5 Minuten
        "force_update": True
    }
    
    if icon:
        payload["icon"] = icon
    
    # JSON senden
    json_payload = json.dumps(payload, indent=2)
    
    print(f"📡 Discovery: {name}")
    print(f"   Topic: {discovery_topic}")
    print(f"   State: {state_topic}")
    
    # Retain = True für Discovery
    result = client.publish(discovery_topic, json_payload, retain=True)
    
    if result.rc != mqtt.MQTT_ERR_SUCCESS:
        print(f"❌ Discovery Fehler für {name}: {result.rc}")
    
    time.sleep(0.1)  # Kurze Pause zwischen Messages

def main():
    """Hauptfunktion"""
    print("🏠 Home Assistant MQTT Discovery Sender")
    print("======================================")
    
    # Config laden
    config = load_config()
    if not config:
        sys.exit(1)
    
    # Discovery senden
    send_discovery_messages(config)
    
    print("\n🎯 Prüfe jetzt in Home Assistant:")
    print("1. Settings → Devices & Services → MQTT")
    print("2. Unter 'Discovered' sollte 'Pi5 Heizungs Messer' stehen")
    print("3. Falls nicht: Developer Tools → Services → 'mqtt.reload' ausführen")
    print("\n✅ Discovery abgeschlossen!")

if __name__ == "__main__":
    main()
