#!/bin/bash

# 🔧 Grafana Subpath Konfiguration für beliebige Domains
# Konfiguriert Grafana für Domain + Port + /grafana/ Subpath

set -e

echo "🔧 Grafana Subpath Konfiguration"
echo "================================"

cd ~/pi5-sensors

# Parameter prüfen oder interaktiv abfragen
if [ -n "$1" ]; then
    # Parameter: configure_grafana_subpath.sh DOMAIN PORT
    DOMAIN="$1"
    PORT="${2:-3000}"
    echo "📋 Parameter erkannt:"
    echo "   🌐 Domain: $DOMAIN"
    echo "   🔌 Port: $PORT"
    echo "   🎯 Ziel-URL: http://$DOMAIN:$PORT/grafana/"
elif [ -t 0 ]; then
    # Interaktiv
    echo ""
    echo "🌐 Grafana Subpath Konfiguration:"
    echo ""
    echo "📋 Aktuelle Netzwerk-Adressen:"
    echo "   🔍 IP-Adressen:"
    ip addr show | grep -E "inet [0-9]" | grep -v "127.0.0.1" | awk '{print "      " $2}' || echo "      Keine gefunden"
    echo ""
    echo "   🔍 Hostname:"
    echo "      $(hostname)"
    echo "      $(hostname).fritz.box (falls Fritzbox)"
    echo "      $(hostname).local (mDNS)"
    echo ""
    
    echo "🎯 Wie willst du auf Grafana zugreifen?"
    echo "1) http://IP:3000/grafana/ (z.B. 192.168.1.100:3000/grafana/)"
    echo "2) http://hostname.fritz.box:3000/grafana/ (z.B. dermesser.fritz.box:3000/grafana/)"
    echo "3) http://hostname.local:3000/grafana/ (z.B. pi5.local:3000/grafana/)"
    echo "4) Eigene Domain eingeben"
    echo ""
    read -p "Wähle (1-4): " CHOICE
    
    case $CHOICE in
        1)
            echo ""
            read -p "IP-Adresse des Pi5 (z.B. 192.168.1.100): " DOMAIN
            PORT="3000"
            ;;
        2)
            DOMAIN="$(hostname).fritz.box"
            PORT="3000"
            echo "✅ Verwende: $DOMAIN"
            ;;
        3)
            DOMAIN="$(hostname).local"
            PORT="3000"
            echo "✅ Verwende: $DOMAIN"
            ;;
        4)
            echo ""
            read -p "Domain/Hostname: " DOMAIN
            read -p "Port (Standard 3000): " PORT
            PORT="${PORT:-3000}"
            ;;
        *)
            echo "❌ Ungültige Auswahl"
            exit 1
            ;;
    esac
    
    echo ""
    echo "📋 Konfiguration:"
    echo "   🌐 Domain: $DOMAIN"
    echo "   🔌 Port: $PORT"
    echo "   🎯 Ziel-URL: http://$DOMAIN:$PORT/grafana/"
    echo ""
    read -p "Ist das korrekt? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "❌ Abgebrochen"
        exit 1
    fi
else
    echo "❌ Keine TTY verfügbar - verwende Parameter:"
    echo "   ./configure_grafana_subpath.sh DOMAIN [PORT]"
    echo ""
    echo "Beispiele:"
    echo "   ./configure_grafana_subpath.sh 192.168.1.100"
    echo "   ./configure_grafana_subpath.sh dermesser.fritz.box"
    echo "   ./configure_grafana_subpath.sh pi5.local"
    exit 1
fi

echo ""
echo "🔧 Erstelle Grafana-Konfiguration..."

# Stelle sicher dass grafana Verzeichnis existiert
mkdir -p grafana

# Erstelle korrekte grafana.ini
cat > grafana/grafana.ini << EOF
# Grafana Configuration für Pi 5 Sensor Monitor
# Subpath-Konfiguration für $DOMAIN:$PORT/grafana/

[server]
http_port = $PORT
domain = $DOMAIN
root_url = http://$DOMAIN:$PORT/grafana/
serve_from_sub_path = true
enable_gzip = true

[auth]
disable_login_form = true
disable_signout_menu = true

[auth.anonymous]
enabled = true
org_name = Pi5SensorOrg
org_role = Admin
hide_version = false

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Admin
default_theme = dark

[security]
allow_embedding = true
cookie_secure = false
cookie_samesite = lax

[plugins]
enable_alpha = false
app_tls_skip_verify_insecure = false

[install]
check_for_updates = false

[log]
mode = console
level = info

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning
EOF

echo "✅ grafana.ini erstellt"

echo ""
echo "🐳 Starte Docker Container neu..."
docker compose down
sleep 2
docker compose up -d

echo ""
echo "⏱️ Warte bis Grafana startet..."
sleep 10

# Finde Grafana Container
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Grafana Container nicht gefunden!"
    docker ps
    exit 1
fi

echo "✅ Grafana Container: $GRAFANA_CONTAINER"

# Prüfe Konfiguration im Container
echo ""
echo "🔍 Prüfe Konfiguration im Container..."
CONTAINER_ROOT_URL=$(docker exec "$GRAFANA_CONTAINER" grep "root_url" /etc/grafana/grafana.ini 2>/dev/null || echo "NICHT_GEFUNDEN")

if [ "$CONTAINER_ROOT_URL" = "NICHT_GEFUNDEN" ]; then
    echo "❌ Konfiguration nicht im Container angekommen!"
    exit 1
else
    echo "✅ Container-Konfiguration:"
    echo "   $CONTAINER_ROOT_URL"
fi

echo ""
echo "🧪 Teste URLs..."
sleep 5

# Teste Subpath URL
echo "🔗 Teste http://$DOMAIN:$PORT/grafana/..."
if curl -s -f "http://$DOMAIN:$PORT/grafana/" >/dev/null; then
    echo "✅ Subpath URL funktioniert!"
else
    echo "⚠️ Subpath URL noch nicht erreichbar (kann einige Sekunden dauern)"
    echo ""
    echo "🔧 Container Logs:"
    docker logs --tail 10 "$GRAFANA_CONTAINER"
fi

echo ""
echo "🎉 Grafana Subpath Konfiguration abgeschlossen!"
echo "==============================================="
echo ""
echo "🌐 Grafana Zugriff:"
echo "   📱 Subpath: http://$DOMAIN:$PORT/grafana/"
echo "   📱 Standard: http://$DOMAIN:$PORT/ (evtl. Redirect)"
echo ""
echo "🔧 Falls nicht erreichbar:"
echo "   1. Warte 30 Sekunden (Container-Start)"
echo "   2. Prüfe: docker logs $GRAFANA_CONTAINER"
echo "   3. Teste IP statt Domain: http://$(hostname -I | awk '{print $1}'):$PORT/grafana/"
echo ""
echo "📋 Konfigurationsdatei: ~/pi5-sensors/grafana/grafana.ini"
