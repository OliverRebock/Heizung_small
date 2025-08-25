# 🌡️ Pi5 Heizungs Messer - Ultra-Minimal

**Ein-Befehl Installation** für 9 Sensoren am Raspberry Pi 5.

## 🎯 Was## 🌐 Zugriff

### 🔧 **NEUE/LEERE Systeme:**
- **📊 Grafana**: `http://PI_IP:3000` (kein Login!)
- **📊 Grafana Subpath**: `http://PI_IP:3000/grafana/` (für Reverse Proxy)
- **🗄️ InfluxDB**: `http://PI_IP:8086` (admin/pi5sensors2024)

### 🚨 **SYSTEME MIT EXISTIERENDEM DOCKER/GRAFANA:**
- **📊 Grafana**: `http://PI_IP:3001/grafana/` (konfliktfreier Port)
- **📊 Grafana (Domain)**: `http://dermesser.fritz.box:3001/grafana/`
- **🗄️ InfluxDB**: `http://PI_IP:8087` (admin/pi5sensors2024)

**Neue Features:**
- ✨ **Automatische Port-Erkennung**: Verwendet freie Ports (3001, 8087)
- 🔧 **Konflikt-sichere Container**: `pi5-sensors-` Prefix
- 🌐 **Flexible Subpath Support**: Funktioniert mit IP, Hostname, .fritz.box, .local
- 🔧 **Domain-spezifische Konfiguration**: `dermesser.fritz.box:PORT/grafana/`
- 🌐 **Professionelle Konfiguration**: Optimiert für Reverse Proxy Setup

- **8x DS18B20** Temperatursensoren
- **1x DHT22** (Temperatur + Luftfeuchtigkeit)
- **InfluxDB** als Datenbank
- **Grafana** OHNE Login für Visualisierung
- **Python venv** für DHT22 Kompatibilität

## ⚡ Installation (Ein Befehl!)

### � **SCHRITT 1: Docker Konflikt-Check (EMPFOHLEN)**

```bash
# Prüfe ob bereits Docker/Grafana Services laufen
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/check_docker_conflicts.sh | bash
```

### �🚨 **SCHRITT 2A: FÜR SYSTEME MIT BEREITS LAUFENDEM DOCKER/GRAFANA:**

```bash
# 🔧 KONFLIKT-SICHERE Installation (andere Ports & Container-Namen)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_existing_docker.sh | bash

# 🏠 KONFLIKT-SICHERE Installation MIT Home Assistant MQTT:
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_existing_docker.sh | bash -s -- 192.168.1.100 homeassistant mySecretPassword
```

**Verwendet automatisch freie Ports:**
- **Grafana**: Port 3001 (falls 3000 belegt)
- **InfluxDB**: Port 8087 (falls 8086 belegt)  
- **Container**: `pi5-sensors-grafana`, `pi5-sensors-influxdb`

### 🌡️ **SCHRITT 2C: OHNE GRAFANA (InfluxDB + Sensoren)**

```bash
# Für Systeme mit bereits existierender Grafana
# Installiert: InfluxDB + Sensoren, OHNE Grafana

curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_without_grafana.sh | bash
```

**Installiert:**
- ✅ **InfluxDB** (Docker Container, Port 8086/8087)
- ✅ **Pi5 Sensor Reader** (8x DS18B20 + 1x DHT22)
- ✅ **Systemd Service** (pi5-sensors)

**Installiert NICHT:**
- ❌ **Grafana** (verwendest deine existierende)

**InfluxDB Datenquelle für deine Grafana:**
- **URL**: `http://localhost:8086` (oder 8087 bei Konflikten)
- **Token**: `pi5-token-2024`
- **Organisation**: `pi5org`
- **Bucket**: `sensors`

### 🔧 **SCHRITT 2D: NUR SENSOREN (KEIN Docker/Grafana)**

```bash
# Für Systeme mit bereits existierender InfluxDB/Grafana
# Installiert NUR: Python + Sensoren + Service (KEIN Docker!)

# Parameter-Installation:
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors_only.sh | bash -s -- INFLUX_URL TOKEN ORG BUCKET

# Beispiele:
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors_only.sh | bash -s -- http://localhost:8086 myToken myOrg sensors

curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors_only.sh | bash -s -- http://192.168.1.100:8086 influx-token homelab pi5-sensors

# Interaktive Installation:
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors_only.sh
chmod +x install_sensors_only.sh
./install_sensors_only.sh
```

