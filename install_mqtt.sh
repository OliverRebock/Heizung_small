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

# MQTT Setup Methode auswählen
echo ""
echo "📡 MQTT Setup Methode:"
echo "   1) Home Assistant MQTT Broker verwenden (empfohlen)"
echo "   2) Pi5 als MQTT Broker einrichten"
read -p "   Wähle Methode [1/2]: " MQTT_METHOD
MQTT_METHOD=${MQTT_METHOD:-1}

if [ "$MQTT_METHOD" = "1" ]; then
    echo "   → Verwende Home Assistant MQTT Broker"
    USE_HA_BROKER=true
    
    # MQTT Authentifizierung für HA abfragen
    echo ""
    echo "🔐 Home Assistant MQTT Authentifizierung:"
    read -p "   MQTT Username für Home Assistant: " MQTT_USER
    read -s -p "   MQTT Passwort für Home Assistant: " MQTT_PASS
    echo ""
    
    MQTT_BROKER_IP="$HA_IP"
    INSTALL_LOCAL_BROKER=false
    
else
    echo "   → Richte Pi5 als MQTT Broker ein"
    USE_HA_BROKER=false
    
    # MQTT Authentifizierung abfragen
    echo ""
    echo "🔐 MQTT Authentifizierung für Pi5 Broker:"
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
    
    MQTT_BROKER_IP=$(hostname -I | awk '{print $1}')
    INSTALL_LOCAL_BROKER=true
fi

# Bestätigung
echo ""
echo "✅ Konfiguration:"
echo "   🏠 Home Assistant IP: $HA_IP"
if [ "$USE_HA_BROKER" = true ]; then
    echo "   📡 MQTT Broker: Home Assistant ($HA_IP:1883)"
    echo "   🔐 MQTT Auth: $MQTT_USER"
else
    echo "   📡 MQTT Broker: Pi5 ($MQTT_BROKER_IP:1883)"
    echo "   🔐 MQTT Auth: $([ "$USE_AUTH" = true ] && echo "Ja ($MQTT_USER)" || echo "Nein")"
fi
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

if [ "$INSTALL_LOCAL_BROKER" = true ]; then
    # =============================================================================
    # 2. MOSQUITTO MQTT BROKER INSTALLIEREN (nur wenn Pi5 als Broker)
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

    # =============================================================================
    # 4. MOSQUITTO AUTOSTART AKTIVIEREN
    # =============================================================================
    echo ""
    echo "🚀 Aktiviere Mosquitto Autostart..."
    sudo systemctl enable mosquitto
    sudo systemctl start mosquitto

    # =============================================================================
    # 5. FIREWALL KONFIGURATION (falls aktiv)
    # =============================================================================
    echo ""
    echo "🔥 Konfiguriere Firewall (falls aktiv)..."
    if sudo ufw status | grep -q "Status: active"; then
        echo "   🔓 Öffne MQTT Ports..."
        sudo ufw allow 1883/tcp comment "MQTT"
        sudo ufw allow 9001/tcp comment "MQTT WebSocket"
    else
        echo "   ⚠️ UFW Firewall nicht aktiv"
    fi

else
    # =============================================================================
    # 2. MQTT CLIENT TOOLS INSTALLIEREN (für Home Assistant Broker)
    # =============================================================================
    echo ""
    echo "📡 Installiere MQTT Client Tools..."
    sudo apt install mosquitto-clients -y
    echo "   ✅ Pi5 wird als MQTT Client zu Home Assistant konfiguriert"
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
# 6. PYTHON MQTT DEPENDENCIES
# =============================================================================
echo ""
echo "🐍 Installiere Python MQTT Dependencies..."

# Python Virtual Environment verwenden (falls vorhanden)
if [ -d "/home/pi/pi5-sensors/venv" ]; then
    echo "   📂 Verwende existierendes venv..."
    cd /home/pi/pi5-sensors
    source venv/bin/activate
    pip install paho-mqtt influxdb-client
else
    echo "   📂 Installiere system-wide..."
    sudo apt install python3-pip -y
    pip3 install paho-mqtt influxdb-client
fi

# =============================================================================
# 7. KONFIGURATIONSDATEI FÜR MQTT BRIDGE ERSTELLEN
# =============================================================================
echo ""
echo "⚙️ Erstelle MQTT Bridge Konfiguration..."

# MQTT Bridge Config erstellen
if [ -d "/home/pi/pi5-sensors" ]; then
    CONFIG_FILE="/home/pi/pi5-sensors/config.ini"
else
    CONFIG_FILE="./mqtt_config.ini"
fi

# Pi5 IP ermitteln
PI5_IP=$(hostname -I | awk '{print $1}')

# Erstelle Konfigurationsdatei mit Benutzer-Einstellungen
cat > "$CONFIG_FILE" << EOF
# Pi5 Heizungs Messer - MQTT Bridge Konfiguration
# ================================================

