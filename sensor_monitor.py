#!/usr/bin/env python3
"""
Sensor-Monitor für 6x DS18B20 + 1x DHT22
Speziell optimiert für Raspberry Pi 5
High-Performance Temperatur- und Feuchtigkeitsüberwachung
"""

import os
import time
import glob
import logging
import threading
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Pi 5 GPIO-Bibliotheken mit Priorität für lgpio
try:
    import lgpio
    PI5_LGPIO_AVAILABLE = True
    logger.info("✅ Pi 5 lgpio erfolgreich geladen")
except ImportError:
    PI5_LGPIO_AVAILABLE = False
    logger.warning("⚠️  lgpio nicht verfügbar - verwende Fallback")

# DHT22 Import mit Pi 5 Optimierungen
try:
    import board
    import adafruit_dht
    DHT22_AVAILABLE = True
    logger.info("✅ DHT22 CircuitPython für Pi 5 geladen")
except ImportError as e:
    logger.warning(f"⚠️  DHT22 nicht verfügbar: {e}")
    DHT22_AVAILABLE = False

# Zusätzliche Pi 5 GPIO-Bibliotheken
try:
    import gpiozero
    from gpiozero import Device
    from gpiozero.pins.lgpio import LGPIOFactory
    
    if PI5_LGPIO_AVAILABLE:
        # Pi 5 optimierte GPIO-Factory setzen
        Device.pin_factory = LGPIOFactory()
        logger.info("✅ Pi 5 LGPIOFactory aktiviert")
    GPIOZERO_AVAILABLE = True
except ImportError:
    GPIOZERO_AVAILABLE = False
    logger.warning("⚠️  gpiozero nicht verfügbar")

