#!/usr/bin/env python3
"""
🧪 Test Script für alle 9 Sensoren (8x DS18B20 + 1x DHT22)
"""

import os
import sys
import glob
import time
import configparser

def test_ds18b20_sensors():
    """Teste alle DS18B20 Sensoren"""
    print("🔍 Teste DS18B20 Sensoren...")
    
    devices = glob.glob('/sys/bus/w1/devices/28-*')
    print(f"   Gefundene DS18B20 Geräte: {len(devices)}")
    
    working_sensors = 0
    for i, device in enumerate(devices[:8], 1):
        try:
            with open(f"{device}/w1_slave", 'r') as f:
                data = f.read()
            if 'YES' in data:
                temp_pos = data.find('t=') + 2
                temp_c = float(data[temp_pos:]) / 1000.0
                print(f"   ✅ DS18B20_{i}: {temp_c:.2f}°C")
                working_sensors += 1
            else:
                print(f"   ❌ DS18B20_{i}: CRC Fehler")
        except Exception as e:
            print(f"   ❌ DS18B20_{i}: {e}")
            
    return working_sensors

def test_dht22_sensor():
    """Teste DHT22 Sensor"""
    print("🔍 Teste DHT22 Sensor...")
    
    try:
        import adafruit_dht
        import board
        
        # Mehrere Versuche da DHT22 unzuverlässig sein kann
        dht = adafruit_dht.DHT22(board.D18)
        
        for attempt in range(3):
            try:
                temp = dht.temperature
                humidity = dht.humidity
                
                if temp is not None and humidity is not None:
                    print(f"   ✅ DHT22 Temp: {temp:.2f}°C")
                    print(f"   ✅ DHT22 Humidity: {humidity:.2f}%")
                    return True
                    
            except RuntimeError as e:
                if attempt < 2:
                    print(f"   ⚠️  DHT22 Versuch {attempt + 1}/3 fehlgeschlagen, versuche erneut...")
                    time.sleep(0.5)
                else:
                    print(f"   ❌ DHT22 Fehler nach 3 Versuchen: {e}")
                    
    except ImportError as e:
        print(f"   ❌ DHT22 Import Fehler: {e}")
        print("   💡 Installiere: pip install adafruit-circuitpython-dht adafruit-blinka")
    except Exception as e:
        print(f"   ❌ DHT22 Fehler: {e}")
        
    return False

def test_config():
    """Teste Konfigurationsdatei"""
    print("🔍 Teste config.ini...")
    
    if not os.path.exists('config.ini'):
        print("   ❌ config.ini nicht gefunden!")
        return False
        
    try:
        config = configparser.ConfigParser()
        config.read('config.ini')
        
        # Prüfe Sektionen
        required_sections = ['database', 'sensors', 'labels']
        for section in required_sections:
            if section in config:
                print(f"   ✅ Sektion [{section}] gefunden")
            else:
                print(f"   ❌ Sektion [{section}] fehlt!")
                return False
                
        # Prüfe Labels
        labels = dict(config.items('labels'))
        print(f"   📋 Individualisierte Labels: {len(labels)}")
        for key, value in labels.items():
            print(f"      • {key} = {value}")
            
        return True
        
    except Exception as e:
        print(f"   ❌ Config Fehler: {e}")
        return False

def test_influxdb_connection():
    """Teste InfluxDB Verbindung"""
    print("🔍 Teste InfluxDB Verbindung...")
    
    try:
        from influxdb_client import InfluxDBClient
        
        config = configparser.ConfigParser()
        config.read('config.ini')
        
        client = InfluxDBClient(
            url=f"http://{config['database']['host']}:{config['database']['port']}",
            token=config['database']['token'],
            org=config['database']['org']
        )
        
        # Teste Verbindung
        health = client.health()
        if health.status == "pass":
            print("   ✅ InfluxDB Verbindung erfolgreich")
            return True
        else:
            print(f"   ❌ InfluxDB Status: {health.status}")
            
    except ImportError:
        print("   ❌ influxdb_client nicht installiert")
        print("   💡 Installiere: pip install influxdb-client")
    except Exception as e:
        print(f"   ❌ InfluxDB Verbindung Fehler: {e}")
        print("   💡 Prüfe ob Docker Container laufen: docker compose ps")
        
    return False

def main():
    """Haupttest"""
    print("🧪 SENSOR TEST - Pi 5 Monitor (9 Sensoren)")
    print("=" * 50)
    
    # Wechsle ins richtige Verzeichnis
    if os.path.exists('/home/pi/sensor-monitor'):
        os.chdir('/home/pi/sensor-monitor')
        print(f"📁 Arbeitsverzeichnis: {os.getcwd()}")
    
    # Tests ausführen
    ds18b20_count = test_ds18b20_sensors()
    print()
    
    dht22_ok = test_dht22_sensor()
    print()
    
    config_ok = test_config()
    print()
    
    influxdb_ok = test_influxdb_connection()
    print()
    
    # Zusammenfassung
    print("📊 TEST ZUSAMMENFASSUNG")
    print("=" * 30)
    print(f"   DS18B20 Sensoren: {ds18b20_count}/8")
    print(f"   DHT22 Sensor: {'✅' if dht22_ok else '❌'}")
    print(f"   Konfiguration: {'✅' if config_ok else '❌'}")
    print(f"   InfluxDB: {'✅' if influxdb_ok else '❌'}")
    
    total_sensors = ds18b20_count + (2 if dht22_ok else 0)
    print(f"   TOTAL: {total_sensors}/10 Messwerte (9 Sensoren)")
    
    if total_sensors >= 8:
        print("🎉 System bereit für Monitoring!")
    else:
        print("⚠️  System braucht Aufmerksamkeit")
        
    return total_sensors >= 8

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
