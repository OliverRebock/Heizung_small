# 🌡️ Pi5 Heizungs Messer
**Professionelles Heizungsmonitoring mit Raspberry Pi 5**

[![Raspberry Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![InfluxDB](https://img.shields.io/badge/InfluxDB-2.x-orange.svg)](https://www.influxdata.com/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboard-green.svg)](https://grafana.com/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-MQTT-yellow.svg)](https://www.home-assistant.io/)

## 🏠 Überblick

**Pi5 Heizungs Messer** ist eine professionelle Lösung zur Überwachung von Heizungsanlagen mit 9 Temperatursensoren (8x DS18B20 + 1x DHT22). Das System bietet:

- ✅ **4 Heizkreise** mit Vorlauf/Rücklauf Temperaturen
- ✅ **Raumklima-Überwachung** (Temperatur + Luftfeuchtigkeit) 
- ✅ **Grafana Dashboards** für professionelle Visualisierung
- ✅ **Home Assistant Integration** via MQTT
- ✅ **Docker-basiert** für einfache Installation
- ✅ **Pi5 optimiert** mit lgpio Support

## 📊 Dashboard Vorschau

**4 Heizkreise überwacht:**
- 🔥 **HK1**: Wärmepumpe (Vorlauf/Rücklauf)
- 🏠 **HK2**: Obergeschoss (Vorlauf/Rücklauf)  
- 🏘️ **HK3**: Untergeschoss (Vorlauf/Rücklauf)
- 🏠 **HK4**: Keller (Vorlauf/Rücklauf)
- 🌡️ **Heizraum**: Temperatur + Luftfeuchtigkeit

## 🚀 Schnellstart (One-Command Installation)

```bash
# 1. Repository klonen
git clone https://github.com/OliverRebock/Pi5-Heizungs-Messer.git
cd Pi5-Heizungs-Messer

# 2. Installation (alles automatisch)
bash install_simple.sh

## 📋 Sensor Setup

### Hardware Anforderungen
- **Raspberry Pi 5** (empfohlen)
- **8x DS18B20** Temperatursensoren (GPIO 4)
- **1x DHT22** Temperatur/Luftfeuchtigkeit Sensor (GPIO 18)
- **4.7kΩ Pullup** Widerstände

### Sensor Belegung
```
GPIO 4  → DS18B20 Sensoren (8 Stück, One-Wire Bus)
GPIO 18 → DHT22 Sensor (Temperatur + Luftfeuchtigkeit)
```

### Professionelle Sensor Labels
```
28-0000000001 → HK1 Vorlauf    (Wärmepumpe)
28-0000000002 → HK1 Rücklauf   (Wärmepumpe)
28-0000000003 → HK2 Vorlauf    (Obergeschoss)  
28-0000000004 → HK2 Rücklauf   (Obergeschoss)
28-0000000005 → HK3 Vorlauf    (Untergeschoss)
28-0000000006 → HK3 Rücklauf   (Untergeschoss)
28-0000000007 → HK4 Vorlauf    (Keller)
28-0000000008 → HK4 Rücklauf   (Keller)
DHT22         → Heizraum Klima (Temp + Humidity)
```

## 📦 Installationsmethoden

### 🟢 Methode 1: Ultra-Simple (Empfohlen)
```bash
bash install_simple.sh
```
- **One-Command Installation**
- Embedded Python Code (kein Git erforderlich)
- Alle Dependencies automatisch installiert
- Sofort einsatzbereit

### 🔵 Methode 2: Git-basiert 
```bash
bash install_minimal.sh
```
- Git Repository wird geklont
- Separate Python Files
- Für Entwicklung geeignet

### 🟡 Methode 3: Docker-Only
```bash
bash install_docker_influxdb.sh
```
- Nur InfluxDB + Grafana
- Sensors separat installieren

## 🏠 Home Assistant Integration

### MQTT Setup
```bash
# 1. MQTT Broker installieren
bash install_mqtt.sh

# 2. MQTT Bridge Service einrichten
bash setup_mqtt_service.sh

# 3. Service starten
sudo systemctl start pi5-mqtt-bridge
```

### Auto-Discovery
- **10 Sensoren** werden automatisch erkannt
- **Professionelle Namen** (HK1-4 Vorlauf/Rücklauf)
- **Real-time Updates** alle 30 Sekunden
- **Availability Status** (Online/Offline)

## 📊 Grafana Dashboards

### Verfügbare Dashboards
- **`grafana_dashboard_heizkreise_final.json`** - Hauptdashboard mit 4 Heizkreisen
- **`grafana_dashboard_main.json`** - Übersicht Dashboard  
- **`grafana_dashboard_mobile.json`** - Mobile-optimiert
- **`grafana_dashboard_alarms.json`** - Alarm Dashboard

### Dashboard Import
1. Grafana öffnen: `http://raspberrypi:3000`
2. Login: `admin` / `admin`
3. **Import** → JSON File auswählen
4. **InfluxDB Datasource** auswählen
5. **Import** klicken

## ⚙️ Konfiguration

### Sensor Labels anpassen
```bash
nano /home/pi/pi5-sensors/sensor_labels.json
```

### InfluxDB Token ändern
```bash
nano /home/pi/pi5-sensors/docker-compose.yml
```

### MQTT Einstellungen
```bash
nano /home/pi/pi5-sensors/config.ini
```

## 🔧 Systemd Services

### Sensor Service
```bash
sudo systemctl status pi5-sensors        # Status prüfen
sudo systemctl restart pi5-sensors       # Neustart
sudo journalctl -u pi5-sensors -f        # Live Logs
```

### MQTT Bridge Service  
```bash
sudo systemctl status pi5-mqtt-bridge    # Status prüfen
sudo systemctl restart pi5-mqtt-bridge   # Neustart
sudo journalctl -u pi5-mqtt-bridge -f    # Live Logs
```

### Docker Services
```bash
sudo systemctl status docker             # Docker Status
docker-compose -f /home/pi/pi5-sensors/docker-compose.yml ps
```

## 🧪 Testing & Debugging

### Sensor Test
```bash
cd /home/pi/pi5-sensors
source venv/bin/activate
python test_sensors_fixed.py
```

### MQTT Test
```bash
cd /home/pi/pi5-sensors  
source venv/bin/activate
python mqtt_bridge.py test
```

### InfluxDB Test
```bash
# Web Interface
http://raspberrypi:8086

# CLI Test
influx auth list
```

### MQTT Topics überwachen
```bash
mosquitto_sub -t 'pi5_heizung/+/state'
```

## 🌐 Web Interfaces

| Service | URL | Login |
|---------|-----|-------|
| **Grafana** | http://raspberrypi:3000 | admin/admin |
| **InfluxDB** | http://raspberrypi:8086 | admin/password123 |

## 🛠️ Erweiterte Features

### Automatische Sensor-Erkennung
- **DS18B20 IDs** werden automatisch erkannt
- **Sensor Labels** können angepasst werden
- **Fallback-Modi** bei Sensor-Ausfällen

### Pi5 Optimierungen
- **lgpio Support** für Raspberry Pi 5
- **Multi-Fallback** Installation
- **Docker Permissions** automatisch konfiguriert
- **Systemd Integration** für Autostart

### Professional Monitoring
- **InfluxDB 2.x** mit Flux Queries
- **Grafana Alerting** bei kritischen Temperaturen
- **Home Assistant Automations** 
- **Mobile Dashboards** für unterwegs

## 🆘 Troubleshooting

### Häufige Probleme

**❌ "No module named lgpio"**
```bash
# Automatisch gelöst durch install_simple.sh
# Oder manuell: pip install lgpio
```

**❌ "Docker permission denied"**  
```bash
sudo usermod -aG docker pi
newgrp docker
```

**❌ "No data in Grafana"**
```bash
# InfluxDB Status prüfen
curl -I http://localhost:8086/health

# Sensor Service prüfen
sudo systemctl status pi5-sensors
```

**❌ "MQTT not working"**
```bash
# MQTT Broker Status
sudo systemctl status mosquitto

# MQTT Bridge Logs
sudo journalctl -u pi5-mqtt-bridge -f
```
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
