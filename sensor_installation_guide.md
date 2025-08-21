# Sensor-Installation: 6x DS18B20 + 1x DHT22 für Raspberry Pi 5

## Hardware-Anforderungen

### Komponenten
- **Raspberry Pi 5** (optimiert für Pi 5)
- **6x DS18B20 Temperatursensoren** (wasserdicht, TO-92 oder wasserdicht)
- **1x DHT22 Temperatur-/Luftfeuchtigkeitssensor** (AM2302)
- **4.7kΩ Widerstand** (Pull-up für DS18B20, unbedingt erforderlich)
- **10kΩ Widerstand** (Pull-up für DHT22, empfohlen für Pi 5)
- **Breadboard oder Lötsteckbrett**
- **Qualitäts-Jumper-Kabel** (wichtig für stabile Verbindungen)
- **SD-Karte** (min. 32GB, Class 10, für Raspberry Pi OS)

### Verdrahtung für Raspberry Pi 5

#### DS18B20 Sensoren (1-Wire Bus)
```
Alle 6 DS18B20 parallel am 1-Wire Bus:
├── VDD (rot):    3.3V (Pin 1) - Stabile Spannungsversorgung
├── GND (schwarz): GND (Pin 6) - Gemeinsame Masse
└── Data (gelb):   GPIO 4 (Pin 7) + 4.7kΩ Pull-up zu 3.3V (Pin 1)

Wichtig für Pi 5:
- 4.7kΩ Pull-up Widerstand ist UNBEDINGT erforderlich
- Kurze, qualitativ hochwertige Kabel verwenden
- Alle Data-Pins parallel an GPIO 4 anschließen
```

#### DHT22 Sensor (für Pi 5 optimiert)
```
├── VCC (Pin 1): 3.3V (Pin 17) - Nicht Pin 1 wegen 1-Wire
├── Data (Pin 2): GPIO 18 (Pin 12) + 10kΩ Pull-up zu 3.3V (empfohlen)
├── NC (Pin 3): Nicht angeschlossen
└── GND (Pin 4): GND (Pin 20) - Separate Masse für DHT22

Pi 5 Besonderheiten:
- 10kΩ Pull-up für DHT22 empfohlen (bessere Signalqualität)
- GPIO 18 hat auf Pi 5 verbesserte Performance
- Kurze Kabelverbindungen für störungsfreien Betrieb
```

#### GPIO-Layout Raspberry Pi 5
```
Pin-Belegung (nur relevante Pins):
 1: 3.3V ────────────── VDD DS18B20 + Pull-ups
 6: GND ─────────────── GND DS18B20
 7: GPIO 4 (1-Wire) ── Data DS18B20 (alle 6 parallel)
12: GPIO 18 ────────── Data DHT22
17: 3.3V ────────────── VCC DHT22
20: GND ─────────────── GND DHT22
```

## Software-Installation für Raspberry Pi 5

### 1. Raspberry Pi 5 System vorbereiten
```bash
# System auf neueste Version aktualisieren (wichtig für Pi 5)
sudo apt update && sudo apt upgrade -y

# Pi 5 spezifische Pakete installieren
sudo apt install -y python3 python3-pip python3-venv git
sudo apt install -y python3-dev python3-setuptools
sudo apt install -y build-essential cmake

# GPIO-Tools für Pi 5
sudo apt install -y gpiod libgpiod-dev
```

### 2. 1-Wire Interface für Pi 5 aktivieren
```bash
# Pi 5 verwendet /boot/firmware/config.txt (NICHT /boot/config.txt!)
sudo nano /boot/firmware/config.txt

# Folgende Zeilen hinzufügen:
dtoverlay=w1-gpio,gpiopin=4
# Optional für bessere Performance:
dtparam=i2c_arm=on
dtparam=spi=on

# Module für Pi 5 konfigurieren
echo "w1-gpio" | sudo tee -a /etc/modules
echo "w1-therm" | sudo tee -a /etc/modules

# Neustart erforderlich (wichtig!)
sudo reboot
```