**Installiert NUR:**
- ✅ **Python Umgebung** + Sensor Packages  
- ✅ **Pi5 Sensor Reader** (8x DS18B20 + 1x DHT22)
- ✅ **Systemd Service** (pi5-sensors-standalone)

**Installiert NICHT:**
- ❌ **Docker** (verwendet existierende Installation)
- ❌ **Grafana** (verwendet existierende Installation)  
- ❌ **InfluxDB** (verwendet existierende Installation)

### 🟢 **SCHRITT 2E: FÜR NEUE/LEERE SYSTEME:**

```bash
# 🚨 NUCLEAR OPTION - ULTIMATE WELCOME SCREEN KILLER (für Neuinstallation)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_complete_nuclear.sh | bash

# Standard Installation (bewährt)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash

# NUCLEAR mit MQTT (Home Assistant Integration sofort):
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_complete_nuclear.sh | bash -s -- 192.168.1.100 homeassistant mySecretPassword
```

**Das war's!** Nach dem Neustart läuft alles.

## 🏠 Home Assistant Integration (Optional)

Für Home Assistant MQTT Integration:

```bash
# Option 1: Parameter-Installation (EMPFOHLEN für curl | bash)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh | bash -s -- HA_IP MQTT_USER MQTT_PASS

# Beispiel mit echten Werten:
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh | bash -s -- 192.168.1.100 homeassistant mySecretPassword

# Weitere Beispiele:
# Fritzbox Standard IP:
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh | bash -s -- 192.168.178.50 mqtt_user mqtt123

# Home Assistant mit Docker/VM:
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh | bash -s -- 192.168.1.200 pi5sensors HeizungMQTT2024

# Option 2: Interaktive Installation
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_ultra_simple.sh
chmod +x install_mqtt_ultra_simple.sh
./install_mqtt_ultra_simple.sh

# Option 3: DEBUG Version (falls Probleme auftreten)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_debug.sh | bash

# 🚨 MQTT IMPORT ERROR FIX (falls ModuleNotFoundError: mqtt_bridge)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_mqtt_import_error.sh | bash

# Option 4: Einfache Installation (mit Parameter möglich)
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_simple.sh | bash

# Option 5: Interaktive Installation
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt.sh | bash

# Service Status prüfen
sudo systemctl status pi5-mqtt-bridge
```

**Wichtig:** 
- 📡 **Sendet direkt an Home Assistant MQTT Broker** (nicht lokaler Broker!)
- 🏠 **Home Assistant IP** als Parameter oder interaktiv
- 🔐 **MQTT Username/Passwort** für Home Assistant als Parameter oder interaktiv

**🔍 Wie finde ich meine Werte?**

**Home Assistant IP-Adresse:**
- Home Assistant Web-Interface URL: `http://DEINE_HA_IP:8123`
- Router Admin Panel → Geräteliste
- Oder im Terminal: `nmap -sn 192.168.1.0/24` (suche nach Home Assistant)

**MQTT Credentials in Home Assistant:**
1. **Settings** → **Add-ons** → **Mosquitto broker** → **Configuration**
2. Oder **Settings** → **People** → **Users** → MQTT User erstellen
3. **Standard MQTT User**: Oft `homeassistant` oder `mqtt`
4. **MQTT Port**: Standard `1883` (wird automatisch verwendet)

**📋 Typische Setups:**
```bash
# Home Assistant OS (Standard):
# IP: 192.168.1.100, User: homeassistant, Pass: dein-ha-password

# Home Assistant Docker:  
# IP: 192.168.1.200, User: mqtt, Pass: mqtt-password

# Synology NAS Home Assistant:
# IP: 192.168.1.150, User: ha-mqtt, Pass: NAS-Password
```

**Features:**
- 🔄 **Auto-Discovery** für alle 9 Sensoren in Home Assistant
- 📡 **Live Updates** alle 30 Sekunden  
- 🏷️ **Professionelle Namen** (HK1 Vorlauf, HK2 Rücklauf, etc.)
- 🔐 **MQTT Authentifizierung** für Home Assistant

## 🌐 Zugriff

- **📊 Grafana**: `http://PI_IP:3000` (kein Login!)
- **� Grafana Subpath**: `http://PI_IP:3000/grafana/` (für Reverse Proxy)
- **�🗄️ InfluxDB**: `http://PI_IP:8086` (admin/pi5sensors2024)

**Neue Features:**
- ✨ **Flexible Subpath Support**: Funktioniert mit IP, Hostname, .fritz.box, .local
- 🔧 **Domain-spezifische Konfiguration**: `dermesser.fritz.box:3000/grafana/`
- 🌐 **Professionelle Konfiguration**: Optimiert für Reverse Proxy Setup