class Pi5DS18B20Manager:
    """Pi 5 optimierter Manager für DS18B20 Temperatursensoren"""
    
    def __init__(self, high_performance: bool = True):
        self.base_dir = '/sys/bus/w1/devices/'
        self.device_folders = []
        self.sensor_ids = []
        self.high_performance = high_performance
        self.read_stats = {'total_readings': 0, 'failed_readings': 0, 'avg_read_time': 0}
        self._discover_sensors()
    
    def _discover_sensors(self):
        """Findet alle angeschlossenen DS18B20 Sensoren mit Pi 5 Optimierungen"""
        try:
            # Alle 28-* Geräte finden (DS18B20 Familie)
            self.device_folders = glob.glob(self.base_dir + '28-*')
            self.sensor_ids = [folder.split('/')[-1] for folder in self.device_folders]
            
            logger.info(f"🔍 Pi 5: {len(self.sensor_ids)} DS18B20 Sensoren gefunden:")
            for i, sensor_id in enumerate(self.sensor_ids, 1):
                logger.info(f"   Sensor {i}: {sensor_id}")
                
            # Pi 5 Performance-Check
            if self.high_performance and len(self.sensor_ids) > 4:
                logger.info("⚡ Pi 5 High-Performance Modus für 6+ Sensoren aktiviert")
                
        except Exception as e:
            logger.error(f"❌ Pi 5 Sensor-Discovery Fehler: {e}")
            self.device_folders = []
            self.sensor_ids = []
    
    def read_temp_raw(self, device_file: str) -> List[str]:
        """Liest Roh-Daten von einem Sensor mit Pi 5 Optimierungen"""
        try:
            # Pi 5: Optimierte Datei-Operationen
            with open(device_file, 'r') as f:
                lines = f.readlines()
            return lines
        except Exception as e:
            logger.error(f"❌ Pi 5 Lesefehler {device_file}: {e}")
            return []
    
    def read_temp_single(self, device_folder: str, sensor_id: str) -> Tuple[str, Optional[float]]:
        """Liest Temperatur von einem DS18B20 Sensor (Pi 5 Thread-safe)"""
        start_time = time.time()
        device_file = device_folder + '/w1_slave'
        
        try:
            lines = self.read_temp_raw(device_file)
            
            if not lines:
                return sensor_id, None
                
            # Pi 5: Retry-Logic für bessere Stabilität
            retry_count = 0
            max_retries = 3 if self.high_performance else 1
            
            while lines[0].strip()[-3:] != 'YES' and retry_count < max_retries:
                time.sleep(0.1)  # Pi 5: Reduzierte Wartezeit
                lines = self.read_temp_raw(device_file)
                retry_count += 1
                if not lines:
                    return sensor_id, None
            
            if lines[0].strip()[-3:] != 'YES':
                logger.warning(f"⚠️  Pi 5: Sensor {sensor_id} CRC-Fehler nach {retry_count} Versuchen")
                return sensor_id, None
            
            # Temperatur extrahieren
            equals_pos = lines[1].find('t=')
            if equals_pos != -1:
                temp_string = lines[1][equals_pos+2:]
                temp_c = float(temp_string) / 1000.0
                
                # Pi 5 Performance-Statistiken
                read_time = (time.time() - start_time) * 1000  # ms
                self.read_stats['total_readings'] += 1
                self.read_stats['avg_read_time'] = (
                    (self.read_stats['avg_read_time'] * (self.read_stats['total_readings'] - 1) + read_time) /
                    self.read_stats['total_readings']
                )
                
                return sensor_id, temp_c
            
            return sensor_id, None
            
        except Exception as e:
            logger.error(f"❌ Pi 5 Sensor {sensor_id} Fehler: {e}")
            self.read_stats['failed_readings'] += 1
            return sensor_id, None
    
    def get_all_temperatures(self) -> Dict[str, float]:
        """Pi 5 Parallel-Reading aller DS18B20 Temperaturen"""
        temperatures = {}
        
        if not self.device_folders:
            return temperatures
        
        if self.high_performance and len(self.device_folders) > 2:
            # Pi 5 Parallel-Reading für bessere Performance
            return self._parallel_temperature_reading()
        else:
            # Sequenzielles Reading für wenige Sensoren
            return self._sequential_temperature_reading()
    
    def _parallel_temperature_reading(self) -> Dict[str, float]:
        """Pi 5 High-Performance paralleles Sensor-Reading"""
        temperatures = {}
        logger.debug("⚡ Pi 5 Parallel-Reading gestartet...")
        
        with ThreadPoolExecutor(max_workers=min(6, len(self.device_folders))) as executor:
            # Alle Sensoren parallel starten
            future_to_sensor = {
                executor.submit(self.read_temp_single, folder, self.sensor_ids[i]): (i+1, self.sensor_ids[i])
                for i, folder in enumerate(self.device_folders)
            }
            
            # Ergebnisse sammeln
            for future in as_completed(future_to_sensor):
                sensor_num, sensor_id = future_to_sensor[future]
                try:
                    returned_id, temp = future.result(timeout=2.0)  # Pi 5: 2s Timeout
                    
                    if temp is not None:
                        temperatures[f"DS18B20_{sensor_num}"] = temp
                        logger.info(f"🌡️  Pi 5 Sensor {sensor_num} ({sensor_id}): {temp:.2f}°C")
                    else:
                        logger.warning(f"⚠️  Pi 5 Sensor {sensor_num} ({sensor_id}): Lesefehler")
                        temperatures[f"DS18B20_{sensor_num}"] = None
                        
                except Exception as e:
                    logger.error(f"❌ Pi 5 Parallel-Reading Fehler Sensor {sensor_num}: {e}")
                    temperatures[f"DS18B20_{sensor_num}"] = None
        
        return temperatures
    
    def _sequential_temperature_reading(self) -> Dict[str, float]:
        """Sequenzielles Reading für Pi 5 (Fallback)"""
        temperatures = {}
        
        for i, device_folder in enumerate(self.device_folders, 1):
            sensor_id = self.sensor_ids[i-1]
            _, temp = self.read_temp_single(device_folder, sensor_id)
            
            if temp is not None:
                temperatures[f"DS18B20_{i}"] = temp
                logger.info(f"🌡️  Pi 5 Sensor {i} ({sensor_id}): {temp:.2f}°C")
            else:
                logger.warning(f"⚠️  Pi 5 Sensor {i} ({sensor_id}): Lesefehler")
                temperatures[f"DS18B20_{i}"] = None
        
        return temperatures
    
    def get_performance_stats(self) -> Dict[str, float]:
        """Pi 5 Performance-Statistiken"""
        return {
            'total_readings': self.read_stats['total_readings'],
            'failed_readings': self.read_stats['failed_readings'],
            'success_rate': ((self.read_stats['total_readings'] - self.read_stats['failed_readings']) / 
                           max(1, self.read_stats['total_readings'])) * 100,
            'avg_read_time': self.read_stats['avg_read_time']
        }

