# 📊 Grafana Dashboard Templates für Pi 5 Sensor Monitor

Diese Verzeichnis enthält professionelle Grafana Dashboard-Templates für das Raspberry Pi 5 Sensor-Monitor System.

## 🎯 Verfügbare Dashboards

### 1. **Hauptdashboard** - `grafana_dashboard_main.json`
**Professionelles 4x3 Grid Layout für vollständige Sensor-Übersicht**

📋 **Features:**
- 🌡️ Temperatur-Übersicht aller Sensoren (Time Series)
- 💧 Luftfeuchtigkeit Gauge mit Farbzonen
- 🔥 24h Min/Max Temperaturen (Stat Panel)
- 📈 DS18B20 Sensoren aufgeteilt (1-3 und 4-6)
- 🌡️💧 DHT22 Dual-Axis (Temperatur + Luftfeuchtigkeit)
- 📋 Sensor-Status Tabelle mit Farbcodierung
- ⚡ System-Status und aktive Sensoren
- 🚨 Temperatur-Alarme Counter

📐 **Layout:** 4x3 Grid (24 Spalten, 3 Reihen)  
🔄 **Refresh:** 30 Sekunden  
⏰ **Zeitraum:** Letzte 6 Stunden

### 2. **Mobile Dashboard** - `grafana_dashboard_mobile.json`
**Optimiert für Smartphones und Tablets**

📋 **Features:**
- 🌡️ Durchschnittstemperatur (große Stat-Anzeige)
- 💧 Luftfeuchtigkeit Gauge (kompakt)
- ⚡ Sensor-Status Übersicht
- 📈 Temperaturverlauf aller Sensoren (vereinfacht)
- 📋 Aktuelle Sensorwerte Tabelle

📐 **Layout:** Vertikal optimiert für mobile Geräte  
🔄 **Refresh:** 10 Sekunden  
⏰ **Zeitraum:** Letzte 1 Stunde

### 3. **Alarm Dashboard** - `grafana_dashboard_alarms.json`
**Kritische Überwachung und Warnungen**

📋 **Features:**
- 🚨 Temperatur > 30°C Alarm Counter
- ❄️ Temperatur < 10°C Alarm Counter
- 💧 Luftfeuchtigkeit Alarm (>80% oder <30%)
- 📡 Offline Sensoren Detection
- 🚨 Kritische Temperaturen Tabelle
- 📡 Offline Sensoren mit Zeitstempel
- 📈 Temperaturverlauf mit Alarm-Zonen

📐 **Layout:** Alarm-optimiert mit großen Status-Panels  
🔄 **Refresh:** 5 Sekunden (Live-Monitoring)  
⏰ **Zeitraum:** Letzte 30 Minuten

## 🚀 Installation der Dashboards

### Schritt 1: Dashboard importieren
```bash
# 1. Grafana öffnen: http://localhost:3000
# 2. Login: pi5admin / pi5sensors2024
# 3. + → Import → Upload JSON file
# 4. JSON-Datei auswählen und importieren
```

### Schritt 2: Datenquelle verknüpfen
```bash
# Beim Import wird automatisch nach der InfluxDB-Datenquelle gesucht
# Falls nicht automatisch erkannt:
# 1. Import-Dialog → "InfluxDB" aus Dropdown wählen
# 2. Oder: Dashboard → Settings → Variables → DS_INFLUXDB bearbeiten
```

### Schritt 3: Dashboard anpassen
```bash
# Optional: Dashboard-Einstellungen anpassen
# - Time Range ändern
# - Refresh-Intervall anpassen
# - Panel-Größen modifizieren
# - Farben/Schwellwerte anpassen
```

## 📦 Schnell-Import (Ein-Befehl)

### Mit curl direkt importieren:
```bash
# Hauptdashboard
curl -X POST http://pi5admin:pi5sensors2024@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana_dashboard_main.json

# Mobile Dashboard
curl -X POST http://pi5admin:pi5sensors2024@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana_dashboard_mobile.json

# Alarm Dashboard
curl -X POST http://pi5admin:pi5sensors2024@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana_dashboard_alarms.json
```

### Mit Python-Script:
```python
import requests
import json

# Grafana-Konfiguration
GRAFANA_URL = "http://localhost:3000"
GRAFANA_USER = "pi5admin"
GRAFANA_PASS = "pi5sensors2024"

def import_dashboard(json_file):
    with open(json_file, 'r') as f:
        dashboard_json = json.load(f)
    
    payload = {
        "dashboard": dashboard_json,
        "overwrite": True
    }
    
    response = requests.post(
        f"{GRAFANA_URL}/api/dashboards/db",
        auth=(GRAFANA_USER, GRAFANA_PASS),
        headers={"Content-Type": "application/json"},
        json=payload
    )
    
    if response.status_code == 200:
        print(f"✅ {json_file} erfolgreich importiert")
    else:
        print(f"❌ Fehler beim Import von {json_file}: {response.text}")

# Alle Dashboards importieren
dashboards = [
    "grafana_dashboard_main.json",
    "grafana_dashboard_mobile.json", 
    "grafana_dashboard_alarms.json"
]

for dashboard in dashboards:
    import_dashboard(dashboard)
```