## 🏷️ Sensornamen ändern

```bash
nano ~/pi5-sensors/config.ini
```

```ini
[labels]
ds18b20_1 = RL WP
ds18b20_2 = VL UG  
ds18b20_3 = VL WP
ds18b20_4 = RL UG
ds18b20_5 = RL OG
ds18b20_6 = RL Keller
ds18b20_7 = VL OG
ds18b20_8 = VL Keller
dht22 = Raumklima Heizraum
```

Danach: `sudo systemctl restart pi5-sensors`

## 🔧 Wichtige Befehle

```bash
# Service Status
sudo systemctl status pi5-sensors

# Live Logs
sudo journalctl -u pi5-sensors -f

# 🚨 PI5-SENSORS SERVICE PROBLEME?
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/debug_pi5_sensors.sh
chmod +x debug_pi5_sensors.sh
./debug_pi5_sensors.sh

# Quick Fix für Service-Probleme
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/quickfix_pi5_sensors.sh
chmod +x quickfix_pi5_sensors.sh
./quickfix_pi5_sensors.sh

# Sensor Test
cd ~/pi5-sensors
source venv/bin/activate  
python sensor_reader.py test

# Container Status
cd ~/pi5-sensors
docker compose ps

# MQTT Bridge (falls installiert)
sudo systemctl status pi5-mqtt-bridge
sudo journalctl -u pi5-mqtt-bridge -f

# Home Assistant Auto-Discovery testen
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/test_home_assistant.sh
chmod +x test_home_assistant.sh
./test_home_assistant.sh
```

## 🛠️ Troubleshooting

### DHT22 funktioniert nicht?
```bash
cd ~/pi5-sensors
source venv/bin/activate
pip install --force-reinstall adafruit-circuitpython-dht
```

### Docker startet nicht?
```bash
sudo systemctl start docker
cd ~/pi5-sensors
docker compose up -d
```

### 📊 Grafana Subpath (/grafana/) funktioniert nicht?
```bash
# 🚨 ORGANIZATION NOT FOUND FIX ({"message":"organization not found","statusCode":404})
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_organization_not_found.sh
chmod +x fix_organization_not_found.sh
./fix_organization_not_found.sh

# 🐳 DOCKER COMPOSE DOMAIN FIX (für dermesser.fritz.box Organization Problem)
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_docker_compose_domain.sh
chmod +x fix_docker_compose_domain.sh
./fix_docker_compose_domain.sh

# 🚨 SERVE_FROM_SUB_PATH SOFORT-FIX (bei Welcome Screen trotz korrekter Config)
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_serve_from_sub_path.sh
chmod +x fix_serve_from_sub_path.sh
./fix_serve_from_sub_path.sh

# 🔍 WELCOME SCREEN DIAGNOSE (um das Problem zu analysieren)
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/diagnose_welcome_screen.sh
chmod +x diagnose_welcome_screen.sh
./diagnose_welcome_screen.sh

# 🚨 SUPER-AGGRESSIVE WELCOME SCREEN KILLER (bei hartnäckigem "Welcome to Grafana")
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/kill_grafana_welcome_brutal.sh
chmod +x kill_grafana_welcome_brutal.sh
./kill_grafana_welcome_brutal.sh

# 🚨 WELCOME SCREEN FIX - "Welcome to Grafana" nicht wegklickbar
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_grafana_welcome_screen.sh
chmod +x fix_grafana_welcome_screen.sh
./fix_grafana_welcome_screen.sh

# 🚨 SOFORT-REPARATUR für dermesser.fritz.box:3000/grafana/ (bei "Page not found")
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_grafana_subpath_emergency.sh
chmod +x fix_grafana_subpath_emergency.sh
./fix_grafana_subpath_emergency.sh

# URL-Test ausführen
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/test_grafana_urls.sh
chmod +x test_grafana_urls.sh
./test_grafana_urls.sh

# Universal Grafana Subpath Konfiguration (EMPFOHLEN für neue Installation)
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/configure_grafana_subpath.sh
chmod +x configure_grafana_subpath.sh
./configure_grafana_subpath.sh

# Beispiele für direkte Konfiguration:
./configure_grafana_subpath.sh 192.168.1.100
./configure_grafana_subpath.sh dermesser.fritz.box  
./configure_grafana_subpath.sh pi5.local

# Grafana Docker Konfiguration prüfen
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/diagnose_grafana_config.sh
chmod +x diagnose_grafana_config.sh
./diagnose_grafana_config.sh
```

