# 🌡️ Pi5 Ultra-Minimal Sensor Monitor

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

## 🌐 Zugriff

- **📊 Grafana**: `http://PI_IP:3000` (kein Login!)
- **🗄️ InfluxDB**: `http://PI_IP:8086` (admin/pi5sensors2024)

## 🏷️ Sensornamen ändern

```bash
nano ~/pi5-sensors/config.ini
```

```ini
[labels]
ds18b20_1 = Mein Sensor Name
ds18b20_2 = Anderer Name
# ... 
dht22 = Raumklima
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

### Sensoren werden nicht erkannt?
```bash
# GPIO prüfen
ls /sys/bus/w1/devices/

# Falls leer:
sudo modprobe w1-gpio
sudo modprobe w1-therm
```

## 📁 Projekt-Struktur

```
~/pi5-sensors/
├── sensor_reader.py     # Hauptscript (9 Sensoren)
├── config.ini          # Sensornamen hier ändern
├── docker-compose.yml  # InfluxDB + Grafana
├── venv/               # Python Virtual Environment
└── (logs...)
```

---

🎯 **Ultra-minimal, funktioniert sofort!**
