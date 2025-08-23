# Pi5 Heizungs Messer → Home Assistant MQTT Integration
======================================================

## 🏠 Überblick

Die MQTT Integration ermöglicht es, alle Temperatur-Sensoren des Pi5 Heizungs Messers automatisch in Home Assistant zu integrieren. Die Sensoren werden automatisch erkannt (Auto-Discovery) und können sofort in Dashboards und Automationen verwendet werden.

## 📋 Funktionen

- ✅ **Auto-Discovery**: Sensoren werden automatisch in Home Assistant erkannt
- ✅ **Real-time Updates**: Temperaturen werden alle 30 Sekunden übertragen
- ✅ **Professionelle Benennung**: HK1-4 Vorlauf/Rücklauf + Heizraum Klima
- ✅ **Systemd Service**: Läuft automatisch im Hintergrund
- ✅ **Logging**: Vollständige Protokollierung für Debugging
- ✅ **Availability**: Home Assistant erkennt Online/Offline Status

## 🚀 Schnellstart

### 1. MQTT Broker installieren
```bash
bash install_mqtt.sh
```

### 2. MQTT Bridge installieren
```bash
bash setup_mqtt_service.sh
```

### 3. Service starten
```bash
sudo systemctl start pi5-mqtt-bridge
```

### 4. Home Assistant konfigurieren
- MQTT Integration aktivieren (falls nicht bereits aktiv)
- Broker IP: IP-Adresse deines Raspberry Pi 5
- Port: 1883
- Sensoren werden automatisch erkannt!

## 📊 Verfügbare Sensoren

| Sensor ID | Home Assistant Name | MQTT Topic |
|-----------|-------------------|------------|
| 28-0000000001 | HK1 Vorlauf | `pi5_heizung/28-0000000001/state` |
| 28-0000000002 | HK1 Rücklauf | `pi5_heizung/28-0000000002/state` |
| 28-0000000003 | HK2 Vorlauf | `pi5_heizung/28-0000000003/state` |
| 28-0000000004 | HK2 Rücklauf | `pi5_heizung/28-0000000004/state` |
| 28-0000000005 | HK3 Vorlauf | `pi5_heizung/28-0000000005/state` |
| 28-0000000006 | HK3 Rücklauf | `pi5_heizung/28-0000000006/state` |
| 28-0000000007 | HK4 Vorlauf | `pi5_heizung/28-0000000007/state` |
| 28-0000000008 | HK4 Rücklauf | `pi5_heizung/28-0000000008/state` |
| dht22_temperature | Heizraum Temperatur | `pi5_heizung/dht22_temperature/state` |
| dht22_humidity | Heizraum Luftfeuchtigkeit | `pi5_heizung/dht22_humidity/state` |

## ⚙️ Konfiguration

### MQTT Bridge Konfiguration (`config.ini`)
```ini
[mqtt]
broker = localhost        # MQTT Broker IP
port = 1883              # MQTT Port
username =               # Optional: Username
password =               # Optional: Passwort
topic_prefix = pi5_heizung

[database]
host = localhost         # InfluxDB Host
token = pi5-token-2024   # InfluxDB Token
org = pi5org             # InfluxDB Organisation
bucket = sensors         # InfluxDB Bucket

[labels]
# Sensor Labels - müssen mit InfluxDB Namen übereinstimmen!
28-0000000001 = HK1 Vorlauf
28-0000000002 = HK1 Rücklauf
...
```

### Service Commands
```bash
# Service starten/stoppen
sudo systemctl start pi5-mqtt-bridge
sudo systemctl stop pi5-mqtt-bridge
sudo systemctl restart pi5-mqtt-bridge

# Service Status
sudo systemctl status pi5-mqtt-bridge

# Live Logs
sudo journalctl -u pi5-mqtt-bridge -f

# Autostart aktivieren/deaktivieren
sudo systemctl enable pi5-mqtt-bridge
sudo systemctl disable pi5-mqtt-bridge
```

## 🧪 Testing

### Test-Modus (einmalige Übertragung)
```bash
cd /home/pi/pi5-sensors
source venv/bin/activate
python mqtt_bridge.py test
```

### MQTT Topics überwachen
```bash
# Alle Heizungs-Topics
mosquitto_sub -t 'pi5_heizung/+/state'

# Specific Topic
mosquitto_sub -t 'pi5_heizung/28-0000000001/state'

# Discovery Topics
mosquitto_sub -t 'homeassistant/sensor/pi5_heizung_+/config'
```

