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
# Keine Authentifizierung für lokalen Betrieb

[server]
http_port = 3000
domain = localhost
root_url = %(protocol)s://%(domain)s/grafana/
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
if grep -q "root_url = %(protocol)s://%(domain)s/grafana/" grafana/grafana.ini; then
    echo "✅ root_url ist korrekt konfiguriert"
else
    echo "🔧 Korrigiere root_url Einstellung..."
    # Backup erstellen
    cp grafana/grafana.ini grafana/grafana.ini.backup
    
    # root_url korrigieren
    sed -i 's|^root_url =.*|root_url = %(protocol)s://%(domain)s/grafana/|' grafana/grafana.ini
    
    # Falls root_url nicht existiert, hinzufügen
    if ! grep -q "root_url" grafana/grafana.ini; then
        sed -i '/^\[server\]/a root_url = %(protocol)s://%(domain)s/grafana/' grafana/grafana.ini
    fi
    
    # serve_from_sub_path hinzufügen falls nicht vorhanden
    if ! grep -q "serve_from_sub_path" grafana/grafana.ini; then
        sed -i '/^root_url/a serve_from_sub_path = true' grafana/grafana.ini
    fi
    
    echo "✅ root_url korrigiert"
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

# Teste ob Container läuft
if docker ps | grep pi5-sensor-grafana; then
    echo "✅ Grafana Container läuft"
else
    echo "❌ Grafana Container startet nicht - prüfe Logs:"
    docker logs pi5-sensor-grafana
    exit 1
fi

echo ""
echo "🔍 Prüfe Mount im Container..."
CONTAINER_ROOT_URL=$(docker exec pi5-sensor-grafana grep "root_url" /etc/grafana/grafana.ini 2>/dev/null || echo "NICHT_GEFUNDEN")

if [ "$CONTAINER_ROOT_URL" = "NICHT_GEFUNDEN" ]; then
    echo "❌ grafana.ini nicht korrekt gemounted!"
    echo "🔧 Debug-Info:"
    docker exec pi5-sensor-grafana ls -la /etc/grafana/
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
    docker logs --tail 20 pi5-sensor-grafana
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
echo "   docker logs pi5-sensor-grafana"
echo "   docker exec pi5-sensor-grafana cat /etc/grafana/grafana.ini"