### Docker Permission Problem?
```bash
# Schneller Fix
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_docker_permission.sh | bash

# Oder manuell:
sudo usermod -aG docker $USER
sudo systemctl restart docker
cd ~/pi5-sensors
sudo docker compose up -d

# Nach Neustart funktioniert es ohne sudo
sudo reboot
```

### Sensoren werden nicht erkannt?
```bash
# GPIO prüfen
ls /sys/bus/w1/devices/

# Falls leer:
sudo modprobe w1-gpio
sudo modprobe w1-therm
```

### MQTT Bridge Probleme?
```bash
# 🚨 MQTT IMPORT ERROR FIX (ModuleNotFoundError: mqtt_bridge)
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_mqtt_import_error.sh
chmod +x fix_mqtt_import_error.sh
./fix_mqtt_import_error.sh

# 🚨 CONFIG.INI REPARIEREN (falls mehrfach installiert)
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_config_mqtt.sh
chmod +x fix_config_mqtt.sh
./fix_config_mqtt.sh

# MQTT Service neu starten
sudo systemctl restart pi5-mqtt-bridge

# MQTT Bridge Status
sudo systemctl status pi5-mqtt-bridge
sudo journalctl -u pi5-mqtt-bridge -f

# 🏠 HOME ASSISTANT AUTO-DISCOVERY PROBLEME?
cd ~/pi5-sensors

# 1. Discovery Debug ausführen
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/debug_mqtt_discovery.sh
chmod +x debug_mqtt_discovery.sh
./debug_mqtt_discovery.sh

# 2. Home Assistant Discovery Fix
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_home_assistant_discovery.py
python fix_home_assistant_discovery.py

# 3. Original Test
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/test_home_assistant.sh
chmod +x test_home_assistant.sh
./test_home_assistant.sh

# 4. MQTT Service prüfen
sudo systemctl status pi5-mqtt-bridge
sudo journalctl -u pi5-mqtt-bridge -f

# MQTT Verbindung testen
cd ~/pi5-sensors
python mqtt_debug.py

# MQTT Bridge direkt testen
python mqtt_bridge.py mqtt-test

# Nur Discovery senden
python mqtt_bridge.py discovery

# Topics in Home Assistant prüfen (mit echten Werten)
mosquitto_sub -h 192.168.1.100 -u homeassistant -P mySecretPassword -t 'homeassistant/sensor/pi5_heizung_+/config' -v

# Sensor-Daten prüfen (mit echten Werten)  
mosquitto_sub -h 192.168.1.100 -u homeassistant -P mySecretPassword -t 'pi5_heizung/+/state' -v

# Alle MQTT Topics anzeigen
mosquitto_sub -h 192.168.1.100 -u homeassistant -P mySecretPassword -t '#' -v

# Konfiguration prüfen
nano ~/pi5-sensors/config.ini
```

## � Grafana Dashboards

Nach der Installation stehen dir fertige Dashboards zur Verfügung:

```bash
# Dashboard-Dateien im Projekt:
grafana_dashboard_heizkreise.json   # 🏠 4 Heizkreise (Wärmepumpe, OG, UG, Keller) 
grafana_dashboard_main.json         # 📊 Alle 9 Sensoren Übersicht
grafana_dashboard_mobile.json       # 📱 Mobile Ansicht
grafana_dashboard_alarms.json       # 🚨 Alarme
```

**Dashboard importieren:**
1. **Grafana öffnen**: `http://PI_IP:3000`
2. **Klick**: `+` → `Import`
3. **Upload**: `grafana_dashboard_heizkreise.json`
4. **Datasource**: Wähle deine InfluxDB
5. **Import** - Fertig! 🎯

## 📁 Projekt-Struktur

```
~/pi5-sensors/
├── sensor_reader.py                    # Hauptscript (9 Sensoren)
├── config.ini                         # Sensornamen hier ändern
├── docker-compose.yml                 # InfluxDB + Grafana
├── grafana_dashboard_heizkreise.json  # 🏠 4 Heizkreise Dashboard
├── mqtt_bridge.py                     # 🏠 Home Assistant MQTT Bridge
├── venv/                              # Python Virtual Environment
└── (logs...)
```

## 📚 Erweiterte Dokumentation

- **🏠 MQTT Integration**: Siehe `MQTT_INTEGRATION.md`
- **📊 Grafana Dashboards**: Siehe `GRAFANA_DASHBOARDS.md`  
- **🔧 Installation**: Siehe `QUICKSTART.md`

---

🎯 **Ultra-minimal, funktioniert sofort!**