### 3. Python-Umgebung für Pi 5 einrichten
```bash
# Projekt-Verzeichnis erstellen
mkdir ~/sensor-monitor-pi5
cd ~/sensor-monitor-pi5

# Virtual Environment erstellen (Pi 5 verwendet Python 3.11+)
python3 -m venv venv
source venv/bin/activate

# Pi 5 spezifische Dependencies installieren
pip install --upgrade pip setuptools wheel

# GPIO-Bibliothek für Pi 5 (lgpio ist Pflicht!)
pip install lgpio

# CircuitPython für Pi 5
pip install adafruit-circuitpython-dht
pip install adafruit-blinka

# Zusätzliche Pi 5 Bibliotheken
pip install gpiozero
pip install RPi.GPIO  # Fallback-Unterstützung
```

## Automatische Installation für Raspberry Pi 5 (Empfohlen)

### Ein-Befehl-Installation für Pi 5
```bash
# Spezielle Pi 5 Installation:
wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_sensors.sh
chmod +x install_sensors.sh
./install_sensors.sh
```

Nach der Installation:
```bash
sudo reboot  # Immer erforderlich für Pi 5
cd ~/sensor-monitor-pi5
./test_sensors_pi5.sh
```

### Pi 5 Performance-Optimierungen
```bash
# Optional: Pi 5 für Sensor-Betrieb optimieren
sudo nano /boot/firmware/config.txt

# Hinzufügen für bessere Sensor-Performance:
gpu_mem=16          # Reduziert GPU-Speicher für headless Betrieb
max_usb_current=1   # Stabile USB-Power
arm_freq=2400       # Standard-Takt (2.4GHz)
# over_voltage=2    # Nur bei Stabilitätsproblemen

# Energiemanagement für stabile Sensoren:
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## Manuelle Installation

### 4. Sensor-Test-Script erstellen
```bash
# Das komplette Script ist als sensor_monitor.py verfügbar
# Es beinhaltet:
# - DS18B20 Manager für alle 6 Sensoren
# - DHT22 Temperatur/Feuchtigkeit
# - Hardware-Check
# - Einmalige oder kontinuierliche Messung
```

### 5. Installation testen
```bash
# Virtual Environment aktivieren
source venv/bin/activate

# Hardware prüfen
python sensor_monitor.py

# Sensoren manuell testen
# DS18B20 Sensoren prüfen:
ls /sys/bus/w1/devices/28-*

# Einzelnen Sensor lesen:
cat /sys/bus/w1/devices/28-*/w1_slave
```

## Troubleshooting für Raspberry Pi 5

### DS18B20 Sensoren nicht erkannt (Pi 5 spezifisch)
```bash
# 1-Wire Interface prüfen (Pi 5)
ls /sys/bus/w1/devices/

# Falls leer - Pi 5 Config prüfen:
sudo nano /boot/firmware/config.txt  # NICHT /boot/config.txt!
# Muss enthalten: dtoverlay=w1-gpio,gpiopin=4
sudo reboot

# Module manuell laden (Pi 5):
sudo modprobe w1-gpio
sudo modprobe w1-therm

# Pi 5 Hardware-Info anzeigen:
pinout  # GPIO-Layout anzeigen
```

### DHT22 Probleme auf Pi 5
```bash
# Pi 5 benötigt UNBEDINGT lgpio:
source venv/bin/activate
pip install lgpio --upgrade

# GPIO-Berechtigungen für Pi 5:
sudo usermod -a -G gpio $USER
sudo usermod -a -G dialout $USER
# Neuanmeldung erforderlich!

# DHT22 Test speziell für Pi 5:
python3 -c "
import board
import adafruit_dht
import lgpio
print('Pi 5 GPIO Test...')
dht = adafruit_dht.DHT22(board.D18, use_pulseio=False)
try:
    temp = dht.temperature
    hum = dht.humidity
    print(f'Pi 5 DHT22: {temp}°C, {hum}%')
except Exception as e:
    print(f'Pi 5 Error: {e}')
    print('Prüfe Verkabelung und lgpio Installation')
"
```

### Typische Pi 5 Fehler

**"No module named 'lgpio'"**
```bash
# Pi 5 MUSS lgpio verwenden:
source venv/bin/activate
pip install lgpio --upgrade
pip install gpiozero --upgrade
```

**"Unable to set line 18 to input" (Pi 5)**
```bash
# Pi 5 GPIO-Architektur prüfen:
gpioinfo  # Verfügbare GPIO-Chips anzeigen
ls /dev/gpiochip*  # GPIO-Devices prüfen

