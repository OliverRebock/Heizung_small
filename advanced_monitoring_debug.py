#!/usr/bin/env python3
"""
Advanced Monitoring Debug Version
Robuste Version mit detailliertem Error-Handling
"""

import logging
import sys
import os
import time
from datetime import datetime

# Logging für Debug
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/home/pi/sensor-monitor-pi5/advanced_monitoring_debug.log')
    ]
)
logger = logging.getLogger(__name__)

def main():
    """Debug-Version des Advanced Monitoring"""
    logger.info("🚀 Advanced Monitoring Debug gestartet")
    
    try:
        # 1. Python Environment prüfen
        logger.info(f"🐍 Python Version: {sys.version}")
        logger.info(f"📁 Working Directory: {os.getcwd()}")
        logger.info(f"📄 Python Path: {sys.executable}")
        
        # 2. Verzeichnis prüfen
        expected_dir = "/home/pi/sensor-monitor-pi5"
        if not os.path.exists(expected_dir):
            logger.error(f"❌ Verzeichnis nicht gefunden: {expected_dir}")
            return 1
            
        os.chdir(expected_dir)
        logger.info(f"✅ Verzeichnis gewechselt: {os.getcwd()}")
        
        # 3. Config-Datei prüfen
        config_file = "config.ini"
        if not os.path.exists(config_file):
            logger.error(f"❌ Config-Datei nicht gefunden: {config_file}")
            logger.info("💡 Erstelle Minimal-Config...")
            create_minimal_config()
        else:
            logger.info(f"✅ Config-Datei gefunden: {config_file}")
        
        # 4. Abhängigkeiten prüfen
        logger.info("📦 Prüfe Python-Module...")
        missing_modules = []
        
        try:
            import configparser
            logger.info("✅ configparser verfügbar")
        except ImportError:
            missing_modules.append("configparser")
            
        try:
            import psutil
            logger.info("✅ psutil verfügbar")
        except ImportError:
            missing_modules.append("psutil")
            
        try:
            from sensor_monitor import Pi5SensorMonitor
            logger.info("✅ sensor_monitor verfügbar")
        except ImportError as e:
            logger.warning(f"⚠️ sensor_monitor nicht verfügbar: {e}")
            
        if missing_modules:
            logger.error(f"❌ Fehlende Module: {missing_modules}")
            logger.info("💡 Installiere mit: pip install " + " ".join(missing_modules))
            return 1
        
        # 5. Hauptschleife (vereinfacht)
        logger.info("🔄 Starte Monitoring-Schleife...")
        
        monitoring_count = 0
        while True:
            monitoring_count += 1
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            logger.info(f"📊 Monitoring-Zyklus #{monitoring_count} - {timestamp}")
            
            # System-Info sammeln
            try:
                cpu_percent = psutil.cpu_percent(interval=1)
                memory = psutil.virtual_memory()
                disk = psutil.disk_usage('/')
                
                logger.info(f"  💻 CPU: {cpu_percent:.1f}%")
                logger.info(f"  🧠 RAM: {memory.percent:.1f}% ({memory.used/1024/1024/1024:.1f}GB/{memory.total/1024/1024/1024:.1f}GB)")
                logger.info(f"  💾 Disk: {disk.percent:.1f}% ({disk.used/1024/1024/1024:.1f}GB/{disk.total/1024/1024/1024:.1f}GB)")
                
                # Sensor-Daten versuchen
                try:
                    logger.info("🌡️ Versuche Sensor-Daten zu lesen...")
                    # Hier würde normalerweise der Sensor-Code stehen
                    logger.info("✅ Sensor-Simulation erfolgreich")
                except Exception as e:
                    logger.warning(f"⚠️ Sensor-Fehler: {e}")
                    
            except Exception as e:
                logger.error(f"❌ System-Info Fehler: {e}")
            
            # Warte bis zum nächsten Zyklus
            time.sleep(30)
            
    except KeyboardInterrupt:
        logger.info("👋 Monitoring durch Benutzer beendet")
        return 0
    except Exception as e:
        logger.error(f"💥 Unerwarteter Fehler: {e}")
        logger.exception("Vollständiger Traceback:")
        return 1

def create_minimal_config():
    """Erstellt eine minimale config.ini falls sie fehlt"""
    config_content = """# Minimal Config für Debug
[hardware]
ds18b20_count = 8
ds18b20_gpio_pin = 4
dht22_gpio_pin = 18

[monitoring]
check_interval = 30
enable_logging = true
log_level = "INFO"

[alerts]
temperature_high = 30.0
temperature_low = 10.0
alert_cooldown = 300
smtp_enabled = false
"""
    
    try:
        with open("config.ini", "w") as f:
            f.write(config_content)
        logger.info("✅ Minimal-Config erstellt")
    except Exception as e:
        logger.error(f"❌ Config-Erstellung fehlgeschlagen: {e}")

if __name__ == "__main__":
    exit_code = main()
    logger.info(f"🏁 Advanced Monitoring beendet mit Code: {exit_code}")
    sys.exit(exit_code)
