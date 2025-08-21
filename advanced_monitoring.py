#!/usr/bin/env python3
"""
Advanced Monitoring und Alerting für Pi 5 Sensor Monitor
Umfasst System-Health, Performance-Metriken und Smart Alerts
"""

import logging
import time
import json
import smtplib
import psutil
import configparser
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
from pathlib import Path

# Prometheus Metrics (optional)
try:
    from prometheus_client import Gauge, Counter, Histogram, start_http_server
    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AlertManager:
    """Smart Alert Management mit Cooldown und Priorisierung"""
    
    def __init__(self, config_path: str = "config.ini"):
        self.config = configparser.ConfigParser()
        self.config.read(config_path)
        
        self.alert_history = {}
        self.cooldown_period = self.config.getint('alerts', 'alert_cooldown', fallback=300)
        
        # E-Mail Konfiguration (optional)
        self.smtp_enabled = self.config.getboolean('alerts', 'smtp_enabled', fallback=False)
        if self.smtp_enabled:
            self.smtp_server = self.config.get('alerts', 'smtp_server', fallback='smtp.gmail.com')
            self.smtp_port = self.config.getint('alerts', 'smtp_port', fallback=587)
            self.smtp_user = self.config.get('alerts', 'smtp_user', fallback='')
            self.smtp_password = self.config.get('alerts', 'smtp_password', fallback='')
            self.alert_recipients = self.config.get('alerts', 'recipients', fallback='').split(',')
    
    def check_alert_cooldown(self, alert_type: str) -> bool:
        """Prüft ob Alert-Cooldown abgelaufen ist"""
        if alert_type not in self.alert_history:
            return True
        
        last_alert = self.alert_history[alert_type]
        time_diff = datetime.now() - last_alert
        return time_diff.total_seconds() > self.cooldown_period
    
    def send_alert(self, alert_type: str, message: str, priority: str = "medium"):
        """Sendet Alert mit Cooldown-Management"""
        if not self.check_alert_cooldown(alert_type):
            logger.debug(f"Alert {alert_type} im Cooldown - übersprungen")
            return
        
        self.alert_history[alert_type] = datetime.now()
        
        # Console Alert
        priority_emoji = {"low": "ℹ️", "medium": "⚠️", "high": "🚨", "critical": "💥"}
        emoji = priority_emoji.get(priority, "⚠️")
        logger.warning(f"{emoji} ALERT [{priority.upper()}] {alert_type}: {message}")
        
        # E-Mail Alert (falls konfiguriert)
        if self.smtp_enabled and priority in ["high", "critical"]:
            self._send_email_alert(alert_type, message, priority)
    
    def _send_email_alert(self, alert_type: str, message: str, priority: str):
        """Sendet E-Mail Alert"""
        try:
            subject = f"🚨 Pi5 Sensor Alert [{priority.upper()}] - {alert_type}"
            
            msg = MimeMultipart()
            msg['From'] = self.smtp_user
            msg['Subject'] = subject
            
            body = f"""
            Pi 5 Sensor Monitor Alert
            ========================
            
            Alert Type: {alert_type}
            Priority: {priority.upper()}
            Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            
            Message:
            {message}
            
            System: Raspberry Pi 5 Sensor Monitor
            """
            
            msg.attach(MimeText(body, 'plain'))
            
            server = smtplib.SMTP(self.smtp_server, self.smtp_port)
            server.starttls()
            server.login(self.smtp_user, self.smtp_password)
            
            for recipient in self.alert_recipients:
                if recipient.strip():
                    msg['To'] = recipient.strip()
                    server.send_message(msg)
            
            server.quit()
            logger.info(f"E-Mail Alert gesendet: {alert_type}")
            
        except Exception as e:
            logger.error(f"E-Mail Alert Fehler: {e}")