# Fallback für Pi 5:
pip install RPi.GPIO --upgrade
```

**"externally-managed-environment" (Pi 5)**
```bash
# Pi 5 Python-Umgebung ist strenger:
# IMMER Virtual Environment verwenden:
cd ~/sensor-monitor-pi5
python3 -m venv venv --clear  # Neu erstellen falls nötig
source venv/bin/activate
pip install --upgrade pip
```

**Keine DS18B20 Sensoren auf Pi 5**
```bash
# Pi 5 Hardware-spezifische Checks:
# 1. Stromversorgung prüfen (Pi 5 braucht min. 5V/3A)
# 2. Pull-up Widerstand MUSS 4.7kΩ sein
# 3. Kabel-Qualität (Pi 5 ist empfindlicher)

# Pi 5 1-Wire Debug:
echo "w1_master_driver w1_gpio" | sudo tee /sys/bus/w1/drivers_autoprobe
dmesg | grep w1  # Kernel-Messages prüfen

# Pi 5 GPIO-Test:
python3 -c "
import gpiozero
from gpiozero import Device
from gpiozero.pins.lgpio import LGPIOFactory
Device.pin_factory = LGPIOFactory()
print('Pi 5 GPIO Factory gesetzt')
"
```

## Sensor-Zuordnung für Pi 5

Die 6 DS18B20 Sensoren werden automatisch als DS18B20_1 bis DS18B20_6 erkannt.
Pi 5 Sensor-IDs können mit folgendem Befehl angezeigt werden:

```bash
cd ~/sensor-monitor-pi5
source venv/bin/activate
python3 -c "
import glob
print('Raspberry Pi 5 - Sensor-Zuordnung:')
print('=' * 40)
sensors = glob.glob('/sys/bus/w1/devices/28-*')
if sensors:
    for i, sensor in enumerate(sensors, 1):
        sensor_id = sensor.split('/')[-1]
        print(f'DS18B20_{i}: {sensor_id}')
    print(f'\\nGesamt: {len(sensors)} DS18B20 Sensoren auf Pi 5')
else:
    print('Keine DS18B20 Sensoren gefunden!')
    print('Prüfe: 1-Wire Interface, Verkabelung, Pull-up Widerstand')
"
```

### Pi 5 Performance-Features
- **Paralleles Sensor-Reading**: Alle 6 DS18B20 gleichzeitig
- **Optimierte GPIO-Performance**: Reduzierte Latenzen
- **Erweiterte Fehlerbehandlung**: Pi 5-spezifische GPIO-Diagnose
- **Automatische Takt-Optimierung**: Für stabile Sensor-Kommunikation

## Verwendung auf Pi 5

### Einmalige Messung
```bash
cd ~/sensor-monitor-pi5
./test_sensors_pi5.sh
# Wähle Option 1
```

### Kontinuierliche Überwachung (Pi 5 optimiert)
```bash
cd ~/sensor-monitor-pi5
./start_monitoring_pi5.sh
# Wähle Option 2 (30s) - empfohlen für Pi 5
# Wähle Option 3 (60s) - für stromsparenden Betrieb
# Wähle Option 4 (300s) - für Langzeit-Monitoring
```

### Pi 5 High-Performance Modus
```bash
# Für kritische Anwendungen - maximale Sensor-Performance:
cd ~/sensor-monitor-pi5
source venv/bin/activate
python3 -c "
from sensor_monitor_pi5 import SensorMonitor
monitor = SensorMonitor(high_performance=True)
monitor.continuous_monitoring(interval=10)  # 10s Intervall
"
```

### Programmierung eigener Scripts für Pi 5
```python
from sensor_monitor_pi5 import SensorMonitor

# Pi 5 optimierte Konfiguration
monitor = SensorMonitor(
    high_performance=True,    # Pi 5 Performance-Modus
    error_recovery=True,      # Automatische Fehlerbehandlung
    parallel_reading=True     # Paralleles Sensor-Reading
)

# Hardware prüfen mit Pi 5 Features
if monitor.check_hardware():
    # Pi 5 Batch-Messung (alle Sensoren parallel)
    ds_temps, dht_temp, dht_humidity = monitor.parallel_reading()
    
    # Daten verarbeiten
    for sensor, temp in ds_temps.items():
        print(f"{sensor}: {temp}°C")
        
    # Pi 5 Performance-Statistiken
    stats = monitor.get_performance_stats()
    print(f"Reading-Zeit: {stats['read_time']:.2f}ms")
    print(f"GPIO-Latenz: {stats['gpio_latency']:.2f}ms")
```