### InfluxDB Daten prüfen
```bash
# InfluxDB Web Interface
http://raspberrypi:8086

# Oder CLI Query
influx query 'from(bucket:"sensors") |> range(start:-1h) |> filter(fn:(r) => r["_measurement"] == "temperature")'
```

## 🏠 Home Assistant Integration

### Automatische Erkennung
1. **MQTT Integration** in Home Assistant aktivieren
2. **Broker IP**: IP-Adresse des Raspberry Pi 5
3. **Port**: 1883
4. **Discovery**: Aktiviert lassen
5. Sensoren erscheinen automatisch unter "Geräte & Services" → "MQTT"

### Manuelle Konfiguration
Falls Auto-Discovery nicht funktioniert, kopiere die Konfiguration aus `home_assistant_config.yaml` in deine `configuration.yaml`.

### Dashboard Integration
```yaml
# Beispiel Lovelace Card
type: entities
title: Heizkreis 1
entities:
  - entity: sensor.hk1_vorlauf
    name: Vorlauf
  - entity: sensor.hk1_ruecklauf  
    name: Rücklauf
  - entity: sensor.hk1_temperaturdifferenz
    name: Differenz
```

### Automationen
```yaml
# Alarm bei hoher Temperatur
automation:
  - alias: "Heizung Warnung"
    trigger:
      platform: numeric_state
      entity_id: sensor.hk1_vorlauf
      above: 70
    action:
      service: notify.mobile_app
      data:
        message: "Vorlauftemperatur hoch: {{ states('sensor.hk1_vorlauf') }}°C"
```

## 🔧 Troubleshooting

### Service startet nicht
```bash
# Logs prüfen
sudo journalctl -u pi5-mqtt-bridge -n 50

# Permissions prüfen
ls -la /home/pi/pi5-sensors/

# Dependencies prüfen
source /home/pi/pi5-sensors/venv/bin/activate
pip list | grep -E "(paho-mqtt|influxdb-client)"
```

### Keine Daten in Home Assistant
```bash
# MQTT Broker Status
sudo systemctl status mosquitto

# MQTT Topics testen
mosquitto_sub -t 'pi5_heizung/+/state'

# InfluxDB Verbindung testen
curl -I http://localhost:8086/health
```

### Sensor-IDs nicht gefunden
```bash
# Aktuelle Sensor-IDs anzeigen
cd /home/pi/pi5-sensors
source venv/bin/activate
python sensor_influxdb.py
```

### Discovery funktioniert nicht
1. MQTT Integration in Home Assistant neu konfigurieren
2. Home Assistant neustarten
3. Manuelle Konfiguration aus `home_assistant_config.yaml` verwenden

## 📈 Monitoring

### MQTT Bridge Performance
```bash
# Speicher/CPU Usage
sudo systemctl status pi5-mqtt-bridge

# Network Traffic
sudo netstat -tuln | grep 1883

# Log File Size
ls -lh /home/pi/pi5-sensors/mqtt_bridge.log
```

### Health Checks
```bash
# Alle Services prüfen
sudo systemctl is-active pi5-sensors influxdb mosquitto pi5-mqtt-bridge

# Port Status
sudo ss -tlnp | grep -E "(8086|1883)"
```

## 📚 Weitere Dokumentation

- **Installation**: `QUICKSTART.md`
- **Grafana Dashboards**: `GRAFANA_DASHBOARDS.md`
- **Sensor Installation**: `sensor_installation_guide.md`
- **GitHub Setup**: `GITHUB_SETUP.md`

## 🆘 Support

Bei Problemen:
1. Logs prüfen: `sudo journalctl -u pi5-mqtt-bridge -f`
2. Service neu starten: `sudo systemctl restart pi5-mqtt-bridge`
3. Konfiguration prüfen: `nano /home/pi/pi5-sensors/config.ini`
4. Test-Modus ausführen: `python mqtt_bridge.py test`

**Erfolgreiche Integration erkennbar durch:**
- ✅ Service Status: `active (running)`
- ✅ MQTT Topics sichtbar mit `mosquitto_sub`
- ✅ Sensoren in Home Assistant unter "MQTT" Geräte
- ✅ Live Temperatur-Updates alle 30 Sekunden
