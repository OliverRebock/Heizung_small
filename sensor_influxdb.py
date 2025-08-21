#!/usr/bin/env python3
"""
InfluxDB Integration für Pi 5 Sensor-Monitor
Schreibt Sensor-Daten in InfluxDB Docker Container
"""

import logging
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import json

# InfluxDB Client Import
try:
    from influxdb_client import InfluxDBClient, Point
    from influxdb_client.client.write_api import SYNCHRONOUS
    INFLUXDB_AVAILABLE = True
    logging.info("✅ InfluxDB Client verfügbar")
except ImportError as e:
    logging.warning(f"⚠️  InfluxDB Client nicht verfügbar: {e}")
    logging.info("💡 Installiere mit: pip install influxdb-client")
    INFLUXDB_AVAILABLE = False

# Sensor Monitor Import
try:
    from sensor_monitor import Pi5SensorMonitor
    SENSOR_MONITOR_AVAILABLE = True
except ImportError as e:
    logging.error(f"❌ Sensor Monitor nicht verfügbar: {e}")
    SENSOR_MONITOR_AVAILABLE = False

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/home/pi/sensor-monitor-pi5/influxdb.log')
    ]
)
logger = logging.getLogger(__name__)

class Pi5InfluxDBIntegration:
    """InfluxDB Integration für Pi 5 Sensor-Daten"""
    
    def __init__(self, 
                 host: str = "localhost",
                 port: int = 8086,
                 token: str = "pi5-sensor-token-2024-super-secret",
                 org: str = "Pi5SensorOrg",
                 bucket: str = "sensor_data"):
        
        self.host = host
        self.port = port
        self.token = token
        self.org = org
        self.bucket = bucket
        self.url = f"http://{host}:{port}"
        
        self.client = None
        self.write_api = None
        self.connected = False
        
        logger.info(f"🗄️  InfluxDB Integration initialisiert:")
        logger.info(f"   📡 URL: {self.url}")
        logger.info(f"   🏢 Organisation: {org}")
        logger.info(f"   📦 Bucket: {bucket}")
        
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
            logger.info("💡 Prüfe ob Docker Container läuft: docker compose ps")
            self.connected = False
            return False
    
    def write_sensor_data(self, ds18b20_temps: Dict[str, float], 
                         dht22_temp: Optional[float], 
                         dht22_humidity: Optional[float]) -> bool:
        """Sensor-Daten in InfluxDB schreiben"""
        if not self.connected:
            logger.warning("⚠️  Keine InfluxDB Verbindung - versuche Reconnect...")
            if not self.connect():
                return False
        
        try:
            points = []
            timestamp = datetime.utcnow()
            
            # DS18B20 Temperaturdaten
            for sensor_name, temperature in ds18b20_temps.items():
                if temperature is not None:
                    point = Point("temperature") \
                        .tag("sensor_type", "DS18B20") \
                        .tag("sensor_name", sensor_name) \
                        .tag("location", "pi5_system") \
                        .tag("unit", "celsius") \
                        .field("temperature_celsius", float(temperature)) \
                        .time(timestamp)
                    points.append(point)
            
            # DHT22 Temperaturdaten
            if dht22_temp is not None:
                point = Point("temperature") \
                    .tag("sensor_type", "DHT22") \
                    .tag("sensor_name", "DHT22_1") \
                    .tag("location", "pi5_system") \
                    .tag("unit", "celsius") \
                    .field("temperature_celsius", float(dht22_temp)) \
                    .time(timestamp)
                points.append(point)
            
            # DHT22 Luftfeuchtigkeitsdaten
            if dht22_humidity is not None:
                point = Point("humidity") \
                    .tag("sensor_type", "DHT22") \
                    .tag("sensor_name", "DHT22_1") \
                    .tag("location", "pi5_system") \
                    .tag("unit", "percent") \
                    .field("humidity_percent", float(dht22_humidity)) \
                    .time(timestamp)
                points.append(point)
            
            # System-Metadaten
            system_point = Point("system_info") \
                .tag("device", "raspberry_pi_5") \
                .tag("location", "pi5_system") \
                .field("sensor_count", len(ds18b20_temps)) \
                .field("dht22_available", dht22_temp is not None) \
                .field("timestamp_unix", int(timestamp.timestamp())) \
                .time(timestamp)
            points.append(system_point)
            
            # Alle Punkte schreiben
            if points:
                self.write_api.write(bucket=self.bucket, record=points)
                logger.info(f"✅ {len(points)} Datenpunkte in InfluxDB geschrieben")
                return True
            else:
                logger.warning("⚠️  Keine Daten zum Schreiben verfügbar")
                return False
                
        except Exception as e:
            logger.error(f"❌ Fehler beim Schreiben in InfluxDB: {e}")
            self.connected = False  # Reconnect beim nächsten Versuch
            return False
    
    def test_connection(self) -> bool:
        """InfluxDB Verbindung testen"""
        if not self.connected:
            return self.connect()
        
        try:
            health = self.client.health()
            is_healthy = health.status == "pass"
            logger.info(f"🔍 InfluxDB Health: {health.status}")
            return is_healthy
        except Exception as e:
            logger.error(f"❌ InfluxDB Health Check Fehler: {e}")
            return False
    
    def clean_old_data(self) -> bool:
        """Alte Daten mit falschen Feldtypen löschen"""
        if not self.connected:
            if not self.connect():
                return False
        
        try:
            # Lösche Daten mit den alten Feldnamen
            delete_api = self.client.delete_api()
            
            # Lösche alle Daten der letzten 7 Tage (um sicherzugehen)
            start = datetime.utcnow() - timedelta(days=7)
            stop = datetime.utcnow()
            
            delete_api.delete(start, stop, 
                            predicate='_measurement="temperature" OR _measurement="humidity"',
                            bucket=self.bucket,
                            org=self.org)
            
            logger.info("🧹 Alte InfluxDB Daten mit falschen Feldtypen gelöscht")
            return True
            
        except Exception as e:
            logger.error(f"❌ Fehler beim Löschen alter Daten: {e}")
            return False
    
    def close(self):
        """InfluxDB Verbindung schließen"""
        if self.client:
            try:
                self.client.close()
                logger.info("👋 InfluxDB Verbindung geschlossen")
            except:
                pass