[mqtt]
# MQTT Broker Einstellungen
broker = $MQTT_BROKER_IP
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
# 8. MQTT VERBINDUNGSTEST
# =============================================================================
echo ""
echo "🧪 Teste MQTT Verbindung..."

if [ "$USE_HA_BROKER" = true ]; then
    echo "   📡 Teste Verbindung zu Home Assistant MQTT Broker..."
    
    # Test zu Home Assistant MQTT Broker
    if mosquitto_pub -h "$HA_IP" -p 1883 -u "$MQTT_USER" -P "$MQTT_PASS" -t "pi5_heizung/test" -m "Pi5 Test $(date)" 2>/dev/null; then
        echo "   ✅ MQTT Verbindung zu Home Assistant erfolgreich!"
    else
        echo "   ❌ MQTT Verbindung zu Home Assistant fehlgeschlagen!"
        echo "      Prüfe IP: $HA_IP, Username: $MQTT_USER"
    fi
    
else
    echo "   🦟 Teste lokalen Mosquitto Broker..."
    
    # Status prüfen
    if sudo systemctl is-active --quiet mosquitto; then
        echo "   ✅ Mosquitto läuft"
        
        # Quick Test
        echo "   🔄 Teste MQTT Kommunikation..."
        
        # Test Message senden/empfangen
        TEST_PARAMS=""
        if [ "$USE_AUTH" = true ]; then
            TEST_PARAMS="-u $MQTT_USER -P $MQTT_PASS"
        fi
        
        mosquitto_pub -h localhost $TEST_PARAMS -t "test/pi5" -m "MQTT Broker funktioniert!" 2>/dev/null
        
        if timeout 3 mosquitto_sub -h localhost $TEST_PARAMS -t "test/pi5" -C 1 2>/dev/null | grep -q "funktioniert"; then
            echo "   ✅ MQTT Test erfolgreich!"
        else
            echo "   ⚠️ MQTT Test fehlgeschlagen - prüfe Konfiguration"
        fi
    else
        echo "   ❌ Mosquitto startet nicht - prüfe Logs:"
        sudo journalctl -u mosquitto --no-pager -n 10
    fi
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
echo "✅ MQTT Bridge Installation abgeschlossen!"
echo ""
if [ "$USE_HA_BROKER" = true ]; then
    echo "📋 MQTT Konfiguration (Home Assistant Broker):"
    echo "   📡 MQTT Broker: Home Assistant ($HA_IP:1883)"
    echo "   � Username: $MQTT_USER"
    echo "   🔐 Passwort: $MQTT_PASS"
    echo "   🌡️ Pi5 sendet Daten an: $HA_IP"
    echo ""
    echo "🧪 MQTT Test Befehle:"
    echo "   mosquitto_pub -h $HA_IP -u $MQTT_USER -P $MQTT_PASS -t 'pi5_heizung/test' -m 'test'"
    echo "   mosquitto_sub -h $HA_IP -u $MQTT_USER -P $MQTT_PASS -t 'pi5_heizung/+/+'"
    echo ""
    echo "🏠 Home Assistant - MQTT bereits konfiguriert!"
    echo "   ✅ Sensoren werden automatisch erkannt"
    
else
    echo "📋 MQTT Konfiguration (Pi5 als Broker):"
    echo "   📡 MQTT Broker: Pi5 ($PI5_IP:1883)"
    echo "   🌐 WebSocket Port: 9001"
    if [ "$USE_AUTH" = true ]; then
        echo "   🔐 Username: $MQTT_USER"
        echo "   🔐 Passwort: $MQTT_PASS"
        TEST_PARAMS="-u $MQTT_USER -P $MQTT_PASS"
    else
        echo "   🔐 Authentifizierung: Keine"
        TEST_PARAMS=""
    fi
    echo ""
    echo "🧪 MQTT Test Befehle:"
    echo "   mosquitto_pub -h $PI5_IP $TEST_PARAMS -t 'test' -m 'message'"
    echo "   mosquitto_sub -h $PI5_IP $TEST_PARAMS -t 'pi5_heizung/+/+'"
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
    echo "🔧 Service Befehle:"
    echo "   sudo systemctl status mosquitto    # Status prüfen"
    echo "   sudo systemctl restart mosquitto   # Neustart"
    echo "   sudo journalctl -u mosquitto -f    # Live Logs"
fi

echo ""
echo "📝 Konfiguration gespeichert in: $CONFIG_FILE"
echo ""
echo "🎯 Nächster Schritt:"
echo "   bash setup_mqtt_service.sh    # MQTT Bridge Service installieren"
echo "   sudo systemctl start pi5-mqtt-bridge"
echo ""
echo "✅ Die MQTT Bridge sendet jetzt an: $MQTT_BROKER_IP"
