# 🌡️ Pi5 Heizungs Messer - Ultra-Minimal

**Ein-Befehl Installation** für 9 Sensoren am Raspberry Pi 5.

## 🎯 Was ist das?

- **8x DS18B20** Temperatursensoren
- **1x DHT22** (Temperatur + Luftfeuchtigkeit)
- **InfluxDB** als Datenbank
- **Grafana** OHNE Login für Visualisierung
- **Python venv** für DHT22 Kompatibilität

## ⚡ Installation (Ein Befehl!)

```bash
curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash
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
- **🗄️ InfluxDB**: `http://PI_IP:8086` (admin/pi5sensors2024)

**Neue Features:**
- ✨ **Subpath Support**: Grafana läuft auch unter `/grafana/` Pfad
- 🔧 **Professionelle Konfiguration**: Optimiert für Reverse Proxy Setup

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
# MQTT Service neu starten
sudo systemctl restart pi5-mqtt-bridge

# MQTT Bridge Status
sudo systemctl status pi5-mqtt-bridge
sudo journalctl -u pi5-mqtt-bridge -f

# 🏠 HOME ASSISTANT AUTO-DISCOVERY TESTEN
cd ~/pi5-sensors
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/test_home_assistant.sh
chmod +x test_home_assistant.sh
./test_home_assistant.sh

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