## 🎨 Dashboard-Anpassungen

### Farben und Themes
```json
// Standard-Farbschema (in JSON editierbar):
{
  "thresholds": {
    "steps": [
      {"color": "blue", "value": null},     // Kalt
      {"color": "green", "value": 18},      // Normal
      {"color": "yellow", "value": 25},     // Warm
      {"color": "red", "value": 30}         // Heiß
    ]
  }
}
```

### Schwellwerte anpassen
```json
// Alarm-Schwellwerte (editierbar):
{
  "temperatur_alarm_hoch": 30,    // °C
  "temperatur_alarm_niedrig": 10, // °C
  "luftfeuchtigkeit_max": 80,     // %
  "luftfeuchtigkeit_min": 30,     // %
  "sensor_offline_timeout": 120   // Sekunden
}
```

### Refresh-Intervalle
```json
// Pro Dashboard anpassbar:
{
  "refresh": "30s",               // Hauptdashboard
  "refresh": "10s",               // Mobile Dashboard  
  "refresh": "5s"                 // Alarm Dashboard
}
```

## 🔧 Erweiterte Konfiguration

### Variables (Template-Variablen)
```bash
# Bereits konfigurierte Variablen:
$DS_INFLUXDB     # Datenquelle
$sensor_type     # Sensor-Typ Filter (DS18B20, DHT22)

# Verwendung in Queries:
filter(fn: (r) => r["sensor_type"] == "$sensor_type")
```

### Custom Queries hinzufügen
```flux
// Beispiel: Temperatur-Trend (letzte 24h)
from(bucket: "sensor_data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "temperature")
  |> filter(fn: (r) => r["_field"] == "temperature_celsius")
  |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
  |> derivative(unit: 1h)
```

### Alert Rules (Grafana Alerting)
```bash
# Alarm-Regeln konfigurieren:
# 1. Dashboard → Panel → Alert tab
# 2. Create Alert Rule
# 3. Bedingung: _value > 30 (Temperatur)
# 4. Notification: E-Mail/Webhook

# Beispiel-Bedingung:
WHEN last() OF query(A, 5m, now) IS ABOVE 30
```

## 📱 Mobile Optimierung

### Responsive Design
```bash
# Mobile Dashboard Features:
- Große Touch-Targets
- Vereinfachte Navigation
- Schnelle Ladezeiten (10s Refresh)
- Wichtigste Infos zuerst
- Vertikales Scrolling optimiert
```

### PWA-Support (Progressive Web App)
```bash
# Grafana als PWA nutzen:
# 1. Chrome/Safari → localhost:3000
# 2. "Zum Startbildschirm hinzufügen"
# 3. Native App-ähnliche Erfahrung
```

## 🔍 Troubleshooting

### Dashboard lädt nicht
```bash
# 1. Datenquelle prüfen:
curl -I http://localhost:8086/health

# 2. Grafana-Container prüfen:
docker compose logs grafana

# 3. Dashboard-Variables prüfen:
# Settings → Variables → DS_INFLUXDB
```

### Keine Daten sichtbar
```bash
# 1. Zeitraum prüfen (Time Range)
# 2. Daten in InfluxDB vorhanden?
python sensor_influxdb.py test

# 3. Query debuggen:
# Panel → Query → Query Inspector
```

### Performance-Probleme
```bash
# 1. Zeitraum reduzieren (1h statt 24h)
# 2. Refresh-Intervall erhöhen (30s → 1m)
# 3. Aggregation verwenden:
aggregateWindow(every: 5m, fn: mean)
```

## 🎯 Verwendungsszenarien

### 🏠 **Heimautomatisierung**
- Hauptdashboard auf großem Monitor
- Mobile Dashboard für unterwegs
- Alarm Dashboard für kritische Überwachung

### 🏭 **Industrielle Überwachung**
- 24/7 Monitoring mit Alarm Dashboard
- Historische Trends mit Hauptdashboard
- Mobile Wartungstechniker-Access

### 🔬 **Labor/Forschung**
- Präzise Temperaturverfolgung
- Datenexport für Analyse
- Alarm bei kritischen Werten

## 📊 Export/Import zwischen Grafana-Instanzen

```bash
# Dashboard exportieren:
# Dashboard → Share → Export → Save to file

# Dashboard-URL teilen:
# Dashboard → Share → Link → Copy link

# Programmatischer Export:
curl -u pi5admin:pi5sensors2024 \
  http://localhost:3000/api/dashboards/uid/pi5-sensor-main > backup.json
```

---

**🎨 Professionelle Dashboards für enterprise-grade IoT-Monitoring auf Raspberry Pi 5**

*Entwickelt für optimale Visualisierung der 6x DS18B20 + 1x DHT22 Sensor-Daten*
