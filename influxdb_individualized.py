#!/usr/bin/env python3
"""
Erweiterte InfluxDB Integration mit individualisierten Sensor-Namen
Schreibt Daten mit benutzerdefinierten Labels in InfluxDB
"""

import logging
import configparser
from datetime import datetime
from typing import Dict, Any, Optional

# InfluxDB Client Import
try:
    from influxdb_client import InfluxDBClient, Point
    from influxdb_client.client.write_api import SYNCHRONOUS
    INFLUXDB_AVAILABLE = True
except ImportError:
    INFLUXDB_AVAILABLE = False

# Individualized Sensor Manager Import
try:
    from individualized_sensors import IndividualizedSensorManager
    SENSOR_MANAGER_AVAILABLE = True
except ImportError:
    SENSOR_MANAGER_AVAILABLE = False

logger = logging.getLogger(__name__)

class IndividualizedInfluxDBWriter:
    """InfluxDB Writer mit individualisierten Sensor-Namen"""
    
    def __init__(self, config_path: str = "config.ini"):
        self.config = configparser.ConfigParser()
        self.config.read(config_path)
        
        # InfluxDB Konfiguration
        self.host = self.config.get('influxdb', 'host', fallback='localhost')
        self.port = self.config.getint('influxdb', 'port', fallback=8086)
        self.token = self.config.get('influxdb', 'token', fallback='pi5-sensor-token-2024-super-secret')
        self.org = self.config.get('influxdb', 'org', fallback='Pi5SensorOrg')
        self.bucket = self.config.get('influxdb', 'bucket', fallback='sensor_data')
        
        self.url = f"http://{self.host}:{self.port}"
        self.client = None
        self.write_api = None
        self.connected = False
        
        # Sensor Manager
        if SENSOR_MANAGER_AVAILABLE:
            self.sensor_manager = IndividualizedSensorManager(config_path)
        
        # Verbindung herstellen
        self.connect()
    
    def connect(self) -> bool:
        """Verbindung zu InfluxDB herstellen"""
        if not INFLUXDB_AVAILABLE:
            logger.error("❌ InfluxDB Client nicht verfügbar!")
            return False
        
        try:
            self.client = InfluxDBClient(
                url=self.url,
                token=self.token,
                org=self.org,
                timeout=10000
            )
            
            # Verbindung testen
            health = self.client.health()
            if health.status == "pass":
                logger.info("✅ InfluxDB Verbindung erfolgreich")
                self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
                self.connected = True
                return True
            else:
                logger.error(f"❌ InfluxDB Health Check fehlgeschlagen: {health.status}")
                return False
                
        except Exception as e:
            logger.error(f"❌ InfluxDB Verbindung fehlgeschlagen: {e}")
            self.connected = False
            return False
    
    def write_individualized_sensor_data(self, sensor_data: Dict[str, Any]) -> bool:
        """Schreibt individualisierte Sensor-Daten in InfluxDB"""
        if not self.connected or not self.write_api:
            logger.error("❌ Keine InfluxDB Verbindung")
            return False
        
        try:
            points = []
            
            for sensor_name, data in sensor_data.items():
                if data['value'] is not None:
                    # Point für InfluxDB erstellen
                    point = Point("sensor_reading") \
                        .tag("sensor_name", sensor_name) \
                        .tag("sensor_id", data['sensor_id']) \
                        .tag("sensor_type", data['sensor_type']) \
                        .tag("measurement_type", data['measurement']) \
                        .tag("location", "heizungsanlage") \
                        .tag("unit", data['unit']) \
                        .tag("status", data['status']) \
                        .field("value", float(data['value'])) \
                        .time(datetime.fromisoformat(data['timestamp']))
                    
                    points.append(point)
                    
                    logger.debug(f"📊 {sensor_name}: {data['value']}{data['unit']}")
            
            # Batch-Write in InfluxDB
            if points:
                self.write_api.write(bucket=self.bucket, record=points)
                logger.info(f"✅ {len(points)} Datenpunkte in InfluxDB geschrieben")
                return True
            else:
                logger.warning("⚠️  Keine gültigen Datenpunkte zum Schreiben")
                return False
                
        except Exception as e:
            logger.error(f"❌ Fehler beim Schreiben in InfluxDB: {e}")
            return False
    
    def write_current_readings(self) -> bool:
        """Liest aktuelle Sensor-Daten und schreibt in InfluxDB"""
        if not SENSOR_MANAGER_AVAILABLE:
            logger.error("❌ Sensor Manager nicht verfügbar")
            return False
        
        try:
            # Aktuelle Sensor-Daten abrufen
            sensor_data = self.sensor_manager.get_individualized_sensor_data()
            
            if not sensor_data:
                logger.warning("⚠️  Keine Sensor-Daten verfügbar")
                return False
            
            # In InfluxDB schreiben
            return self.write_individualized_sensor_data(sensor_data)
            
        except Exception as e:
            logger.error(f"❌ Fehler beim Abrufen und Schreiben der Sensor-Daten: {e}")
            return False
    
    def create_sensor_metadata(self):
        """Erstellt Metadaten-Einträge für alle Sensoren"""
        if not SENSOR_MANAGER_AVAILABLE:
            return
        
        try:
            mapping = self.sensor_manager.get_sensor_mapping()
            points = []
            
            for sensor_id, sensor_name in mapping.items():
                # Sensor-Typ bestimmen
                if 'DS18B20' in sensor_id:
                    sensor_type = 'DS18B20'
                    measurement_type = 'temperature'
                    unit = '°C'
                elif 'DHT22_temp' in sensor_id:
                    sensor_type = 'DHT22'
                    measurement_type = 'temperature'
                    unit = '°C'
                elif 'DHT22_humidity' in sensor_id:
                    sensor_type = 'DHT22'
                    measurement_type = 'humidity'
                    unit = '%'
                else:
                    continue
                
                # Metadaten-Point erstellen
                point = Point("sensor_metadata") \
                    .tag("sensor_id", sensor_id) \
                    .tag("sensor_name", sensor_name) \
                    .tag("sensor_type", sensor_type) \
                    .tag("measurement_type", measurement_type) \
                    .tag("unit", unit) \
                    .tag("location", "heizungsanlage") \
                    .field("active", True) \
                    .time(datetime.now())
                
                points.append(point)
            
            # Metadaten schreiben
            if points:
                self.write_api.write(bucket=self.bucket, record=points)
                logger.info(f"✅ {len(points)} Sensor-Metadaten in InfluxDB geschrieben")
            
        except Exception as e:
            logger.error(f"❌ Fehler beim Erstellen der Sensor-Metadaten: {e}")
    
    def query_sensor_data(self, sensor_name: str, hours: int = 24) -> Optional[list]:
        """Fragt Sensor-Daten für einen bestimmten Sensor ab"""
        if not self.connected:
            return None
        
        try:
            query = f'''
            from(bucket: "{self.bucket}")
                |> range(start: -{hours}h)
                |> filter(fn: (r) => r["_measurement"] == "sensor_reading")
                |> filter(fn: (r) => r["sensor_name"] == "{sensor_name}")
                |> filter(fn: (r) => r["_field"] == "value")
                |> sort(columns: ["_time"], desc: false)
            '''
            
            query_api = self.client.query_api()
            result = query_api.query(query=query)
            
            # Ergebnisse verarbeiten
            data_points = []
            for table in result:
                for record in table.records:
                    data_points.append({
                        'time': record.get_time(),
                        'value': record.get_value(),
                        'sensor_name': record.values.get('sensor_name'),
                        'sensor_type': record.values.get('sensor_type'),
                        'unit': record.values.get('unit')
                    })
            
            return data_points
            
        except Exception as e:
            logger.error(f"❌ Fehler beim Abfragen der Sensor-Daten: {e}")
            return None

