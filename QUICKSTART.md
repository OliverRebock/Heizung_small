# 🚀 Quick Start

Das **Heizung_small** Repository enthält ein Raspberry Pi 5 optimiertes Sensor-Monitoring-System.

## ⚡ Schnellinstallation

```bash
# Repository klonen
git clone https://github.com/OliverRebock/Heizung_small.git
cd Heizung_small

# Automatische Installation auf Raspberry Pi 5
chmod +x install_sensors.sh
./install_sensors.sh

# Nach Neustart
sudo reboot
cd ~/sensor-monitor-pi5
./test_sensors.sh
```

## 📋 Was ist enthalten

- `sensor_monitor.py` - Pi 5 optimiertes Haupt-Script
- `install_sensors.sh` - Automatische Installation
- `sensor_installation_guide.md` - Komplette Anleitung
- `test_sensors_fixed.py` - Umfassendes Test-Script
- `README.md` - Projekt-Dokumentation

## 🔧 Hardware

- 6x DS18B20 Temperatursensoren (1-Wire Bus)
- 1x DHT22 Temperatur/Feuchtigkeit-Sensor
- Raspberry Pi 5
- Pull-up Widerstände (4.7kΩ + 10kΩ)

## 📊 Features

✅ Parallel-Reading aller Sensoren  
✅ Pi 5 lgpio Unterstützung  
✅ High-Performance Modus  
✅ Automatische Fehlerbehandlung  
✅ Performance-Statistiken  

---

**Optimiert für Raspberry Pi 5 🍓**
