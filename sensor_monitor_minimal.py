#!/usr/bin/env python3
"""
🌡️ Pi 5 Sensor Monitor - MINIMAL VERSION
Fokus: InfluxDB + Individualisierte Sensoren
"""

import os
import sys
import time
import glob
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
        
        print(f"📊 {timestamp.strftime('%Y-%m-%d %H:%M:%S')} - Lese Sensoren...")
        
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
                print(f"   📏 {sensor_info['label']}: {temp}°C")
                
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
            print(f"   📏 {dht_label} Temp: {temp}°C")
            
        if humidity is not None:
            point = Point("humidity") \
                .tag("sensor", "dht22") \
                .tag("label", dht_label) \
                .tag("type", "DHT22") \
                .field("value", humidity) \
                .time(timestamp)
            measurements.append(point)
            print(f"   📏 {dht_label} Humidity: {humidity}%")
            
        return measurements
        
    def write_to_influxdb(self, measurements):
        """Daten zu InfluxDB schreiben"""
        try:
            self.write_api.write(
                bucket=self.config['database']['bucket'],
                org=self.config['database']['org'],
                record=measurements
            )
            print(f"   ✅ {len(measurements)} Messungen zu InfluxDB geschrieben")
        except Exception as e:
            print(f"   ❌ InfluxDB Fehler: {e}")
            
    def monitor_continuous(self, interval=30):
        """Kontinuierliches Monitoring"""
        print("🚀 Pi 5 Sensor Monitor - MINIMAL")
        print("=" * 40)
        print(f"🔄 Monitoring alle {interval} Sekunden")
        print("🏷️  Individualisierte Sensornamen aktiv!")
        print("🔓 Grafana ohne Login verfügbar")
        print("=" * 40)
        
        while True:
            try:
                measurements = self.read_all_sensors()
                if measurements:
                    self.write_to_influxdb(measurements)
                else:
                    print("   ⚠️  Keine Sensordaten verfügbar")
                    
                print(f"   ⏳ Warte {interval}s bis zur nächsten Messung...")
                print("-" * 40)
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n🛑 Monitoring gestoppt")
                break
            except Exception as e:
                print(f"   ❌ Fehler: {e}")
                print("   🔄 Versuche es in 5s erneut...")
                time.sleep(5)

if __name__ == "__main__":
    monitor = MinimalSensorMonitor()
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        print("🧪 SENSOR TEST MODE")
        print("=" * 30)
        measurements = monitor.read_all_sensors()
        print(f"\n✅ {len(measurements)} Sensoren gefunden")
        if measurements:
            print("🏷️  Individualisierte Namen:")
            for measurement in measurements:
                tags = measurement._tags
                print(f"   • {tags.get('label', 'Unbekannt')} ({tags.get('sensor', 'N/A')})")
    else:
        monitor.monitor_continuous()
