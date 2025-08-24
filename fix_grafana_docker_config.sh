#!/bin/bash

# 🔧 Docker Grafana Konfiguration Fix
# Stellt sicher dass grafana.ini korrekt gemounted und konfiguriert ist

set -e

echo "🔧 Docker Grafana Konfiguration Fix"
echo "===================================="

cd ~/pi5-sensors

echo "📁 Prüfe lokale grafana.ini..."
if [ ! -f "grafana/grafana.ini" ]; then
    echo "❌ grafana/grafana.ini nicht gefunden - erstelle Verzeichnis und Datei..."
    mkdir -p grafana
    
    # Erstelle korrekte grafana.ini
    cat > grafana/grafana.ini << 'EOF'
# Grafana Configuration für Pi 5 Sensor Monitor
# Flexible Domain-Konfiguration für Subpath

[server]
http_port = 3000
domain = %(domain)s
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/
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
else
    echo "✅ grafana/grafana.ini gefunden"
fi

# Prüfe ob root_url korrekt ist
echo "🔍 Prüfe root_url Einstellung..."
if grep -q "root_url.*grafana" grafana/grafana.ini; then
    echo "✅ root_url ist konfiguriert"
else
    echo "🔧 Korrigiere root_url Einstellung..."
    # Backup erstellen
    cp grafana/grafana.ini grafana/grafana.ini.backup
    
    # root_url korrigieren für flexible Domain-Verwendung
    sed -i 's|^root_url =.*|root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/|' grafana/grafana.ini
    
    # Falls root_url nicht existiert, hinzufügen
    if ! grep -q "root_url" grafana/grafana.ini; then
        sed -i '/^\[server\]/a root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/' grafana/grafana.ini
    fi
    
    # serve_from_sub_path hinzufügen falls nicht vorhanden
    if ! grep -q "serve_from_sub_path" grafana/grafana.ini; then
        sed -i '/^root_url/a serve_from_sub_path = true' grafana/grafana.ini
    fi
    
    echo "✅ root_url korrigiert für flexible Domain-Verwendung"
fi

echo ""
echo "🐳 Stoppe und starte Docker Container neu..."
docker compose down
sleep 2

echo "🚀 Starte Container mit korrekter Konfiguration..."
docker compose up -d

echo ""
echo "⏱️ Warte bis Grafana startet..."
sleep 10

# Finde Grafana Container Name dynamisch
GRAFANA_CONTAINER=$(docker ps --format "table {{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Grafana Container nicht gefunden!"
    echo "🔍 Verfügbare Container:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    echo ""
    echo "🔧 Alle Container anzeigen (auch gestoppte):"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    echo ""
    echo "🚀 Versuche alle Container zu starten:"
    docker compose up -d
    sleep 5
    
    # Nochmal prüfen
    GRAFANA_CONTAINER=$(docker ps --format "table {{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)
    if [ -z "$GRAFANA_CONTAINER" ]; then
        echo "❌ Grafana Container immer noch nicht gefunden!"
        echo "🔧 docker-compose.yml prüfen:"
        if [ -f "docker-compose.yml" ]; then
            echo "📄 Grafana Service in docker-compose.yml:"
            grep -A 10 -B 2 "grafana:" docker-compose.yml || echo "❌ Grafana Service nicht in docker-compose.yml gefunden"
        else
            echo "❌ docker-compose.yml nicht gefunden!"
        fi
        exit 1
    fi
fi

echo "✅ Grafana Container gefunden: $GRAFANA_CONTAINER"

echo ""
echo "🔍 Prüfe Mount im Container..."
CONTAINER_ROOT_URL=$(docker exec "$GRAFANA_CONTAINER" grep "root_url" /etc/grafana/grafana.ini 2>/dev/null || echo "NICHT_GEFUNDEN")

if [ "$CONTAINER_ROOT_URL" = "NICHT_GEFUNDEN" ]; then
    echo "❌ grafana.ini nicht korrekt gemounted!"
    echo "🔧 Debug-Info:"
    docker exec "$GRAFANA_CONTAINER" ls -la /etc/grafana/ || echo "❌ Kann Container-Dateien nicht lesen"
    exit 1
else
    echo "✅ grafana.ini korrekt gemounted"
    echo "📋 Container root_url: $CONTAINER_ROOT_URL"
fi

echo ""
echo "🧪 Teste Grafana URLs..."
sleep 5

# Teste Standard URL
echo "🔗 Teste http://localhost:3000..."
if curl -s -f http://localhost:3000/ >/dev/null; then
    echo "✅ Standard URL erreichbar"
else
    echo "⚠️ Standard URL nicht erreichbar (das ist OK mit Subpath)"
fi

# Teste Subpath URL
echo "🔗 Teste http://localhost:3000/grafana/..."
if curl -s -f http://localhost:3000/grafana/ >/dev/null; then
    echo "✅ Subpath URL erreichbar"
else
    echo "❌ Subpath URL nicht erreichbar"
    echo "🔧 Prüfe Container Logs:"
    docker logs --tail 20 "$GRAFANA_CONTAINER" || echo "❌ Kann Container Logs nicht lesen"
fi

echo ""
echo "🎉 Grafana Konfiguration Fix abgeschlossen!"
echo "==========================================="
echo ""
echo "📱 Zugriff URLs:"
echo "   🌐 Standard: http://PI_IP:3000"
echo "   🌐 Subpath:  http://PI_IP:3000/grafana/"
echo ""
echo "🔧 Falls Probleme bestehen:"
echo "   docker logs $GRAFANA_CONTAINER"
echo "   docker exec $GRAFANA_CONTAINER cat /etc/grafana/grafana.ini"
