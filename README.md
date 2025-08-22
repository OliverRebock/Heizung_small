# 🌡️ Heizung Small - Pi 5 Sensor Monitor

Ein professionelles IoT-Monitoring-System für Raspberry Pi 5 mit 6x DS18B20 Temperatursensoren und 1x DHT22 Sensor.

## 🚀 Features

- ⚡ **Pi 5 optimiert** - Nutzt lgpio für beste Performance
- 🔄 **Parallel-Processing** - Simultanes Auslesen aller Sensoren
- 📊 **Grafana Dashboards** - Professionelle Visualisierung
- 🗄️ **InfluxDB Integration** - Zeitreihen-Datenbank
- 🐳 **Docker Compose** - Einfache Bereitstellung
- 📱 **Mobile optimiert** - Responsive Dashboards
- 🚨 **Alarm-System** - Temperatur-Überwachung
- 🔧 **Auto-Installation** - Ein-Klick Setup

## 📊 Hardware

| Komponente | Anzahl | GPIO | Beschreibung |
|------------|--------|------|--------------|
| DS18B20 | 8x | GPIO 4 | Temperatursensoren (1-Wire) |
| DHT22 | 1x | GPIO 18 | Temperatur/Luftfeuchtigkeit |
| Pull-up | 1x | 4.7kΩ | DS18B20 Bus |
| Pull-up | 1x | 10kΩ | DHT22 |

### 🏷️ Standard Sensor-Namen
- **DS18B20_1** → Vorlauf Heizkreis 1
- **DS18B20_2** → Rücklauf Heizkreis 1  
- **DS18B20_3** → Vorlauf Heizkreis 2
- **DS18B20_4** → Rücklauf Heizkreis 2
- **DS18B20_5** → Warmwasser Speicher
- **DS18B20_6** → Außentemperatur
- **DS18B20_7** → Heizraum Ambient
- **DS18B20_8** → Pufferspeicher Oben
- **DHT22** → Raumklima Heizraum

## ⚡ Quick Start

### 🚀 **Option 1: Standard-Installation (Sensoren only)**
```bash
# Repository klonen
git clone https://github.com/OliverRebock/Heizung_small.git
cd Heizung_small

# Basis-Installation (mit optionaler Docker-Auswahl)
chmod +x install_sensors.sh
./install_sensors.sh

# Nach Neustart testen
sudo reboot
cd ~/sensor-monitor-pi5
python sensor_monitor.py single
```

### 🌟 **Option 2: Full-Stack Installation (Alles in einem)**
```bash
# Repository klonen
git clone https://github.com/OliverRebock/Heizung_small.git
cd Heizung_small

# Komplette Installation: Sensoren + Docker + Grafana + Web-Dashboard
chmod +x install_full_stack.sh
./install_full_stack.sh

# Nach Installation verfügbar:
# 📊 Grafana: http://YOUR_PI_IP:3000
# 🌐 Web-Dashboard: http://YOUR_PI_IP:5000
```

## 🐳 Docker Stack

```bash
# InfluxDB + Grafana starten
docker compose up -d

# Status prüfen
docker compose ps
```

### Web-Interfaces
- **Grafana**: http://localhost:3000 (pi5admin/pi5sensors2024)
- **InfluxDB**: http://localhost:8086 (pi5admin/pi5sensors2024)

## 📊 Grafana Dashboards

- `grafana_dashboard_main.json` - Haupt-Dashboard (4x3 Grid)
- `grafana_dashboard_mobile.json` - Mobile-optimiert
- `grafana_dashboard_alarms.json` - Alarm-Überwachung

## 🔧 Konfiguration

```bash
# Standard Sensor-Monitor
python sensor_monitor.py single          # Einmalige Messung
python sensor_monitor.py continuous 30   # Kontinuierlich (30s)
python sensor_monitor.py parallel        # High-Performance

# Individualisierte Sensoren
python individualized_sensors.py         # Test individueller Namen
python influxdb_individualized.py        # InfluxDB mit Namen

# InfluxDB Integration
python sensor_influxdb.py test          # Verbindung testen
python sensor_influxdb.py monitor       # Kontinuierlich loggen

# ⚠️ Komplette Deinstallation
chmod +x reset.sh                        # Script ausführbar machen
./reset.sh                               # ALLES löschen (mit Warnung!)
```

### 🏷️ Sensor-Namen individualisieren

**1. Namen in `config.ini` anpassen:**
```ini
[labels]
ds18b20_1 = "Mein Vorlauf Sensor"
ds18b20_2 = "Mein Rücklauf Sensor"
ds18b20_3 = "Warmwasser Sensor"
# ... weitere Sensoren
dht22 = "Heizraum Klima"
```

