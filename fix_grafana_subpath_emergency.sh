#!/bin/bash

# 🔧 Grafana Subpath SOFORT-REPARATUR für dermesser.fritz.box
# Behebt "Page not found" bei http://dermesser.fritz.box:3000/grafana/

set -e

echo "🚨 Grafana Subpath SOFORT-REPARATUR"
echo "===================================="
echo "🎯 Ziel: http://dermesser.fritz.box:3000/grafana/"

cd ~/pi5-sensors

echo ""
echo "🔍 DIAGNOSE - Aktueller Status:"
echo "==============================="

# Prüfe Docker Container
echo "📦 Docker Container Status:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "(grafana|NAMES)" || echo "❌ Keine Grafana Container gefunden"

# Finde Grafana Container
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Grafana Container läuft nicht - starte neu..."
    docker compose up -d
    sleep 10
    GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)
    
    if [ -z "$GRAFANA_CONTAINER" ]; then
        echo "❌ Container startet nicht - prüfe docker-compose.yml"
        docker compose logs grafana
        exit 1
    fi
fi

echo "✅ Grafana Container: $GRAFANA_CONTAINER"

# Prüfe lokale grafana.ini
echo ""
echo "📁 Lokale grafana.ini:"
if [ -f "grafana/grafana.ini" ]; then
    echo "✅ grafana/grafana.ini existiert"
    grep -E "(domain|root_url)" grafana/grafana.ini || echo "❌ Keine domain/root_url gefunden"
else
    echo "❌ grafana/grafana.ini nicht gefunden!"
fi

# Prüfe Container grafana.ini
echo ""
echo "🐳 Container grafana.ini:"
CONTAINER_CONFIG=$(docker exec "$GRAFANA_CONTAINER" cat /etc/grafana/grafana.ini 2>/dev/null || echo "FEHLER")
if [ "$CONTAINER_CONFIG" = "FEHLER" ]; then
    echo "❌ Kann Container-Konfiguration nicht lesen"
else
    echo "✅ Container-Konfiguration lesbar"
    echo "$CONTAINER_CONFIG" | grep -E "(domain|root_url)" || echo "❌ Keine domain/root_url im Container"
fi

echo ""
echo "🔧 REPARATUR - Korrekte Konfiguration erstellen:"
echo "================================================"

# Stoppe Container
echo "🛑 Stoppe Container..."
docker compose down

# Erstelle korrekte grafana.ini
echo "📝 Erstelle korrekte grafana.ini für dermesser.fritz.box..."
mkdir -p grafana

cat > grafana/grafana.ini << 'EOF'
# Grafana Configuration für dermesser.fritz.box Subpath
# SOFORT-REPARATUR für /grafana/ URL

[server]
http_port = 3000
domain = dermesser.fritz.box
root_url = http://dermesser.fritz.box:3000/grafana/
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

# Prüfe docker-compose.yml Mount
echo ""
echo "🔍 Prüfe docker-compose.yml Volume Mount..."
if grep -q "./grafana/grafana.ini:/etc/grafana/grafana.ini" docker-compose.yml; then
    echo "✅ Volume Mount konfiguriert"
else
    echo "❌ Volume Mount fehlt in docker-compose.yml!"
    echo "🔧 Füge Mount hinzu..."
    
    # Backup docker-compose.yml
    cp docker-compose.yml docker-compose.yml.backup
    
    # Füge Mount hinzu falls nicht vorhanden
    if ! grep -q "grafana/grafana.ini" docker-compose.yml; then
        sed -i '/grafana-data:\/var\/lib\/grafana/a\      - ./grafana/grafana.ini:/etc/grafana/grafana.ini' docker-compose.yml
        echo "✅ Volume Mount hinzugefügt"
    fi
fi

# Starte Container neu
echo ""
echo "🚀 Starte Container mit neuer Konfiguration..."
docker compose up -d

echo ""
echo "⏱️ Warte 15 Sekunden bis Grafana startet..."
sleep 15

# Finde Container wieder
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Container startet nicht!"
    docker compose logs grafana
    exit 1
fi

echo "✅ Container läuft: $GRAFANA_CONTAINER"

# Validiere Konfiguration im Container
echo ""
echo "🧪 VALIDIERUNG - Prüfe Konfiguration im Container:"
echo "=================================================="

CONTAINER_DOMAIN=$(docker exec "$GRAFANA_CONTAINER" grep "^domain" /etc/grafana/grafana.ini 2>/dev/null || echo "NICHT_GEFUNDEN")
CONTAINER_ROOT_URL=$(docker exec "$GRAFANA_CONTAINER" grep "^root_url" /etc/grafana/grafana.ini 2>/dev/null || echo "NICHT_GEFUNDEN")
CONTAINER_SUBPATH=$(docker exec "$GRAFANA_CONTAINER" grep "^serve_from_sub_path" /etc/grafana/grafana.ini 2>/dev/null || echo "NICHT_GEFUNDEN")

echo "📋 Container-Konfiguration:"
echo "   $CONTAINER_DOMAIN"
echo "   $CONTAINER_ROOT_URL"
echo "   $CONTAINER_SUBPATH"

if [[ "$CONTAINER_ROOT_URL" == *"dermesser.fritz.box:3000/grafana/"* ]]; then
    echo "✅ Container-Konfiguration korrekt!"
else
    echo "❌ Container-Konfiguration falsch!"
    echo ""
    echo "🔧 Container Logs:"
    docker logs --tail 20 "$GRAFANA_CONTAINER"
    exit 1
fi

# Teste URLs
echo ""
echo "🧪 URL-TESTS:"
echo "============="

echo "🔗 Teste http://dermesser.fritz.box:3000/ (sollte redirect sein)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/ 2>/dev/null || echo "FEHLER")
echo "   HTTP Code: $HTTP_CODE"

echo "🔗 Teste http://dermesser.fritz.box:3000/grafana/ (sollte 200 sein)..."
HTTP_CODE_SUBPATH=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/grafana/ 2>/dev/null || echo "FEHLER")
echo "   HTTP Code: $HTTP_CODE_SUBPATH"

if [ "$HTTP_CODE_SUBPATH" = "200" ]; then
    echo "✅ SUBPATH URL FUNKTIONIERT!"
else
    echo "❌ Subpath URL funktioniert noch nicht"
    echo ""
    echo "🔧 Mögliche Ursachen:"
    echo "1. Container braucht mehr Zeit (warte 30 Sekunden)"
    echo "2. Grafana startet noch"
    echo "3. Mount Problem"
    echo ""
    echo "📋 Container Logs (letzte 10 Zeilen):"
    docker logs --tail 10 "$GRAFANA_CONTAINER"
fi

echo ""
echo "🎉 SOFORT-REPARATUR ABGESCHLOSSEN!"
echo "=================================="
echo ""
echo "🌐 Teste jetzt in deinem Browser:"
echo "   📱 http://dermesser.fritz.box:3000/grafana/"
echo ""
echo "⏱️ Falls noch 'Page not found':"
echo "   1. Warte 1-2 Minuten (Grafana-Start)"
echo "   2. Browser Cache leeren (Ctrl+F5)"
echo "   3. Prüfe Container Logs: docker logs $GRAFANA_CONTAINER"
echo ""
echo "🔧 Debug-Befehle:"
echo "   docker exec $GRAFANA_CONTAINER cat /etc/grafana/grafana.ini | grep -E '(domain|root_url|serve_from_sub_path)'"
echo "   curl -v http://dermesser.fritz.box:3000/grafana/"
