#!/bin/bash
# Test Home Assistant Auto-Discovery
# ===================================

echo "🏠 Home Assistant Auto-Discovery Test"
echo "====================================="

# Prüfe ob pi5-sensors existiert
if [ ! -d "$HOME/pi5-sensors" ]; then
    echo "❌ pi5-sensors nicht gefunden!"
    exit 1
fi

cd "$HOME/pi5-sensors"

# Config prüfen
if [ ! -f "config.ini" ]; then
    echo "❌ config.ini nicht gefunden!"
    exit 1
fi

# MQTT Einstellungen aus config.ini lesen
MQTT_BROKER=$(grep "broker = " config.ini | cut -d' ' -f3)
MQTT_USER=$(grep "username = " config.ini | cut -d' ' -f3)
MQTT_PASS=$(grep "password = " config.ini | cut -d' ' -f3)

echo "📋 MQTT Konfiguration:"
echo "   Broker: $MQTT_BROKER:1883"
echo "   User: $MQTT_USER"
echo ""

# MQTT Verbindung testen
echo "🔌 Teste MQTT Verbindung..."
timeout 5 mosquitto_pub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/test" -m "test" && {
    echo "✅ MQTT Verbindung OK"
} || {
    echo "❌ MQTT Verbindung fehlgeschlagen!"
    echo "   Prüfe Home Assistant MQTT Broker Einstellungen"
    exit 1
}

# Auto-Discovery senden
echo ""
echo "🏠 Sende Auto-Discovery an Home Assistant..."
source venv/bin/activate
python mqtt_bridge.py discovery

echo ""
echo "📡 Discovery-Topics prüfen..."
timeout 5 mosquitto_sub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t 'homeassistant/sensor/pi5_heizung_+/config' -C 1 && {
    echo "✅ Discovery-Topics werden gesendet"
} || {
    echo "⚠️ Keine Discovery-Topics empfangen"
}

echo ""
echo "📊 Test-Daten senden..."
python mqtt_bridge.py mqtt-test

echo ""
echo "🎯 Prüfe jetzt in Home Assistant:"
echo "   Settings → Devices & Services → MQTT"
echo "   Suche nach 'Pi5 Heizungs Messer'"
echo ""
echo "🔧 MQTT Topics live anschauen:"
echo "   mosquitto_sub -h $MQTT_BROKER -u $MQTT_USER -P '$MQTT_PASS' -t 'homeassistant/+/+/+/config' -v"
echo "   mosquitto_sub -h $MQTT_BROKER -u $MQTT_USER -P '$MQTT_PASS' -t 'pi5_heizung/+/state' -v"
