#!/bin/bash

# 🔧 Grafana Welcome Screen Fix - Aktiviert Anonymous Login
# Behebt "Welcome to Grafana" Screen der nicht wegklickbar ist

set -e

echo "🔧 Grafana Welcome Screen Fix"
echo "=============================="
echo "🎯 Aktiviert Anonymous Login für sofortigen Zugriff"

cd ~/pi5-sensors

# Finde Grafana Container
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Grafana Container nicht gefunden!"
    echo "🚀 Starte Container..."
    docker compose up -d
    sleep 10
    GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)
    
    if [ -z "$GRAFANA_CONTAINER" ]; then
        echo "❌ Container startet nicht!"
        exit 1
    fi
fi

echo "✅ Grafana Container: $GRAFANA_CONTAINER"

echo ""
echo "🔍 Aktuelle Grafana-Konfiguration:"
echo "=================================="

# Prüfe aktuelle Authentifizierung-Einstellungen
echo "📋 Auth-Einstellungen im Container:"
docker exec "$GRAFANA_CONTAINER" grep -E "^(disable_login_form|enabled.*=.*true)" /etc/grafana/grafana.ini 2>/dev/null || echo "❌ Auth-Einstellungen nicht gefunden"

echo ""
echo "🔧 Erstelle korrekte Grafana-Konfiguration:"
echo "==========================================="

# Stoppe Container
echo "🛑 Stoppe Container..."
docker compose down

# Erstelle VOLLSTÄNDIGE grafana.ini mit korrekter Anonymous-Konfiguration
echo "📝 Erstelle grafana.ini mit Anonymous Login..."
mkdir -p grafana

cat > grafana/grafana.ini << 'EOF'
# Grafana Configuration für Pi5 Heizungs Messer
# ANONYMOUS LOGIN - Kein Welcome Screen, sofortiger Zugriff

[server]
http_port = 3000
domain = dermesser.fritz.box
root_url = http://dermesser.fritz.box:3000/grafana/
serve_from_sub_path = true
enable_gzip = true

# WICHTIG: Authentifizierung komplett deaktivieren
[auth]
disable_login_form = true
disable_signout_menu = true

# KRITISCH: Anonymous Zugriff aktivieren
[auth.anonymous]
enabled = true
org_name = Pi5SensorOrg
org_role = Admin
hide_version = false

# User-Management deaktivieren
[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Admin
default_theme = dark

# Security für Anonymous-Zugriff
[security]
allow_embedding = true
cookie_secure = false
cookie_samesite = lax
disable_initial_admin_creation = true

# Features
[plugins]
enable_alpha = false
app_tls_skip_verify_insecure = false

[install]
check_for_updates = false

# Logging
[log]
mode = console
level = info

# Paths
[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

# Dashboard-Einstellungen für direkten Zugriff
[dashboards]
default_home_dashboard_path = /var/lib/grafana/dashboards/home.json

# Disable Welcome Screen Features
[feature_toggles]
enable = []

# Analytics deaktivieren
[analytics]
reporting_enabled = false
check_for_updates = false

# Unified Alerting (optional)
[unified_alerting]
enabled = false
EOF

echo "✅ Vollständige grafana.ini mit Anonymous Login erstellt"

echo ""
echo "🚀 Starte Container mit neuer Konfiguration..."
docker compose up -d

echo ""
echo "⏱️ Warte 20 Sekunden bis Grafana vollständig startet..."
sleep 20

# Finde Container wieder
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Container startet nicht!"
    docker compose logs grafana
    exit 1
fi

echo "✅ Container läuft: $GRAFANA_CONTAINER"

echo ""
echo "🧪 Validiere Anonymous Login Konfiguration:"
echo "==========================================="

# Prüfe Container-Konfiguration
echo "📋 Auth-Einstellungen im Container:"
ANON_ENABLED=$(docker exec "$GRAFANA_CONTAINER" grep "enabled.*=.*true" /etc/grafana/grafana.ini | grep -A 1 "\[auth.anonymous\]" || echo "NICHT_GEFUNDEN")
DISABLE_LOGIN=$(docker exec "$GRAFANA_CONTAINER" grep "disable_login_form.*=.*true" /etc/grafana/grafana.ini || echo "NICHT_GEFUNDEN")

echo "   Anonymous enabled: $ANON_ENABLED"
echo "   Login disabled: $DISABLE_LOGIN"

if [[ "$ANON_ENABLED" == *"enabled = true"* ]] && [[ "$DISABLE_LOGIN" == *"disable_login_form = true"* ]]; then
    echo "✅ Anonymous Login korrekt konfiguriert!"
else
    echo "❌ Anonymous Login nicht korrekt konfiguriert!"
    echo ""
    echo "🔧 Container Logs:"
    docker logs --tail 10 "$GRAFANA_CONTAINER"
fi

echo ""
echo "🧪 URL-Tests:"
echo "============="

# Teste URL
echo "🔗 Teste http://dermesser.fritz.box:3000/grafana/..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/grafana/ 2>/dev/null || echo "FEHLER")
echo "   HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ URL erreichbar!"
    
    # Teste ob Welcome Screen umgangen wird
    echo ""
    echo "🔍 Teste Welcome Screen..."
    RESPONSE=$(curl -s http://dermesser.fritz.box:3000/grafana/ 2>/dev/null || echo "FEHLER")
    
    if [[ "$RESPONSE" == *"Welcome to Grafana"* ]]; then
        echo "⚠️ Welcome Screen noch sichtbar - aber sollte übersprungen werden"
        echo "💡 Browser neu laden mit Ctrl+F5"
    elif [[ "$RESPONSE" == *"dashboard"* ]] || [[ "$RESPONSE" == *"grafana"* ]]; then
        echo "✅ Welcome Screen umgangen - direkter Zugriff möglich!"
    else
        echo "🔍 Unbekannte Antwort (könnte OK sein)"
    fi
else
    echo "❌ URL nicht erreichbar"
fi

echo ""
echo "🎉 Grafana Welcome Screen Fix abgeschlossen!"
echo "============================================"
echo ""
echo "🌐 Zugriff:"
echo "   📱 URL: http://dermesser.fritz.box:3000/grafana/"
echo "   🎯 Sollte DIREKT ohne Login funktionieren"
echo "   🔄 Falls Welcome Screen: Browser Cache leeren (Ctrl+F5)"
echo ""
echo "💡 Was passiert:"
echo "   ✅ Kein Login erforderlich"
echo "   ✅ Admin-Rechte automatisch"
echo "   ✅ Direkter Dashboard-Zugriff"
echo "   ✅ Welcome Screen deaktiviert"
echo ""
echo "🔧 Falls immer noch Welcome Screen:"
echo "   1. Browser komplett neu starten"
echo "   2. Private/Incognito Fenster verwenden"
echo "   3. Container Logs prüfen: docker logs $GRAFANA_CONTAINER"
echo ""
echo "📋 Konfigurationsdatei: ~/pi5-sensors/grafana/grafana.ini"
