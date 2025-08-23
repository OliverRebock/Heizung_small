#!/bin/bash

# 🚨 MQTT Import Error Fix
# Problem: ModuleNotFoundError: No module named 'mqtt_bridge'
# Lösung: Umgebung und Imports reparieren

set -e

echo "🚨 MQTT Import Error Fix gestartet..."
echo "========================================"

# Prüfe aktuelles Verzeichnis
echo "📁 Aktuelles Verzeichnis: $(pwd)"
echo "📁 Inhalt:"
ls -la

# Prüfe ob mqtt_bridge.py existiert
if [ ! -f "mqtt_bridge.py" ]; then
    echo "❌ mqtt_bridge.py nicht gefunden!"
    echo "💾 Lade mqtt_bridge.py von GitHub..."
    wget -q https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/mqtt_bridge.py
    if [ $? -eq 0 ]; then
        echo "✅ mqtt_bridge.py heruntergeladen"
    else
        echo "❌ Download fehlgeschlagen - prüfe Internet-Verbindung"
        exit 1
    fi
else
    echo "✅ mqtt_bridge.py gefunden"
fi

# Prüfe Python venv
if [ ! -d "venv" ]; then
    echo "❌ Python venv nicht gefunden!"
    echo "🔧 Erstelle neues venv..."
    python3 -m venv venv
    echo "✅ venv erstellt"
else
    echo "✅ Python venv gefunden"
fi

# Aktiviere venv und installiere Abhängigkeiten
echo "🔧 Aktiviere Python venv..."
source venv/bin/activate

echo "📦 Installiere MQTT Abhängigkeiten..."
pip install paho-mqtt configparser influxdb-client > /dev/null 2>&1

# Prüfe ob mqtt_bridge importiert werden kann
echo "🧪 Teste mqtt_bridge Import..."
python3 -c "
import sys
sys.path.append('.')
try:
    import mqtt_bridge
    print('✅ mqtt_bridge Import erfolgreich')
except Exception as e:
    print(f'❌ Import Fehler: {e}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ mqtt_bridge Import immer noch fehlerhaft"
    echo "🔍 Diagnose-Informationen:"
    echo "Python Version: $(python3 --version)"
    echo "Python Path:"
    python3 -c "import sys; print('\n'.join(sys.path))"
    echo "Installierte Pakete:"
    pip list | grep -E "(paho|mqtt|influx)"
    exit 1
fi

echo ""
echo "✅ MQTT Import Error behoben!"
echo "🔧 Jetzt kannst du fix_config_mqtt.sh erneut ausführen"
echo ""
echo "📋 Alternativ: MQTT Test direkt ausführen"
echo "python3 mqtt_bridge.py discovery"
