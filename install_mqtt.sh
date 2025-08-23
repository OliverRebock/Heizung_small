#!/bin/bash
# MQTT Broker Installation für Raspberry Pi 5
# Installiert Mosquitto MQTT Broker und Python MQTT Client

echo "🏠 Pi5 Heizungs Messer - MQTT Broker Installation für Home Assistant"
echo "=================================================================="

# Interaktive Konfiguration
echo ""
echo "📋 MQTT Konfiguration"
echo "===================="

# Home Assistant IP abfragen
echo ""
echo "🏠 Home Assistant Konfiguration:"
read -p "   IP-Adresse deines Home Assistant (z.B. 192.168.1.100): " HA_IP
if [ -z "$HA_IP" ]; then
    HA_IP="192.168.1.100"
    echo "   → Standard verwendet: $HA_IP"
fi

# MQTT Authentifizierung abfragen
echo ""
echo "🔐 MQTT Authentifizierung:"
read -p "   Brauchst du MQTT Username/Passwort? [j/N]: " NEED_AUTH
NEED_AUTH=${NEED_AUTH:-n}

if [[ $NEED_AUTH =~ ^[Jj] ]]; then
    read -p "   MQTT Username: " MQTT_USER
    read -s -p "   MQTT Passwort: " MQTT_PASS
    echo ""
    USE_AUTH=true
else
    MQTT_USER=""
    MQTT_PASS=""
    USE_AUTH=false
    echo "   → Keine Authentifizierung verwendet"
fi

# Pi5 IP automatisch ermitteln
PI5_IP=$(hostname -I | awk '{print $1}')

# Bestätigung
echo ""
echo "✅ Konfiguration:"
echo "   🏠 Home Assistant IP: $HA_IP"
echo "   🤖 Pi5 IP (MQTT Broker): $PI5_IP"
echo "   🔐 MQTT Auth: $([ "$USE_AUTH" = true ] && echo "Ja ($MQTT_USER)" || echo "Nein")"
echo ""
read -p "Fortfahren? [J/n]: " CONFIRM
CONFIRM=${CONFIRM:-j}
if [[ ! $CONFIRM =~ ^[Jj] ]]; then
    echo "❌ Installation abgebrochen"
    exit 1
fi

# =============================================================================
# 1. SYSTEM UPDATE
# =============================================================================
echo ""
echo "📦 System Update..."
sudo apt update && sudo apt upgrade -y

# =============================================================================
# 2. MOSQUITTO MQTT BROKER INSTALLIEREN
# =============================================================================
echo ""
echo "🦟 Installiere Mosquitto MQTT Broker..."
sudo apt install mosquitto mosquitto-clients -y

# =============================================================================
# 3. MOSQUITTO KONFIGURATION
# =============================================================================
echo ""
echo "⚙️ Konfiguriere Mosquitto..."

# Backup der Original-Config
sudo cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup

# Mosquitto Konfiguration basierend auf Auth-Einstellungen
if [ "$USE_AUTH" = true ]; then
    echo "🔐 Erstelle Mosquitto Konfiguration mit Authentifizierung..."
    
    # Passwort-Datei erstellen
    sudo mosquitto_passwd -c -b /etc/mosquitto/passwd "$MQTT_USER" "$MQTT_PASS"
    
    # Konfiguration mit Auth
    sudo tee /etc/mosquitto/mosquitto.conf > /dev/null << EOF
# Mosquitto MQTT Broker Konfiguration für Pi5 Heizungs Messer
# Konfiguration: MIT Authentifizierung

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
listener 1883
protocol mqtt

# WebSocket für Home Assistant (optional)
listener 9001
protocol websockets

# Security - MIT Authentifizierung
allow_anonymous false
password_file /etc/mosquitto/passwd

# Connection Settings
max_connections 1000
connection_messages true
log_timestamp true
EOF

else
    echo "🔓 Erstelle Mosquitto Konfiguration ohne Authentifizierung..."
    
    # Konfiguration ohne Auth
    sudo tee /etc/mosquitto/mosquitto.conf > /dev/null << EOF
# Mosquitto MQTT Broker Konfiguration für Pi5 Heizungs Messer  
# Konfiguration: OHNE Authentifizierung (lokales Netzwerk)

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
listener 1883
protocol mqtt

# WebSocket für Home Assistant (optional)
listener 9001
protocol websockets

# Security - OHNE Authentifizierung
allow_anonymous true