def main():
    """Test der individualisierten InfluxDB Integration"""
    print("📊 Test: Individualisierte InfluxDB Integration")
    print("=" * 55)
    
    # InfluxDB Writer initialisieren
    influx_writer = IndividualizedInfluxDBWriter()
    
    if not influx_writer.connected:
        print("❌ Keine InfluxDB Verbindung - Test mit Mock-Daten")
    
    # Sensor-Metadaten erstellen
    print("\n📝 Erstelle Sensor-Metadaten...")
    influx_writer.create_sensor_metadata()
    
    # Aktuelle Sensor-Daten schreiben
    print("\n📊 Schreibe aktuelle Sensor-Daten...")
    success = influx_writer.write_current_readings()
    
    if success:
        print("✅ Daten erfolgreich in InfluxDB geschrieben")
    else:
        print("❌ Fehler beim Schreiben der Daten")
    
    # Beispiel-Abfrage
    if influx_writer.connected and SENSOR_MANAGER_AVAILABLE:
        print("\n🔍 Beispiel-Abfrage der letzten Daten...")
        sensor_manager = IndividualizedSensorManager()
        mapping = sensor_manager.get_sensor_mapping()
        
        if mapping:
            first_sensor = list(mapping.values())[0]
            recent_data = influx_writer.query_sensor_data(first_sensor, hours=1)
            
            if recent_data:
                print(f"📈 Letzte {len(recent_data)} Datenpunkte für '{first_sensor}':")
                for point in recent_data[-5:]:  # Letzte 5 Punkte
                    print(f"   {point['time']}: {point['value']}{point['unit']}")
            else:
                print("ℹ️  Noch keine historischen Daten verfügbar")

if __name__ == "__main__":
    main()