**2. Individualisierte Daten verwenden:**
```bash
python individualized_sensors.py        # Test der Namen
python influxdb_individualized.py       # InfluxDB mit Namen
```

## 🔍 Troubleshooting

### 1-Wire Sensoren nicht gefunden
```bash
# 1-Wire Interface aktivieren
sudo nano /boot/firmware/config.txt
# Zeile hinzufügen: dtoverlay=w1-gpio,gpiopin=4
sudo reboot
```

### DHT22 Sensor-Fehler
```bash
# lgpio Installation prüfen
pip install lgpio --upgrade
sudo apt install libgpiod2 libgpiod-dev
```

### Docker Container Probleme
```bash
# Logs prüfen
docker compose logs grafana
docker compose logs influxdb

# Neu starten
docker compose restart
```

## 📈 Performance

- **DS18B20 Lesezeit**: ~50ms pro Sensor (parallel)
- **DHT22 Lesezeit**: ~250ms
- **Gesamt-Zykluszeit**: ~300ms für alle 7 Sensoren
- **Speicher-Verbrauch**: ~15MB
- **CPU-Last**: <5% auf Pi 5

## 🔄 Autostart

```bash
# Monitoring als Service einrichten
./setup_autostart_monitoring.sh

# Service-Status prüfen
sudo systemctl status pi5-sensor-monitoring
```

## 🔥 Komplette Deinstallation

⚠️ **WARNUNG**: Das `reset.sh` Script entfernt **ALLES** vom Projekt!

```bash
# Script ausführbar machen
chmod +x reset.sh

# Komplette Deinstallation (mit Sicherheitsabfrage)
./reset.sh
```

**Was wird gelöscht:**
- 🐳 Alle Docker Container, Images und Volumes
- ⚙️ Alle Systemd Services und Konfigurationen
- 📁 Alle Projektverzeichnisse und Dateien
- 🐍 Python Virtual Environments
- ⏰ Crontab-Einträge
- 📊 Log-Dateien und Backups
- 🔧 Optional: Docker komplett deinstallieren

**Was bleibt erhalten:**
- ✅ GPIO-Konfiguration in `/boot/firmware/config.txt`
- ✅ System-Python und andere Software

> 💡 Das Script fragt zweimal nach Bestätigung. Kein Neustart erforderlich.

## 📁 Projektstruktur

```
Heizung_small/
├── sensor_monitor.py                    # Haupt-Sensor-Script
├── sensor_influxdb.py                   # InfluxDB Integration
├── individualized_sensors.py            # 🆕 Sensor-Individualisierung
├── influxdb_individualized.py           # 🆕 InfluxDB mit Namen
├── advanced_monitoring.py               # 🆕 Smart Monitoring & Alerts
├── web_dashboard.py                     # 🆕 Live Web-Interface
├── test_sensors_fixed.py                # Hardware Tests
├── test_comprehensive.py                # 🆕 Pytest Test-Suite
├── install_sensors.sh                   # Basis-Installation
├── install_full_stack.sh                # 🆕 Complete Stack Installation
├── install_docker_influxdb.sh           # Docker Installation
├── backup_system.sh                     # 🆕 Backup & Recovery
├── setup_individualized_sensors.sh      # 🆕 Sensor-Naming Setup
├── reset.sh                             # 🆕 🔥 KOMPLETTE DEINSTALLATION
├── docker-compose.yml                   # Docker Stack
├── docker-compose-clean.yml             # 🆕 Optimized Docker
├── grafana_dashboard_*.json             # Grafana Dashboards
├── requirements.txt                     # 🆕 Python Dependencies
├── config.ini                           # 🆕 Central Configuration
├── .env                                 # 🆕 Environment Variables
├── .github/workflows/ci.yml             # 🆕 CI/CD Pipeline
└── setup_autostart_*.sh                 # Service-Setup
```

## 🤝 Beitragen

1. Fork erstellen
2. Feature-Branch: `git checkout -b feature/neues-feature`
3. Commit: `git commit -am 'Neues Feature'`
4. Push: `git push origin feature/neues-feature`
5. Pull Request erstellen

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Details siehe [LICENSE](LICENSE) Datei.

## 🏷️ Tags

`raspberry-pi-5` `iot` `sensors` `monitoring` `influxdb` `grafana` `docker` `python` `ds18b20` `dht22`

---

**⚡ Optimiert für Raspberry Pi 5 - Professional IoT Monitoring** 🍓