class Pi5DHT22Sensor:
    """Pi 5 optimierter DHT22 Temperatur- und Feuchtigkeitssensor"""
    
    def __init__(self, pin: int = 18, use_pi5_optimizations: bool = True):
        self.pin = pin
        self.sensor = None
        self.available = DHT22_AVAILABLE
        self.use_pi5_optimizations = use_pi5_optimizations
        self.read_attempts = 0
        self.successful_reads = 0
        
        if self.available:
            try:
                # Pi 5 GPIO Pin konfigurieren
                gpio_pin = getattr(board, f'D{pin}')
                
                # Pi 5 Optimierungen: use_pulseio=False für bessere Performance
                if self.use_pi5_optimizations:
                    self.sensor = adafruit_dht.DHT22(gpio_pin, use_pulseio=False)
                    logger.info(f"✅ Pi 5 DHT22 auf GPIO {pin} (optimiert) initialisiert")
                else:
                    self.sensor = adafruit_dht.DHT22(gpio_pin)
                    logger.info(f"✅ Pi 5 DHT22 auf GPIO {pin} (standard) initialisiert")
                    
            except Exception as e:
                logger.error(f"❌ Pi 5 DHT22 Initialisierung fehlgeschlagen: {e}")
                self.available = False
    
    def read_data(self, max_retries: int = 3) -> Tuple[Optional[float], Optional[float]]:
        """Liest Temperatur und Luftfeuchtigkeit mit Pi 5 Optimierungen"""
        if not self.available or not self.sensor:
            return None, None
        
        self.read_attempts += 1
        
        for attempt in range(max_retries):
            try:
                temperature = self.sensor.temperature
                humidity = self.sensor.humidity
                
                if temperature is not None and humidity is not None:
                    self.successful_reads += 1
                    logger.info(f"🌡️  Pi 5 DHT22: {temperature:.1f}°C, 💧 {humidity:.1f}%")
                    return temperature, humidity
                else:
                    if attempt < max_retries - 1:
                        logger.debug(f"🔄 Pi 5 DHT22 Retry {attempt + 1}/{max_retries}")
                        time.sleep(0.5)  # Pi 5: Kurze Wartezeit zwischen Versuchen
                    
            except RuntimeError as e:
                # DHT22 kann zeitweise Lesefehler haben - normal bei Pi 5
                if attempt < max_retries - 1:
                    logger.debug(f"🔄 Pi 5 DHT22 RuntimeError Retry {attempt + 1}: {e}")
                    time.sleep(1.0)
                else:
                    logger.warning(f"⚠️  Pi 5 DHT22 Lesefehler nach {max_retries} Versuchen: {e}")
                    
            except Exception as e:
                logger.error(f"❌ Pi 5 DHT22 unerwarteter Fehler: {e}")
                break
        
        return None, None
    
    def get_success_rate(self) -> float:
        """DHT22 Erfolgsrate für Pi 5"""
        if self.read_attempts == 0:
            return 0.0
        return (self.successful_reads / self.read_attempts) * 100