class Pi5SensorInfluxDBLogger:
    """Pi 5 Sensor-Monitor mit InfluxDB Logging"""
    
    def __init__(self, influx_config: Optional[Dict[str, Any]] = None):
        if not SENSOR_MONITOR_AVAILABLE:
            raise ImportError("Sensor Monitor nicht verfügbar")
        
        # Sensor Monitor initialisieren
        self.sensor_monitor = Pi5SensorMonitor(
            high_performance=True,
            error_recovery=True,
            use_parallel_reading=True
        )
        
        # InfluxDB Integration
        if influx_config is None:
            influx_config = {}
        
        self.influx_db = Pi5InfluxDBIntegration(**influx_config)
        
        # Statistiken
        self.total_readings = 0
        self.successful_writes = 0
        self.failed_writes = 0
        
        logger.info("🚀 Pi 5 Sensor InfluxDB Logger initialisiert")
    
    def single_reading_to_influx(self) -> bool:
        """Einmalige Messung mit InfluxDB Speicherung"""
        try:
            # Hardware prüfen
            if not self.sensor_monitor.check_hardware():
                logger.error("❌ Hardware-Check fehlgeschlagen")
                return False
            
            # Sensor-Daten lesen
            logger.info("📊 Lese Sensor-Daten...")
            ds_temps, dht_temp, dht_humidity = self.sensor_monitor.parallel_reading()
            
            # In InfluxDB schreiben
            success = self.influx_db.write_sensor_data(ds_temps, dht_temp, dht_humidity)
            
            self.total_readings += 1
            if success:
                self.successful_writes += 1
            else:
                self.failed_writes += 1
            
            # Statistiken loggen
            logger.info(f"📈 Statistiken: {self.successful_writes}/{self.total_readings} erfolgreich")
            
            return success
            
        except Exception as e:
            logger.error(f"❌ Fehler bei Sensor-Reading: {e}")
            self.failed_writes += 1
            return False
    
    def continuous_monitoring_to_influx(self, interval: int = 30):
        """Kontinuierliche Überwachung mit InfluxDB Logging"""
        logger.info(f"🔄 Starte kontinuierliche InfluxDB Überwachung (Intervall: {interval}s)")
        
        try:
            reading_count = 0
            while True:
                reading_count += 1
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                logger.info(f"\n⏰ InfluxDB Messung #{reading_count} um {timestamp}")
                
                # Sensor-Daten lesen und speichern
                success = self.single_reading_to_influx()
                
                if success:
                    logger.info(f"✅ Daten erfolgreich in InfluxDB gespeichert")
                else:
                    logger.warning(f"⚠️  Daten konnten nicht gespeichert werden")
                
                # Erfolgsrate berechnen
                if self.total_readings > 0:
                    success_rate = (self.successful_writes / self.total_readings) * 100
                    logger.info(f"📊 Erfolgsrate: {success_rate:.1f}% ({self.successful_writes}/{self.total_readings})")
                
                logger.info(f"⏳ Warte {interval} Sekunden...")
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logger.info(f"\n👋 InfluxDB Überwachung beendet nach {reading_count} Messungen")
            logger.info(f"📊 Finale Statistiken: {self.successful_writes}/{self.total_readings} erfolgreich")
        except Exception as e:
            logger.error(f"❌ Fehler in kontinuierlicher Überwachung: {e}")
        finally:
            self.influx_db.close()