class SystemHealthMonitor:
    """System Health Monitoring für Raspberry Pi 5"""
    
    def __init__(self, alert_manager: AlertManager):
        self.alert_manager = alert_manager
        self.config = alert_manager.config
        
        # Prometheus Metrics (optional)
        if PROMETHEUS_AVAILABLE:
            self.cpu_usage = Gauge('pi5_cpu_usage_percent', 'CPU Usage Percentage')
            self.memory_usage = Gauge('pi5_memory_usage_percent', 'Memory Usage Percentage')
            self.disk_usage = Gauge('pi5_disk_usage_percent', 'Disk Usage Percentage')
            self.cpu_temperature = Gauge('pi5_cpu_temperature_celsius', 'CPU Temperature')
            self.sensor_readings = Gauge('pi5_sensor_readings_total', 'Total Sensor Readings')
            self.sensor_errors = Counter('pi5_sensor_errors_total', 'Total Sensor Errors')
    
    def check_system_health(self) -> Dict[str, Any]:
        """Überwacht System-Gesundheit"""
        health_data = {}
        
        # CPU Usage
        cpu_percent = psutil.cpu_percent(interval=1)
        health_data['cpu_usage'] = cpu_percent
        
        cpu_threshold = self.config.getfloat('health', 'system_alert_cpu', fallback=80.0)
        if cpu_percent > cpu_threshold:
            self.alert_manager.send_alert(
                'high_cpu_usage',
                f'CPU-Auslastung bei {cpu_percent:.1f}% (Schwelle: {cpu_threshold}%)',
                'medium'
            )
        
        # Memory Usage
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        health_data['memory_usage'] = memory_percent
        
        memory_threshold = self.config.getfloat('health', 'system_alert_memory', fallback=80.0)
        if memory_percent > memory_threshold:
            self.alert_manager.send_alert(
                'high_memory_usage',
                f'Speicher-Auslastung bei {memory_percent:.1f}% (Schwelle: {memory_threshold}%)',
                'medium'
            )
        
        # Disk Usage
        disk = psutil.disk_usage('/')
        disk_percent = (disk.used / disk.total) * 100
        health_data['disk_usage'] = disk_percent
        
        disk_threshold = self.config.getfloat('health', 'system_alert_disk', fallback=90.0)
        if disk_percent > disk_threshold:
            self.alert_manager.send_alert(
                'high_disk_usage',
                f'Festplatten-Auslastung bei {disk_percent:.1f}% (Schwelle: {disk_threshold}%)',
                'high'
            )
        
        # CPU Temperature (Pi 5 spezifisch)
        try:
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                cpu_temp = int(f.read()) / 1000.0
                health_data['cpu_temperature'] = cpu_temp
                
                if cpu_temp > 70.0:  # Pi 5 Throttling bei ~80°C
                    self.alert_manager.send_alert(
                        'high_cpu_temperature',
                        f'CPU-Temperatur bei {cpu_temp:.1f}°C - Throttling-Gefahr!',
                        'high'
                    )
        except:
            health_data['cpu_temperature'] = None
        
        # Prometheus Metrics aktualisieren
        if PROMETHEUS_AVAILABLE:
            self.cpu_usage.set(cpu_percent)
            self.memory_usage.set(memory_percent)
            self.disk_usage.set(disk_percent)
            if health_data['cpu_temperature']:
                self.cpu_temperature.set(health_data['cpu_temperature'])
        
        return health_data

class SensorHealthMonitor:
    """Spezielles Health Monitoring für Sensoren"""
    
    def __init__(self, alert_manager: AlertManager):
        self.alert_manager = alert_manager
        self.config = alert_manager.config
        self.sensor_history = {}
        self.last_readings = {}
    
    def check_sensor_health(self, sensor_data: Dict[str, float]) -> Dict[str, Any]:
        """Überwacht Sensor-Gesundheit"""
        health_info = {
            'total_sensors': len(sensor_data),
            'active_sensors': 0,
            'failed_sensors': [],
            'temperature_alerts': [],
            'humidity_alerts': []
        }
        
        current_time = datetime.now()
        
        for sensor_name, value in sensor_data.items():
            if value is not None:
                health_info['active_sensors'] += 1
                self.last_readings[sensor_name] = current_time
                
                # Temperatur-Alerts
                if 'DS18B20' in sensor_name or 'DHT22' in sensor_name:
                    self._check_temperature_alerts(sensor_name, value, health_info)
                
                # Luftfeuchtigkeit-Alerts
                if 'humidity' in sensor_name.lower():
                    self._check_humidity_alerts(sensor_name, value, health_info)
            else:
                health_info['failed_sensors'].append(sensor_name)
        
        # Offline Sensoren prüfen
        timeout = self.config.getint('alerts', 'sensor_offline_timeout', fallback=120)
        for sensor_name, last_time in self.last_readings.items():
            if (current_time - last_time).total_seconds() > timeout:
                self.alert_manager.send_alert(
                    f'sensor_offline_{sensor_name}',
                    f'Sensor {sensor_name} ist seit {timeout}s offline',
                    'high'
                )
        
        return health_info
    
    def _check_temperature_alerts(self, sensor_name: str, value: float, health_info: Dict):
        """Prüft Temperatur-Schwellwerte"""
        temp_high = self.config.getfloat('alerts', 'temperature_high', fallback=30.0)
        temp_low = self.config.getfloat('alerts', 'temperature_low', fallback=10.0)
        
        if value > temp_high:
            alert_msg = f'{sensor_name}: {value:.1f}°C > {temp_high}°C'
            health_info['temperature_alerts'].append(alert_msg)
            self.alert_manager.send_alert(
                f'temperature_high_{sensor_name}',
                alert_msg,
                'medium'
            )
        
        if value < temp_low:
            alert_msg = f'{sensor_name}: {value:.1f}°C < {temp_low}°C'
            health_info['temperature_alerts'].append(alert_msg)
            self.alert_manager.send_alert(
                f'temperature_low_{sensor_name}',
                alert_msg,
                'medium'
            )
    
    def _check_humidity_alerts(self, sensor_name: str, value: float, health_info: Dict):
        """Prüft Luftfeuchtigkeit-Schwellwerte"""
        humidity_high = self.config.getfloat('alerts', 'humidity_high', fallback=80.0)
        humidity_low = self.config.getfloat('alerts', 'humidity_low', fallback=30.0)
        
        if value > humidity_high:
            alert_msg = f'{sensor_name}: {value:.1f}% > {humidity_high}%'
            health_info['humidity_alerts'].append(alert_msg)
            self.alert_manager.send_alert(
                f'humidity_high_{sensor_name}',
                alert_msg,
                'medium'
            )
        
        if value < humidity_low:
            alert_msg = f'{sensor_name}: {value:.1f}% < {humidity_low}%'
            health_info['humidity_alerts'].append(alert_msg)
            self.alert_manager.send_alert(
                f'humidity_low_{sensor_name}',
                alert_msg,
                'low'
            )