# Connection Settings
max_connections 1000
connection_messages true
log_timestamp true
EOF

fi

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
# 8. KONFIGURATIONSDATEI FÜR MQTT BRIDGE ERSTELLEN
# =============================================================================
echo ""
echo "⚙️ Erstelle MQTT Bridge Konfiguration..."

# MQTT Bridge Config erstellen
if [ -d "/home/pi/pi5-sensors" ]; then
    CONFIG_FILE="/home/pi/pi5-sensors/config.ini"
else
    CONFIG_FILE="./mqtt_config.ini"
fi

# Erstelle Konfigurationsdatei mit Benutzer-Einstellungen
cat > "$CONFIG_FILE" << EOF
# Pi5 Heizungs Messer - MQTT Bridge Konfiguration
# ================================================

[mqtt]
# MQTT Broker Einstellungen (dein Pi5)
broker = $PI5_IP
port = 1883
username = $MQTT_USER
password = $MQTT_PASS
topic_prefix = pi5_heizung

[homeassistant]
# Home Assistant Einstellungen
ip = $HA_IP
mqtt_discovery = true

[database]
# InfluxDB Einstellungen (lokal auf Pi5)
host = localhost
port = 8086
token = pi5-token-2024
org = pi5org
bucket = sensors

[labels]
# Sensor Labels (ID = Anzeigename)
# Diese müssen exakt mit den Namen in InfluxDB übereinstimmen!
28-0000000001 = HK1 Vorlauf
28-0000000002 = HK1 Rücklauf
28-0000000003 = HK2 Vorlauf
28-0000000004 = HK2 Rücklauf
28-0000000005 = HK3 Vorlauf
28-0000000006 = HK3 Rücklauf
28-0000000007 = HK4 Vorlauf
28-0000000008 = HK4 Rücklauf
dht22 = Heizraum Klima
EOF

echo "   ✅ Konfiguration erstellt: $CONFIG_FILE"

# =============================================================================
# 9. INFORMATIONEN
# =============================================================================
echo ""
echo "✅ MQTT Broker Installation abgeschlossen!"
echo ""
echo "📋 MQTT Broker Informationen:"
echo "   🌐 Broker IP: $PI5_IP"
echo "   🔌 MQTT Port: 1883"  
echo "   🌐 WebSocket Port: 9001"
if [ "$USE_AUTH" = true ]; then
    echo "   🔐 Authentifizierung: Ja ($MQTT_USER)"
    echo "       → Username: $MQTT_USER"
    echo "       → Passwort: $MQTT_PASS"
else
    echo "   🔐 Authentifizierung: Nein (allow_anonymous)"
fi
echo ""
echo "🏠 Home Assistant Integration:"
echo "   🎯 HA IP-Adresse: $HA_IP"
echo "   📡 MQTT Broker IP: $PI5_IP:1883"
echo ""
echo "🔧 Wichtige Befehle:"
echo "   sudo systemctl status mosquitto    # Status prüfen"
echo "   sudo systemctl restart mosquitto   # Neustart"
if [ "$USE_AUTH" = true ]; then
    echo "   mosquitto_pub -h localhost -u $MQTT_USER -P $MQTT_PASS -t 'test' -m 'message'   # Test senden"
    echo "   mosquitto_sub -h localhost -u $MQTT_USER -P $MQTT_PASS -t 'test'                # Test empfangen"
else
    echo "   mosquitto_pub -h localhost -t 'test' -m 'message'   # Test senden"
    echo "   mosquitto_sub -h localhost -t 'test'                # Test empfangen"
fi
echo ""
echo "📁 Log-Dateien:"
echo "   /var/log/mosquitto/mosquitto.log   # MQTT Broker Logs"
echo "   sudo journalctl -u mosquitto -f    # Live Logs"
echo ""
echo "🏠 Home Assistant MQTT Konfiguration (configuration.yaml):"
echo "   mqtt:"
echo "     broker: $PI5_IP"
echo "     port: 1883"
if [ "$USE_AUTH" = true ]; then
    echo "     username: $MQTT_USER"
    echo "     password: $MQTT_PASS"
fi
echo "     discovery: true"
echo ""
echo "🎯 Nächster Schritt:"
echo "   bash setup_mqtt_service.sh    # MQTT Bridge Service installieren"
echo ""
echo "📝 Konfiguration gespeichert in: $CONFIG_FILE"