def main():
    """Hauptfunktion für InfluxDB Integration"""
    import sys
    
    print("🗄️  Pi 5 Sensor-Monitor → InfluxDB Integration")
    print("=" * 60)
    
    # Prüfe Abhängigkeiten
    if not INFLUXDB_AVAILABLE:
        print("❌ InfluxDB Client nicht installiert!")
        print("💡 Installiere mit: pip install influxdb-client")
        return 1
    
    if not SENSOR_MONITOR_AVAILABLE:
        print("❌ Sensor Monitor nicht verfügbar!")
        return 1
    
    # InfluxDB Logger erstellen
    try:
        logger_instance = Pi5SensorInfluxDBLogger()
        
        # Command-Line Parameter prüfen
        if len(sys.argv) > 1:
            mode = sys.argv[1].lower()
            if mode == "single":
                logger.info("🎯 Einmalige Messung → InfluxDB")
                success = logger_instance.single_reading_to_influx()
                return 0 if success else 1
            elif mode == "continuous":
                interval = int(sys.argv[2]) if len(sys.argv) > 2 else 30
                logger.info(f"🔄 Kontinuierliche Überwachung → InfluxDB ({interval}s)")
                logger_instance.continuous_monitoring_to_influx(interval)
                return 0
            elif mode == "test":
                logger.info("🔍 InfluxDB Verbindungstest")
                success = logger_instance.influx_db.test_connection()
                return 0 if success else 1
            elif mode == "clean":
                logger.info("🧹 Bereinige alte InfluxDB Daten...")
                success = logger_instance.influx_db.clean_old_data()
                if success:
                    logger.info("✅ Datenbereinigung abgeschlossen")
                    logger.info("💡 Starte jetzt neue Messungen mit korrekten Feldtypen")
                return 0 if success else 1
        
        # Interaktiver Modus
        print("\nInfluxDB Modi:")
        print("1. Einmalige Messung → InfluxDB")
        print("2. Kontinuierliche Überwachung (30s) → InfluxDB")
        print("3. Kontinuierliche Überwachung (60s) → InfluxDB")
        print("4. InfluxDB Verbindungstest")
        print("5. Alte Daten bereinigen (bei Feldtyp-Problemen)")
        
        choice = input("\nWahl (1-5): ").strip()
        
        if choice == "1":
            logger_instance.single_reading_to_influx()
        elif choice == "2":
            logger_instance.continuous_monitoring_to_influx(30)
        elif choice == "3":
            logger_instance.continuous_monitoring_to_influx(60)
        elif choice == "4":
            logger_instance.influx_db.test_connection()
        elif choice == "5":
            success = logger_instance.influx_db.clean_old_data()
            if success:
                logger.info("✅ Datenbereinigung abgeschlossen")
                logger.info("💡 Starte jetzt neue Messungen mit: python sensor_influxdb.py single")
        else:
            logger.error("❌ Ungültige Auswahl")
            return 1
            
    except Exception as e:
        logger.error(f"❌ Fehler: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
