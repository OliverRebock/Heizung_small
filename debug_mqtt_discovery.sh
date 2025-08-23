#!/bin/bash
# Debug Home Assistant MQTT Discovery
# ===================================

echo "🏠 Home Assistant MQTT Discovery Debug"
echo "======================================"

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
timeout 5 mosquitto_pub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/debug" -m "connection_test" && {
    echo "✅ MQTT Verbindung OK"
} || {
    echo "❌ MQTT Verbindung fehlgeschlagen!"
    exit 1
}

echo ""
echo "🧪 Sende Discovery-Nachrichten manuell..."

# Manuelle Discovery für einen Test-Sensor
DISCOVERY_TOPIC="homeassistant/sensor/pi5_heizung_ds18b20_1/config"
STATE_TOPIC="pi5_heizung/ds18b20_1/state"

DISCOVERY_PAYLOAD='{
  "name": "RL WP",
  "unique_id": "pi5_heizung_ds18b20_1",
  "state_topic": "'$STATE_TOPIC'",
  "device_class": "temperature",
  "unit_of_measurement": "°C",
  "value_template": "{{ value_json.temperature }}",
  "device": {
    "identifiers": ["pi5_heizungs_messer"],
    "name": "Pi5 Heizungs Messer",
    "model": "Raspberry Pi 5",
    "manufacturer": "Pi5 Heizung Project",
    "sw_version": "1.0.0"
  },
  "availability": [
    {
      "topic": "pi5_heizung/status",
      "payload_available": "online",
      "payload_not_available": "offline"
    }
  ],
  "icon": "mdi:thermometer"
}'

echo "📡 Sende Discovery für Test-Sensor..."
echo "   Topic: $DISCOVERY_TOPIC"
echo "   Payload: $DISCOVERY_PAYLOAD"

mosquitto_pub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$DISCOVERY_TOPIC" -m "$DISCOVERY_PAYLOAD" -r

echo ""
echo "📊 Sende Status und Test-Daten..."
mosquitto_pub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/status" -m "online" -r
mosquitto_pub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$STATE_TOPIC" -m '{"temperature": 21.5}'

echo ""
echo "🔍 Prüfe Topics in Home Assistant..."
echo "   Discovery Topic: $DISCOVERY_TOPIC"
echo "   State Topic: $STATE_TOPIC"

# Topics anzeigen
echo ""
echo "📡 Live MQTT Topics (5 Sekunden):"
timeout 5 mosquitto_sub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t 'homeassistant/sensor/pi5_heizung_+/config' -v || echo "Keine Discovery Topics empfangen"

echo ""
echo "📊 Live State Topics (5 Sekunden):"
timeout 5 mosquitto_sub -h "$MQTT_BROKER" -u "$MQTT_USER" -P "$MQTT_PASS" -t 'pi5_heizung/+/state' -v || echo "Keine State Topics empfangen"

echo ""
echo "🏠 Home Assistant Discovery Troubleshooting:"
echo "1. Gehe zu Settings → Devices & Services → MQTT"
echo "2. Klicke auf 'Configure' bei MQTT"
echo "3. Schaue unter 'Discovered' nach 'Pi5 Heizungs Messer'"
echo "4. Falls nicht da, prüfe Home Assistant Logs"
echo ""
echo "🔧 Home Assistant Discovery manuell triggern:"
echo "   Developer Tools → Services → mqtt.reload → Call Service"
echo ""
echo "📋 Manuell prüfen:"
echo "   mosquitto_sub -h $MQTT_BROKER -u $MQTT_USER -P '$MQTT_PASS' -t 'homeassistant/+/+/+/config' -v"
