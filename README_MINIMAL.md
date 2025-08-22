# 🌡️ Pi 5 Sensor Monitor - MINIMAL

**Ein-Klick Installation** für Raspberry Pi 5 mit **9 Sensoren**: 8x DS18B20 + 1x DHT22 (Temp + Humidity = 10 Messwerte).

## 🎯 Was macht es?

- ✅ **Docker + InfluxDB + Grafana** automatisch installiert
- ✅ **9 Sensoren individualisiert** aus `config.ini` (8x DS18B20 + DHT22)
- ✅ **Grafana OHNE Login** - sofort nutzbar
- ✅ **Ein Service** für alles - kein Chaos

## ⚡ Installation (2 Befehle)

```bash
# 1. Repository klonen
git clone https://github.com/OliverRebock/Heizung_small.git
cd Heizung_small

# 2. Alles installieren (dauert ~10 Min)
chmod +x install_minimal.sh
./install_minimal.sh
```

**Das war's!** Nach dem Neustart läuft alles automatisch.

## 🌐 Zugriff

- **📊 Grafana**: `http://YOUR_PI_IP:3000` (kein Login!)
- **🗄️ InfluxDB**: `http://YOUR_PI_IP:8086` (pi5admin/pi5sensors2024)

## 🏷️ Sensornamen anpassen

**Datei**: `~/sensor-monitor/config.ini`

```ini
[labels]
ds18b20_1 = Mein Vorlauf Sensor
ds18b20_2 = Mein Rücklauf Sensor
ds18b20_3 = Warmwasser Sensor
# ... anpassen nach Bedarf
```

**Danach**: `sudo systemctl restart pi5-sensor-minimal`

## 🔧 Wichtige Befehle

```bash
# Service Status
sudo systemctl status pi5-sensor-minimal

# Logs anzeigen
sudo journalctl -u pi5-sensor-minimal -f

# ALLE 9 Sensoren testen (8x DS18B20 + 1x DHT22)
cd ~/sensor-monitor
source venv/bin/activate
python test_all_sensors.py

# Einzelner Sensor-Test
python sensor_monitor.py test

# Service neustarten
sudo systemctl restart pi5-sensor-minimal

# 🐳 DOCKER MONITORING (NEU!)
./docker_monitor.sh
```

## 🚨 Troubleshooting

### **Problem: ModuleNotFoundError: No module named 'influxdb_client'**

**WICHTIG**: DHT22 Sensor benötigt Python venv Umgebung!

**Lösung - Service Fix mit venv:**
```bash
cd ~/Heizung_small
git pull  # Neueste venv-Version holen
chmod +x fix_service_minimal.sh
./fix_service_minimal.sh
```

**Oder manuell venv erstellen:**
```bash
cd ~/sensor-monitor

# Python venv erstellen
python3 -m venv venv
source venv/bin/activate

# Dependencies in venv installieren
pip install influxdb-client lgpio adafruit-circuitpython-dht

# Service mit venv konfigurieren (siehe fix_service_minimal.sh)
```

## 🔥 Komplett löschen

```bash
./reset.sh  # Entfernt alles (GPIO bleibt)
```

## 🏗️ Was wurde installiert?

```
~/sensor-monitor/
├── sensor_monitor.py      # Ein Script für alles
├── config.ini            # Sensor-Namen hier
├── docker-compose.yml    # InfluxDB + Grafana (OPTIMIERT für Pi 5!)
├── venv/                 # Python Virtual Environment (für DHT22!)
│   ├── bin/python        # Python mit allen Dependencies
│   └── lib/              # Module (influxdb_client, lgpio, etc.)
├── docker_monitor.sh     # 🆕 Docker System Monitoring
└── (automatische Logs)
```

**Service**: `pi5-sensor-minimal.service` nutzt venv/bin/python

**Docker Optimierungen für Pi 5:**
- 🚀 Memory Limits: InfluxDB=512MB, Grafana=256MB
- 🔧 CPU Limits: InfluxDB=2 cores, Grafana=1 core  
- 📊 Healthchecks für Container-Überwachung
- 💾 Persistente Bind-Mounts in `/opt/docker-data/`
- 📋 Log-Rotation (10MB, 3 Dateien max)
- ⚡ Performance-Tuning für Grafana

---

🎯 **Fokus**: Weniger ist mehr - funktioniert sofort!
