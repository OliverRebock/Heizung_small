#!/bin/bash
# MQTT Verbindungstest für Pi5 Heizungs Messer
# ===========================================

echo "🧪 MQTT Verbindungstest"
echo "======================="

# Konfiguration laden
CONFIG_FILE="/home/pi/pi5-sensors/config.ini"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="./mqtt_config.ini"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Konfigurationsdatei nicht gefunden!"
    echo "   Führe zuerst install_mqtt.sh aus"
    exit 1
fi

# Werte aus Config lesen
BROKER=$(grep "^broker" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
PORT=$(grep "^port" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
USERNAME=$(grep "^username" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
PASSWORD=$(grep "^password" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')

echo "📋 MQTT Konfiguration:"
echo "   Broker: $BROKER:$PORT"
if [ -n "$USERNAME" ]; then
    echo "   Auth: $USERNAME / ***"
    AUTH_PARAMS="-u $USERNAME -P $PASSWORD"
else
    echo "   Auth: Keine"
    AUTH_PARAMS=""
fi

echo ""
echo "🔄 Teste MQTT Verbindung..."

# 1. Mosquitto Service Status
echo ""
echo "1. 🦟 Mosquitto Service Status:"
if systemctl is-active --quiet mosquitto; then
    echo "   ✅ Mosquitto läuft"
else
    echo "   ❌ Mosquitto läuft nicht!"
    echo "   Starte Mosquitto..."
    sudo systemctl start mosquitto
    sleep 2
fi

# 2. Port Test
echo ""
echo "2. 🔌 Port Test:"
if nc -z "$BROKER" "$PORT" 2>/dev/null; then
    echo "   ✅ Port $PORT ist erreichbar"
else
    echo "   ❌ Port $PORT ist nicht erreichbar!"
    echo "   Prüfe Firewall und Mosquitto Konfiguration"
fi

# 3. MQTT Publish Test
echo ""
echo "3. 📤 MQTT Publish Test:"
TEST_TOPIC="pi5_heizung/test"
TEST_MESSAGE="Test von $(date)"

if mosquitto_pub -h "$BROKER" -p "$PORT" $AUTH_PARAMS -t "$TEST_TOPIC" -m "$TEST_MESSAGE" 2>/dev/null; then
    echo "   ✅ Publish erfolgreich"
else
    echo "   ❌ Publish fehlgeschlagen!"
fi

# 4. MQTT Subscribe Test  
echo ""
echo "4. 📥 MQTT Subscribe Test:"
echo "   Sende Test-Nachricht und höre mit..."

# Subscribe im Hintergrund starten
timeout 5 mosquitto_sub -h "$BROKER" -p "$PORT" $AUTH_PARAMS -t "$TEST_TOPIC" -C 1 > /tmp/mqtt_test.log 2>&1 &
SUBSCRIBE_PID=$!

# Kurz warten, dann Nachricht senden
sleep 1
mosquitto_pub -h "$BROKER" -p "$PORT" $AUTH_PARAMS -t "$TEST_TOPIC" -m "Subscribe Test $(date)" 2>/dev/null

# Auf Subscribe warten
wait $SUBSCRIBE_PID 2>/dev/null

if [ -s /tmp/mqtt_test.log ]; then
    echo "   ✅ Subscribe erfolgreich"
    echo "   📨 Empfangen: $(cat /tmp/mqtt_test.log)"
else
    echo "   ❌ Subscribe fehlgeschlagen!"
fi

# 5. Home Assistant Topics Test
echo ""
echo "5. 🏠 Home Assistant Discovery Test:"
DISCOVERY_TOPIC="homeassistant/sensor/pi5_heizung_test/config"
DISCOVERY_PAYLOAD='{"name":"Pi5 Test Sensor","unique_id":"pi5_test","state_topic":"pi5_heizung/test/state"}'

if mosquitto_pub -h "$BROKER" -p "$PORT" $AUTH_PARAMS -t "$DISCOVERY_TOPIC" -m "$DISCOVERY_PAYLOAD" -r 2>/dev/null; then
    echo "   ✅ Discovery Topic erfolgreich"
else
    echo "   ❌ Discovery Topic fehlgeschlagen!"
fi

# 6. Live Topic Monitor
echo ""
echo "6. 📡 Live Topic Monitor (10 Sekunden):"
echo "   Überwache alle pi5_heizung Topics..."
echo "   Drücke Ctrl+C zum Beenden"

timeout 10 mosquitto_sub -h "$BROKER" -p "$PORT" $AUTH_PARAMS -t "pi5_heizung/+/+" -v 2>/dev/null || echo "   ⏰ Timeout - keine Nachrichten empfangen"

# Cleanup
rm -f /tmp/mqtt_test.log

echo ""
echo "🏁 MQTT Test abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "   1. Starte MQTT Bridge: sudo systemctl start pi5-mqtt-bridge"
echo "   2. Überwache Topics: mosquitto_sub -h $BROKER -p $PORT $AUTH_PARAMS -t 'pi5_heizung/+/state' -v"
echo "   3. Home Assistant MQTT Integration konfigurieren"
