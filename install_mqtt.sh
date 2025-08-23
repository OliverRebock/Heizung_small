#!/bin/bash
# MQTT Broker Installation für Raspberry Pi 5
# Installiert Mosquitto MQTT Broker und Python MQTT Client

echo "🦟 MQTT Broker Installation für Pi5 Heizungs Messer"
echo "=================================================="

# =============================================================================
# 1. SYSTEM UPDATE
# =============================================================================
echo "📦 System Update..."
sudo apt update && sudo apt upgrade -y

# =============================================================================
# 2. MOSQUITTO MQTT BROKER INSTALLIEREN
# =============================================================================
echo "🦟 Installiere Mosquitto MQTT Broker..."
sudo apt install mosquitto mosquitto-clients -y

# =============================================================================
# 3. MOSQUITTO KONFIGURATION
# =============================================================================
echo "⚙️ Konfiguriere Mosquitto..."

# Backup der Original-Config
sudo cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup

# Neue Konfiguration
sudo tee /etc/mosquitto/mosquitto.conf > /dev/null << 'EOF'
# Mosquitto MQTT Broker Konfiguration für Pi5 Heizungs Messer

# Basis-Einstellungen
pid_file /run/mosquitto/mosquitto.pid
persistence true
persistence_location /var/lib/mosquitto/

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information

# Network Settings
port 1883
max_connections 1000

# Security (Basic - für lokales Netzwerk)
allow_anonymous true

# WebSocket Support (optional für Web-Clients)
listener 9001
protocol websockets

# Retain Messages
retain_available true

# QoS Settings
max_queued_messages 1000
message_size_limit 268435456
EOF

# =============================================================================
# 4. MOSQUITTO AUTOSTART AKTIVIEREN
# =============================================================================
echo "🚀 Aktiviere Mosquitto Autostart..."
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# =============================================================================
# 5. PYTHON MQTT DEPENDENCIES
# =============================================================================
echo "🐍 Installiere Python MQTT Dependencies..."

# Python Virtual Environment verwenden (falls vorhanden)
if [ -d "~/pi5-sensors/venv" ]; then
    echo "   📂 Verwende existierendes venv..."
    cd ~/pi5-sensors
    source venv/bin/activate
    pip install paho-mqtt
else
    echo "   📂 Installiere system-wide..."
    sudo apt install python3-pip -y
    pip3 install paho-mqtt
fi

# =============================================================================
# 6. FIREWALL KONFIGURATION (falls aktiv)
# =============================================================================
echo "🔥 Konfiguriere Firewall (falls aktiv)..."
if sudo ufw status | grep -q "Status: active"; then
    echo "   🔓 Öffne MQTT Ports..."
    sudo ufw allow 1883/tcp comment "MQTT"
    sudo ufw allow 9001/tcp comment "MQTT WebSocket"
else
    echo "   ⚠️ UFW Firewall nicht aktiv"
fi

# =============================================================================
# 7. TEST MQTT BROKER
# =============================================================================
echo "🧪 Teste MQTT Broker..."

# Status prüfen
if sudo systemctl is-active --quiet mosquitto; then
    echo "   ✅ Mosquitto läuft"
    
    # Quick Test
    echo "   🔄 Teste MQTT Kommunikation..."
    
    # Test Message senden (im Hintergrund)
    mosquitto_pub -h localhost -t "test/pi5" -m "MQTT Broker funktioniert!" &
    sleep 1
    
    # Test Message empfangen
    timeout 3 mosquitto_sub -h localhost -t "test/pi5" -C 1 | head -1
    
    if [ $? -eq 0 ]; then
        echo "   ✅ MQTT Test erfolgreich!"
    else
        echo "   ⚠️ MQTT Test fehlgeschlagen - prüfe Konfiguration"
    fi
else
    echo "   ❌ Mosquitto startet nicht - prüfe Logs:"
    sudo journalctl -u mosquitto --no-pager -n 10
fi

# =============================================================================
# 8. INFORMATIONEN
# =============================================================================
echo ""
echo "✅ MQTT Broker Installation abgeschlossen!"
echo ""
echo "📋 MQTT Broker Informationen:"
echo "   🌐 Broker IP: $(hostname -I | awk '{print $1}')"
echo "   🔌 MQTT Port: 1883"
echo "   🌐 WebSocket Port: 9001"
echo "   🔐 Authentifizierung: Keine (allow_anonymous)"
echo ""
echo "🔧 Wichtige Befehle:"
echo "   sudo systemctl status mosquitto    # Status prüfen"
echo "   sudo systemctl restart mosquitto   # Neustart"
echo "   mosquitto_pub -h localhost -t 'test' -m 'message'   # Test senden"
echo "   mosquitto_sub -h localhost -t 'test'                # Test empfangen"
echo ""
echo "📁 Log-Dateien:"
echo "   /var/log/mosquitto/mosquitto.log   # MQTT Broker Logs"
echo "   sudo journalctl -u mosquitto -f    # Live Logs"
echo ""
echo "🏠 Home Assistant Konfiguration:"
echo "   mqtt:"
echo "     broker: $(hostname -I | awk '{print $1}')"
echo "     port: 1883"
echo ""
echo "🎯 Nächster Schritt: MQTT → Home Assistant Bridge Script erstellen"
