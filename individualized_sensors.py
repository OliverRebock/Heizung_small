#!/usr/bin/env python3
"""
Erweiterte Sensor-Individualisierung für Pi 5 Sensor Monitor
Unterstützt 8x DS18B20 + 1x DHT22 mit individuellen Namen
"""

import configparser
import logging
from typing import Dict, Any, Optional
from datetime import datetime

# Sensor Monitor Import
try:
    from sensor_monitor import Pi5SensorMonitor, Pi5DS18B20Manager, Pi5DHT22Sensor
    SENSOR_MONITOR_AVAILABLE = True
except ImportError:
    SENSOR_MONITOR_AVAILABLE = False

logger = logging.getLogger(__name__)

class IndividualizedSensorManager:
    """Erweiterte Sensor-Manager mit individuellen Namen"""
    
    def __init__(self, config_path: str = "config.ini"):
        self.config = configparser.ConfigParser()
        self.config.read(config_path)
        
        # Sensor-Labels laden
        self.sensor_labels = {}
        if self.config.has_section('labels'):
            for key, value in self.config.items('labels'):
                self.sensor_labels[key] = value
        
        # Hardware-Konfiguration
        self.ds18b20_count = self.config.getint('hardware', 'ds18b20_count', fallback=8)
        
        if SENSOR_MONITOR_AVAILABLE:
            self.ds18b20_manager = Pi5DS18B20Manager(high_performance=True)
            self.dht22_sensor = Pi5DHT22Sensor(pin=18, use_pi5_optimizations=True)
    
    def get_individualized_sensor_data(self) -> Dict[str, Any]:
        """Holt Sensor-Daten mit individuellen Namen"""
        if not SENSOR_MONITOR_AVAILABLE:
            return self._get_mock_data()
        
        try:
            # DS18B20 Temperaturen
            ds_temps = self.ds18b20_manager.get_all_temperatures()
            
            # DHT22 Daten
            dht_temp, dht_humidity = self.dht22_sensor.read_data()
            
            # Individualisierte Daten erstellen
            individualized_data = {}
            
            # DS18B20 Sensoren mit Labels
            for i in range(1, self.ds18b20_count + 1):
                sensor_key = f"DS18B20_{i}"
                label_key = f"ds18b20_{i}"
                
                if sensor_key in ds_temps and ds_temps[sensor_key] is not None:
                    individualized_data[self.sensor_labels.get(label_key, sensor_key)] = {
                        'sensor_id': sensor_key,
                        'sensor_type': 'DS18B20',
                        'measurement': 'temperature',
                        'value': ds_temps[sensor_key],
                        'unit': '°C',
                        'timestamp': datetime.now().isoformat(),
                        'status': 'ok' if 5 <= ds_temps[sensor_key] <= 80 else 'warning'
                    }
                else:
                    individualized_data[self.sensor_labels.get(label_key, sensor_key)] = {
                        'sensor_id': sensor_key,
                        'sensor_type': 'DS18B20',
                        'measurement': 'temperature',
                        'value': None,
                        'unit': '°C',
                        'timestamp': datetime.now().isoformat(),
                        'status': 'error'
                    }
            
            # DHT22 Temperatur
            if dht_temp is not None:
                individualized_data[self.sensor_labels.get('dht22', 'DHT22') + ' (Temperatur)'] = {
                    'sensor_id': 'DHT22_temp',
                    'sensor_type': 'DHT22',
                    'measurement': 'temperature',
                    'value': dht_temp,
                    'unit': '°C',
                    'timestamp': datetime.now().isoformat(),
                    'status': 'ok' if 15 <= dht_temp <= 30 else 'warning'
                }
            
            # DHT22 Luftfeuchtigkeit
            if dht_humidity is not None:
                individualized_data[self.sensor_labels.get('dht22', 'DHT22') + ' (Luftfeuchtigkeit)'] = {
                    'sensor_id': 'DHT22_humidity',
                    'sensor_type': 'DHT22',
                    'measurement': 'humidity',
                    'value': dht_humidity,
                    'unit': '%',
                    'timestamp': datetime.now().isoformat(),
                    'status': 'ok' if 30 <= dht_humidity <= 70 else 'warning'
                }
            
            return individualized_data
            
        except Exception as e:
            logger.error(f"Fehler beim Lesen der individualisierten Sensor-Daten: {e}")
            return {}
    
    def _get_mock_data(self) -> Dict[str, Any]:
        """Mock-Daten für Tests"""
        import random
        mock_data = {}
        
        # Mock DS18B20 Daten
        for i in range(1, self.ds18b20_count + 1):
            label_key = f"ds18b20_{i}"
            sensor_name = self.sensor_labels.get(label_key, f"DS18B20_{i}")
            
            mock_data[sensor_name] = {
                'sensor_id': f"DS18B20_{i}",
                'sensor_type': 'DS18B20',
                'measurement': 'temperature',
                'value': round(random.uniform(15, 35), 1),
                'unit': '°C',
                'timestamp': datetime.now().isoformat(),
                'status': 'ok'
            }
        
        # Mock DHT22 Daten
        dht_label = self.sensor_labels.get('dht22', 'DHT22')
        
        mock_data[f"{dht_label} (Temperatur)"] = {
            'sensor_id': 'DHT22_temp',
            'sensor_type': 'DHT22',
            'measurement': 'temperature',
            'value': round(random.uniform(18, 25), 1),
            'unit': '°C',
            'timestamp': datetime.now().isoformat(),
            'status': 'ok'
        }
        
        mock_data[f"{dht_label} (Luftfeuchtigkeit)"] = {
            'sensor_id': 'DHT22_humidity',
            'sensor_type': 'DHT22',
            'measurement': 'humidity',
            'value': round(random.uniform(40, 60), 1),
            'unit': '%',
            'timestamp': datetime.now().isoformat(),
            'status': 'ok'
        }
        
        return mock_data
    
    def get_sensor_mapping(self) -> Dict[str, str]:
        """Gibt Mapping zwischen Sensor-IDs und individuellen Namen zurück"""
        mapping = {}
        
        for i in range(1, self.ds18b20_count + 1):
            label_key = f"ds18b20_{i}"
            sensor_id = f"DS18B20_{i}"
            individual_name = self.sensor_labels.get(label_key, sensor_id)
            mapping[sensor_id] = individual_name
        
        dht_name = self.sensor_labels.get('dht22', 'DHT22')
        mapping['DHT22_temp'] = f"{dht_name} (Temperatur)"
        mapping['DHT22_humidity'] = f"{dht_name} (Luftfeuchtigkeit)"
        
        return mapping
    
    def print_sensor_overview(self):
        """Druckt Übersicht der individualisierten Sensoren"""
        print("🏷️  Individualisierte Sensor-Übersicht")
        print("=" * 50)
        
        mapping = self.get_sensor_mapping()
        
        print("DS18B20 Temperatursensoren:")
        for i in range(1, self.ds18b20_count + 1):
            sensor_id = f"DS18B20_{i}"
            individual_name = mapping[sensor_id]
            print(f"  {sensor_id:12} → {individual_name}")
        
        print("\nDHT22 Sensor:")
        print(f"  DHT22_temp   → {mapping['DHT22_temp']}")
        print(f"  DHT22_humid  → {mapping['DHT22_humidity']}")

def main():
    """Test der individualisierten Sensor-Namen"""
    print("🏷️  Test: Individualisierte Sensor-Namen")
    print("=" * 50)
    
    # Manager initialisieren
    sensor_manager = IndividualizedSensorManager()
    
    # Sensor-Übersicht anzeigen
    sensor_manager.print_sensor_overview()
    
    print("\n📊 Aktuelle Sensor-Daten:")
    print("-" * 30)
    
    # Individualisierte Daten abrufen
    data = sensor_manager.get_individualized_sensor_data()
    
    for name, info in data.items():
        status_emoji = "✅" if info['status'] == 'ok' else "⚠️" if info['status'] == 'warning' else "❌"
        value_str = f"{info['value']}{info['unit']}" if info['value'] is not None else "FEHLER"
        print(f"{status_emoji} {name:25} {value_str:>8}")

if __name__ == "__main__":
    main()