class AdvancedMonitoringService:
    """Haupt-Monitoring-Service"""
    
    def __init__(self, config_path: str = "config.ini"):
        self.alert_manager = AlertManager(config_path)
        self.system_monitor = SystemHealthMonitor(self.alert_manager)
        self.sensor_monitor = SensorHealthMonitor(self.alert_manager)
        
        # Prometheus Server starten (optional)
        if PROMETHEUS_AVAILABLE:
            try:
                start_http_server(8000)
                logger.info("🔍 Prometheus Metrics Server gestartet auf Port 8000")
            except Exception as e:
                logger.warning(f"Prometheus Server Start fehlgeschlagen: {e}")
    
    def run_monitoring_cycle(self, sensor_data: Dict[str, float]) -> Dict[str, Any]:
        """Führt kompletten Monitoring-Zyklus aus"""
        monitoring_results = {
            'timestamp': datetime.now().isoformat(),
            'system_health': self.system_monitor.check_system_health(),
            'sensor_health': self.sensor_monitor.check_sensor_health(sensor_data)
        }
        
        # Summary Log
        system = monitoring_results['system_health']
        sensors = monitoring_results['sensor_health']
        
        logger.info(f"📊 Monitoring Summary:")
        logger.info(f"   💻 System: CPU {system['cpu_usage']:.1f}%, "
                   f"RAM {system['memory_usage']:.1f}%, "
                   f"Disk {system['disk_usage']:.1f}%")
        if system.get('cpu_temperature'):
            logger.info(f"   🌡️ CPU Temp: {system['cpu_temperature']:.1f}°C")
        logger.info(f"   📡 Sensoren: {sensors['active_sensors']}/{sensors['total_sensors']} aktiv")
        
        if sensors['failed_sensors']:
            logger.warning(f"   ❌ Fehlerhafte Sensoren: {', '.join(sensors['failed_sensors'])}")
        
        if sensors['temperature_alerts']:
            logger.warning(f"   🌡️ Temperatur-Alerts: {len(sensors['temperature_alerts'])}")
        
        if sensors['humidity_alerts']:
            logger.warning(f"   💧 Luftfeuchtigkeit-Alerts: {len(sensors['humidity_alerts'])}")
        
        return monitoring_results

def main():
    """Test des Monitoring-Systems"""
    print("🔍 Advanced Monitoring Service - Test")
    print("=" * 50)
    
    monitoring = AdvancedMonitoringService()
    
    # Test-Sensor-Daten
    test_sensor_data = {
        'DS18B20_1': 21.5,
        'DS18B20_2': 22.0,
        'DS18B20_3': None,  # Defekter Sensor
        'DS18B20_4': 35.0,  # Zu heiß
        'DS18B20_5': 19.5,
        'DS18B20_6': 20.0,
        'DHT22_temp': 23.0,
        'DHT22_humidity': 85.0  # Zu feucht
    }
    
    # Monitoring-Zyklus ausführen
    results = monitoring.run_monitoring_cycle(test_sensor_data)
    
    print("\n📊 Monitoring-Ergebnisse:")
    print(json.dumps(results, indent=2, default=str))

if __name__ == "__main__":
    main()
