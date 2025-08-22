# 🌡️ Pi 5 Sensor Monitor - MINIMAL

**Ein-Klick Installation** für Raspberry Pi 5 mit 8x DS18B20 + 1x DHT22 Sensoren.

## 🎯 Was macht es?

- ✅ **Docker + InfluxDB + Grafana** automatisch installiert
- ✅ **Individualisierte Sensornamen** aus `config.ini`
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

# Sensoren testen
cd ~/sensor-monitor
python3 sensor_monitor.py test

# Service neustarten
sudo systemctl restart pi5-sensor-minimal
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
├── docker-compose.yml    # InfluxDB + Grafana
└── (automatische Logs)
```

**Service**: `pi5-sensor-minimal.service` startet automatisch

---

🎯 **Fokus**: Weniger ist mehr - funktioniert sofort!