class Pi5SensorMonitor:
    """Pi 5 optimierte Hauptklasse für Sensor-Überwachung"""
    
    def __init__(self, high_performance: bool = True, error_recovery: bool = True, parallel_reading: bool = True):
        self.high_performance = high_performance
        self.error_recovery = error_recovery
        self.parallel_reading = parallel_reading
        
        logger.info(f"🚀 Pi 5 Sensor-Monitor initialisiert:")
        logger.info(f"   ⚡ High-Performance: {high_performance}")
        logger.info(f"   🔄 Error-Recovery: {error_recovery}")
        logger.info(f"   🔀 Parallel-Reading: {parallel_reading}")
        
        self.ds18b20_manager = Pi5DS18B20Manager(high_performance=high_performance)
        self.dht22_sensor = Pi5DHT22Sensor(pin=18, use_pi5_optimizations=True)
        
    def check_hardware(self) -> bool:
        """Prüft Hardware-Verfügbarkeit mit Pi 5 spezifischen Tests"""
        logger.info("🔧 Pi 5 Hardware-Check wird durchgeführt...")
        
        # Pi 5 System-Info
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpu_info = f.read()
                if 'Raspberry Pi 5' in cpu_info:
                    logger.info("✅ Raspberry Pi 5 bestätigt")
                else:
                    logger.warning("⚠️  Läuft nicht auf Raspberry Pi 5")
        except:
            pass
        
        # 1-Wire Interface prüfen
        if not os.path.exists('/sys/bus/w1/devices/'):
            logger.error("❌ 1-Wire Interface nicht aktiviert!")
            logger.info("💡 Pi 5 Lösung: sudo nano /boot/firmware/config.txt")
            logger.info("💡 Zeile hinzufügen: dtoverlay=w1-gpio,gpiopin=4")
            logger.info("💡 Dann: sudo reboot")
            return False
        
        # DS18B20 Sensoren prüfen
        if len(self.ds18b20_manager.sensor_ids) == 0:
            logger.error("❌ Keine DS18B20 Sensoren gefunden!")
            logger.info("💡 Pi 5 Verdrahtung prüfen:")
            logger.info("💡 - VDD → 3.3V (Pin 1)")
            logger.info("💡 - GND → GND (Pin 6)")
            logger.info("💡 - Data → GPIO 4 (Pin 7) + 4.7kΩ Pull-up")
            logger.info("💡 - Qualitäts-Kabel verwenden (Pi 5 ist empfindlicher)")
            return False
        
        expected_sensors = 6
        found_sensors = len(self.ds18b20_manager.sensor_ids)
        
        if found_sensors < expected_sensors:
            logger.warning(f"⚠️  Pi 5: Nur {found_sensors} von {expected_sensors} DS18B20 Sensoren gefunden")
        else:
            logger.info(f"✅ Pi 5: Alle {found_sensors} DS18B20 Sensoren gefunden")
        
        # DHT22 Status
        if self.dht22_sensor.available:
            logger.info("✅ Pi 5 DHT22 Sensor verfügbar")
        else:
            logger.warning("⚠️  Pi 5 DHT22 Sensor nicht verfügbar")
            logger.info("💡 Pi 5 DHT22 Troubleshooting:")
            logger.info("💡 - pip install lgpio --upgrade")
            logger.info("💡 - Verkabelung: GPIO 18 + 10kΩ Pull-up")
        
        # Pi 5 GPIO-Check
        if PI5_LGPIO_AVAILABLE:
            logger.info("✅ Pi 5 lgpio verfügbar")
        else:
            logger.warning("⚠️  Pi 5 lgpio nicht verfügbar - installiere: pip install lgpio")
        
        return True
    
    def single_reading(self):
        """Einmalige Messung aller Sensoren mit Pi 5 Optimierungen"""
        logger.info("📊 Pi 5 Einmalige Sensor-Messung...")
        start_time = time.time()
        
        # DS18B20 Temperaturen
        ds_temps = self.ds18b20_manager.get_all_temperatures()
        
        # DHT22 Daten
        dht_temp, dht_humidity = self.dht22_sensor.read_data()
        
        total_time = (time.time() - start_time) * 1000  # ms
        
        # Pi 5 Messergebnisse
        logger.info("📋 Pi 5 Messergebnisse:")
        logger.info("-" * 50)
        
        for sensor, temp in ds_temps.items():
            if temp is not None:
                logger.info(f"{sensor:12}: {temp:6.2f}°C")
            else:
                logger.info(f"{sensor:12}: FEHLER")
        
        if dht_temp is not None and dht_humidity is not None:
            logger.info(f"{'DHT22 Temp':12}: {dht_temp:6.1f}°C")
            logger.info(f"{'DHT22 Hum':12}: {dht_humidity:6.1f}%")
        else:
            logger.info(f"{'DHT22':12}: FEHLER")
        
        logger.info("-" * 50)
        logger.info(f"⚡ Pi 5 Gesamt-Lesezeit: {total_time:.1f}ms")
        
        # Pi 5 Performance-Statistiken
        if self.high_performance:
            stats = self.ds18b20_manager.get_performance_stats()
            logger.info(f"📊 Pi 5 DS18B20 Stats:")
            logger.info(f"   Erfolgsrate: {stats['success_rate']:.1f}%")
            logger.info(f"   Ø Lesezeit: {stats['avg_read_time']:.1f}ms")
            
            dht_success = self.dht22_sensor.get_success_rate()
            logger.info(f"📊 Pi 5 DHT22 Erfolgsrate: {dht_success:.1f}%")
        
        return ds_temps, dht_temp, dht_humidity
    
    def parallel_reading(self):
        """Pi 5 High-Performance paralleles Reading"""
        if not self.parallel_reading:
            return self.single_reading()
        
        logger.info("⚡ Pi 5 Parallel-Reading gestartet...")
        return self.single_reading()  # Bereits parallelisiert in Pi5DS18B20Manager
    
    def continuous_monitoring(self, interval: int = 30):
        """Kontinuierliche Überwachung mit Pi 5 Optimierungen"""
        logger.info(f"🔄 Pi 5 Kontinuierliche Überwachung startet (Intervall: {interval}s)")
        logger.info("Drücke Ctrl+C zum Beenden")
        
        try:
            reading_count = 0
            while True:
                reading_count += 1
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                logger.info(f"\n⏰ Pi 5 Messung #{reading_count} um {timestamp}")
                
                if self.parallel_reading:
                    self.parallel_reading()
                else:
                    self.single_reading()
                
                logger.info(f"⏳ Pi 5 wartet {interval} Sekunden...")
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logger.info(f"\n👋 Pi 5 Überwachung beendet nach {reading_count} Messungen")
    
    def get_performance_stats(self) -> Dict[str, any]:
        """Pi 5 Gesamt-Performance-Statistiken"""
        ds_stats = self.ds18b20_manager.get_performance_stats()
        dht_success = self.dht22_sensor.get_success_rate()
        
        return {
            'ds18b20_stats': ds_stats,
            'dht22_success_rate': dht_success,
            'pi5_features': {
                'high_performance': self.high_performance,
                'parallel_reading': self.parallel_reading,
                'error_recovery': self.error_recovery,
                'lgpio_available': PI5_LGPIO_AVAILABLE
            }
        }

