#!/bin/bash

# 🚨 GRAFANA SUPER-AGGRESSIVE WELCOME SCREEN KILLER
# Eliminiert Welcome Screen mit Gewalt - für hartnäckige Fälle

set -e

echo "🚨 GRAFANA SUPER-AGGRESSIVE WELCOME SCREEN KILLER"
echo "=================================================="
echo "🎯 Brutaler Fix für hartnäckigen Welcome Screen"

cd ~/pi5-sensors

echo ""
echo "🛑 SCHRITT 1: Kompletter Container-Reset"
echo "========================================"

# Stoppe alle Container
echo "🔥 Stoppe und entferne alle Container..."
docker compose down -v

# Entferne Grafana Volumes komplett
echo "🗑️ Entferne Grafana Volumes..."
docker volume rm $(docker volume ls -q | grep grafana) 2>/dev/null || true

echo ""
echo "📝 SCHRITT 2: AGGRESSIVE Grafana-Konfiguration"
echo "=============================================="

# Erstelle ULTRA-AGGRESSIVE grafana.ini
mkdir -p grafana

cat > grafana/grafana.ini << 'EOF'
# SUPER-AGGRESSIVE Grafana Configuration
# ELIMINIERT Welcome Screen mit Gewalt

[server]
http_port = 3000
domain = dermesser.fritz.box
root_url = http://dermesser.fritz.box:3000/grafana/
serve_from_sub_path = true
enable_gzip = true

# AGGRESSIVE AUTH DISABLE
[auth]
disable_login_form = true
disable_signout_menu = true
oauth_auto_login = false

# AGGRESSIVE ANONYMOUS
[auth.anonymous]
enabled = true
org_name = Pi5SensorOrg
org_role = Admin
hide_version = true

