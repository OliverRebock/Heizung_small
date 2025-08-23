#!/bin/bash
# Quick Fix für MQTT Bridge - Broker Adresse korrigieren
# ====================================================

echo "🔧 MQTT Bridge Broker Fix"
echo "========================="

CONFIG_FILE="/home/pi/pi5-sensors/config.ini"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Konfigurationsdatei nicht gefunden: $CONFIG_FILE"
    echo "   Führe zuerst install_mqtt.sh aus"
    exit 1
fi

# Aktuelle Konfiguration anzeigen
echo ""
echo "📋 Aktuelle MQTT Konfiguration:"
grep -A 5 "\[mqtt\]" "$CONFIG_FILE"

echo ""
echo "🔧 Broker Adresse korrigieren:"
echo "   1) Home Assistant MQTT Broker verwenden"
echo "   2) Pi5 als lokaler MQTT Broker"
read -p "   Wähle Option [1/2]: " OPTION

if [ "$OPTION" = "1" ]; then
    echo ""
    read -p "🏠 Home Assistant IP-Adresse: " HA_IP
    read -p "🔐 MQTT Username: " MQTT_USER
    read -s -p "🔐 MQTT Passwort: " MQTT_PASS
    echo ""
    
    # Konfiguration anpassen
    sed -i "s/^broker = .*/broker = $HA_IP/" "$CONFIG_FILE"
    sed -i "s/^username = .*/username = $MQTT_USER/" "$CONFIG_FILE"
    sed -i "s/^password = .*/password = $MQTT_PASS/" "$CONFIG_FILE"
    
    echo "✅ MQTT Bridge konfiguriert für Home Assistant ($HA_IP)"
    
else
    PI5_IP=$(hostname -I | awk '{print $1}')
    
    # Konfiguration anpassen
    sed -i "s/^broker = .*/broker = $PI5_IP/" "$CONFIG_FILE"
    
    echo "✅ MQTT Bridge konfiguriert für lokalen Pi5 Broker ($PI5_IP)"
fi

echo ""
echo "📋 Neue MQTT Konfiguration:"
grep -A 5 "\[mqtt\]" "$CONFIG_FILE"

echo ""
echo "🔄 MQTT Bridge Service neu starten..."
sudo systemctl restart pi5-mqtt-bridge

echo ""
echo "📊 Service Status:"
sudo systemctl status pi5-mqtt-bridge --no-pager -l

echo ""
echo "✅ MQTT Bridge Broker Fix abgeschlossen!"
echo ""
echo "🧪 Test mit:"
echo "   bash test_mqtt.sh"
echo "   sudo journalctl -u pi5-mqtt-bridge -f"