def main():
    """Hauptfunktion für Pi 5 mit Command-Line Parameter Support"""
    import sys
    
    print("🌡️  Raspberry Pi 5 Sensor-Monitor")
    print("6x DS18B20 + 1x DHT22 (Pi 5 optimiert)")
    print("=" * 55)
    
    monitor = Pi5SensorMonitor(
        high_performance=True,
        error_recovery=True,
        parallel_reading=True
    )
    
    # Hardware-Check
    if not monitor.check_hardware():
        logger.error("❌ Pi 5 Hardware-Check fehlgeschlagen!")
        return 1
    
    # Command-Line Parameter prüfen
    if len(sys.argv) > 1:
        mode = sys.argv[1].lower()
        if mode == "single":
            logger.info("🎯 Command-Line Modus: Einmalige Messung")
            monitor.single_reading()
            return 0
        elif mode == "continuous":
            interval = int(sys.argv[2]) if len(sys.argv) > 2 else 30
            logger.info(f"🔄 Command-Line Modus: Kontinuierliche Überwachung ({interval}s)")
            monitor.continuous_monitoring(interval)
            return 0
        elif mode == "parallel":
            logger.info("⚡ Command-Line Modus: High-Performance Parallel-Reading")
            monitor.parallel_reading()
            return 0
    
    # Interaktiver Modus wenn keine Parameter
    print("\nPi 5 Optionen:")
    print("1. Einmalige Messung")
    print("2. Kontinuierliche Überwachung (30s) - empfohlen für Pi 5")
    print("3. Kontinuierliche Überwachung (60s)")
    print("4. Kontinuierliche Überwachung (300s)")
    print("5. Pi 5 High-Performance Parallel-Reading")
    
    try:
        choice = input("\nWahl (1-5): ").strip()
        
        if choice == "1":
            monitor.single_reading()
        elif choice == "2":
            monitor.continuous_monitoring(30)
        elif choice == "3":
            monitor.continuous_monitoring(60)
        elif choice == "4":
            monitor.continuous_monitoring(300)
        elif choice == "5":
            logger.info("⚡ Pi 5 High-Performance Modus aktiviert")
            monitor.parallel_reading()
        else:
            logger.error("❌ Ungültige Auswahl")
            return 1
            
    except KeyboardInterrupt:
        logger.info("\n👋 Pi 5 Programm beendet")
    
    return 0

if __name__ == "__main__":
    exit(main())