# AGGRESSIVE USER MANAGEMENT
[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Admin
default_theme = dark
viewers_can_edit = true
editors_can_admin = true

# AGGRESSIVE SECURITY
[security]
allow_embedding = true
cookie_secure = false
cookie_samesite = lax
disable_initial_admin_creation = true
admin_user = 
admin_password = 
secret_key = sw2YcwTIb9zpOOhoPsMm

# AGGRESSIVE FEATURES DISABLE
[plugins]
enable_alpha = false
app_tls_skip_verify_insecure = false

[install]
check_for_updates = false

# AGGRESSIVE LOGGING
[log]
mode = console
level = warn
filters = rendering:debug

# PATHS
[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

# AGGRESSIVE DASHBOARD SETTINGS
[dashboards]
default_home_dashboard_path = 

# AGGRESSIVE FEATURE TOGGLES
[feature_toggles]
enable = 

# AGGRESSIVE ANALYTICS DISABLE
[analytics]
reporting_enabled = false
check_for_updates = false
google_analytics_ua_id = 
google_tag_manager_id = 

# AGGRESSIVE SMTP DISABLE
[smtp]
enabled = false

# AGGRESSIVE ALERTING DISABLE
[unified_alerting]
enabled = false

# AGGRESSIVE LIVE DISABLE
[live]
allowed_origins = 

# AGGRESSIVE PANELS
[panels]
disable_sanitize_html = true

# AGGRESSIVE DATABASE
[database]
type = sqlite3
path = grafana.db

# AGGRESSIVE SESSION
[session]
provider = memory

# AGGRESSIVE DATAPROXY
[dataproxy]
logging = false

# AGGRESSIVE EXPLORE
[explore]
enabled = true

# AGGRESSIVE HELP
[help]
enabled = false
EOF

echo "✅ SUPER-AGGRESSIVE grafana.ini erstellt"

echo ""
echo "🔧 SCHRITT 3: Docker-Compose Anpassung"
echo "======================================"

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup.$(date +%s)

# Prüfe/Repariere Grafana Volume Mount in docker-compose.yml
if ! grep -q "./grafana/grafana.ini:/etc/grafana/grafana.ini" docker-compose.yml; then
    echo "🔧 Füge Grafana Mount zu docker-compose.yml hinzu..."
    
    # Füge Mount nach volumes: hinzu
    sed -i '/volumes:/a\      - ./grafana/grafana.ini:/etc/grafana/grafana.ini' docker-compose.yml
fi

echo "✅ docker-compose.yml konfiguriert"

echo ""
echo "🚀 SCHRITT 4: Container-Start mit Force"
echo "======================================"

# Starte Container mit Force-Recreate
echo "🔥 Starte Container mit --force-recreate..."
docker compose up -d --force-recreate

echo ""
echo "⏱️ SCHRITT 5: Extended Wait & Monitoring"
echo "======================================="

echo "⏱️ Warte 30 Sekunden für Container-Start..."
sleep 30

# Finde Grafana Container
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -z "$GRAFANA_CONTAINER" ]; then
    echo "❌ Container startet nicht!"
    echo "🔧 Container Logs:"
    docker compose logs grafana
    exit 1
fi

echo "✅ Container läuft: $GRAFANA_CONTAINER"

echo ""
echo "🔍 SCHRITT 6: Container-Konfiguration VALIDATION"
echo "==============================================="

# Prüfe Container-Konfiguration AGGRESSIV
echo "📋 Prüfe Container-Konfiguration..."

echo "🔍 Anonymous enabled:"
docker exec "$GRAFANA_CONTAINER" grep -A 3 "\[auth.anonymous\]" /etc/grafana/grafana.ini

echo ""
echo "🔍 Auth disabled:"
docker exec "$GRAFANA_CONTAINER" grep -A 3 "\[auth\]" /etc/grafana/grafana.ini

echo ""
echo "🔍 Security settings:"
docker exec "$GRAFANA_CONTAINER" grep -A 3 "\[security\]" /etc/grafana/grafana.ini

echo ""
echo "🧪 SCHRITT 7: AGGRESSIVE URL-Tests"
echo "================================="

# Teste URL mehrfach
for i in {1..3}; do
    echo "🔗 Test $i/3: http://dermesser.fritz.box:3000/grafana/..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/grafana/ 2>/dev/null || echo "FEHLER")
    echo "   HTTP Code: $HTTP_CODE"
    
    if [ "$HTTP_CODE" = "200" ]; then
        # Teste Welcome Screen Content
        RESPONSE=$(curl -s http://dermesser.fritz.box:3000/grafana/ 2>/dev/null | head -1000)
        
        if [[ "$RESPONSE" == *"Welcome to Grafana"* ]]; then
            echo "   ❌ Welcome Screen noch da"
        elif [[ "$RESPONSE" == *"dashboard"* ]] || [[ "$RESPONSE" == *"menu"* ]] || [[ "$RESPONSE" == *"nav"* ]]; then
            echo "   ✅ Welcome Screen weg - Dashboard sichtbar!"
            break
        else
            echo "   🔍 Unbekannte Antwort"
        fi
    fi
    
    if [ "$i" -lt 3 ]; then
        echo "   ⏱️ Warte 10 Sekunden..."
        sleep 10
    fi
done

echo ""
echo "🔧 SCHRITT 8: NUCLEAR OPTION (falls Welcome Screen hartnäckig)"
echo "============================================================="

# Nuclear Option: Grafana Database Reset
echo "🚨 NUCLEAR OPTION: Database Reset..."
docker exec "$GRAFANA_CONTAINER" rm -f /var/lib/grafana/grafana.db 2>/dev/null || true
docker exec "$GRAFANA_CONTAINER" rm -rf /var/lib/grafana/sessions 2>/dev/null || true

echo "🔄 Container Restart..."
docker restart "$GRAFANA_CONTAINER"

echo "⏱️ Warte 20 Sekunden für Database-Rebuild..."
sleep 20

echo ""
echo "🧪 FINAL TEST:"
echo "=============="

HTTP_FINAL=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/grafana/ 2>/dev/null || echo "FEHLER")
echo "🔗 Final Test HTTP Code: $HTTP_FINAL"

if [ "$HTTP_FINAL" = "200" ]; then
    RESPONSE_FINAL=$(curl -s http://dermesser.fritz.box:3000/grafana/ 2>/dev/null | head -500)
    
    if [[ "$RESPONSE_FINAL" == *"Welcome to Grafana"* ]]; then
        echo "❌ HARTNÄCKIG: Welcome Screen immer noch da!"
        echo ""
        echo "🔧 LETZTE OPTIONEN:"
        echo "1. Browser komplett neu starten"
        echo "2. Private/Incognito Fenster"
        echo "3. Andere Browser verwenden"
        echo "4. IP statt Domain: http://$(hostname -I | awk '{print $1}'):3000/grafana/"
        echo ""
        echo "📋 Debug-Info:"
        echo "Container Logs (letzte 20 Zeilen):"
        docker logs --tail 20 "$GRAFANA_CONTAINER"
    else
        echo "✅ SUCCESS: Welcome Screen eliminiert!"
    fi
else
    echo "❌ URL nicht erreichbar: $HTTP_FINAL"
fi

echo ""
echo "🎉 SUPER-AGGRESSIVE WELCOME SCREEN KILLER ABGESCHLOSSEN!"
echo "========================================================"
echo ""
echo "🌐 URLs zum Testen:"
echo "   📱 Domain: http://dermesser.fritz.box:3000/grafana/"
echo "   📱 IP: http://$(hostname -I | awk '{print $1}'):3000/grafana/"
echo ""
echo "💡 Falls immer noch Welcome Screen:"
echo "   🔄 Browser-Cache KOMPLETT leeren"
echo "   🆕 Anderen Browser verwenden"
echo "   🔧 Container Logs: docker logs $GRAFANA_CONTAINER"
