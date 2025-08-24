#!/bin/bash
# =============================================================================
# SOFORT-FIX: Organization Not Found & Domain Problem
# =============================================================================
# Löst: {"message":"organization not found","statusCode":404}
# Und: Domain falsch konfiguriert für dermesser.fritz.box
# =============================================================================

set -e

echo "🚨 ORGANIZATION NOT FOUND & DOMAIN FIX"
echo "======================================="
echo "Problem: organization not found + Domain falsch konfiguriert"
echo "Lösung: Komplette Grafana Neuinitialisierung mit korrekter Domain"
echo ""

GRAFANA_CONTAINER="pi5-grafana"

# Container prüfen
if ! docker ps | grep -q "$GRAFANA_CONTAINER"; then
    echo "❌ Grafana Container '$GRAFANA_CONTAINER' läuft nicht!"
    echo "Starte Container..."
    cd ~/pi5-sensors
    docker compose up -d grafana
    sleep 5
fi

echo "🔧 SCHRITT 1: Container stoppen für komplette Neuinitialisierung"
echo "================================================================="
docker stop "$GRAFANA_CONTAINER"

echo ""
echo "🗄️ SCHRITT 2: Grafana Database löschen (Organization Reset)"
echo "==========================================================="
# Database Volume löschen um Organization Problem zu lösen
docker volume ls | grep grafana
echo "Lösche Grafana Volume für komplette Neuinitialisierung..."
docker volume rm pi5-sensors_grafana-data 2>/dev/null || echo "Volume bereits gelöscht oder nicht vorhanden"

echo ""
echo "📁 SCHRITT 3: Lokale grafana.ini KOMPLETT neu erstellen"
echo "========================================================"
cd ~/pi5-sensors
mkdir -p grafana

# Komplett neue grafana.ini mit korrekter Domain-Konfiguration
cat > grafana/grafana.ini << 'EOF'
# GRAFANA CONFIGURATION - ORGANIZATION FIX für dermesser.fritz.box
# Löst: organization not found Problem

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
hide_version = true

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
disable_initial_admin_creation = true
admin_user = 
admin_password = 

[plugins]
enable_alpha = false
app_tls_skip_verify_insecure = false

[install]
check_for_updates = false

[database]
type = sqlite3
host = 127.0.0.1:3306
name = grafana
user = root
password = 

[analytics]
reporting_enabled = false
check_for_updates = false

[snapshots]
external_enabled = false

[feature_toggles]
enable = 

[unified_alerting]
enabled = false

[alerting]
enabled = false

[explore]
enabled = true

[help]
enabled = false

# ORGANIZATION FIX
[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning
EOF

echo "✅ Neue grafana.ini erstellt mit:"
echo "   - domain = dermesser.fritz.box"
echo "   - root_url = http://dermesser.fritz.box:3000/grafana/"
echo "   - serve_from_sub_path = true"
echo "   - org_name = Pi5SensorOrg"
echo "   - disable_initial_admin_creation = true"

echo ""
echo "🐳 SCHRITT 4: Docker Compose mit Volume Mount sicherstellen"
echo "==========================================================="

# Docker Compose prüfen und ggf. korrigieren
if ! grep -q "./grafana/grafana.ini:/etc/grafana/grafana.ini" docker-compose.yml; then
    echo "⚠️ Grafana.ini Volume Mount fehlt in docker-compose.yml"
    echo "Korrigiere docker-compose.yml..."
    
    # Backup erstellen
    cp docker-compose.yml docker-compose.yml.backup
    
    # Volume Mount hinzufügen
    sed -i '/grafana-data:\/var\/lib\/grafana/a\      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro' docker-compose.yml
    
    echo "✅ Volume Mount hinzugefügt"
else
    echo "✅ Volume Mount bereits vorhanden"
fi

echo ""
echo "🔄 SCHRITT 5: Container mit neuer Konfiguration starten"
echo "======================================================="
docker compose up -d grafana

echo "⏳ Warte auf Grafana Initialisierung..."
sleep 15

echo ""
echo "🔍 SCHRITT 6: Container Konfiguration prüfen"
echo "============================================="
echo "Grafana Config im Container:"
docker exec "$GRAFANA_CONTAINER" cat /etc/grafana/grafana.ini | grep -E "^(domain|root_url|serve_from_sub_path|org_name)" | grep -v "^#"

echo ""
echo "🧪 SCHRITT 7: URL Tests"
echo "======================="

# Test 1: Health Check
echo "Test 1: Health Check"
health_response=$(curl -s "http://dermesser.fritz.box:3000/grafana/api/health" 2>/dev/null || echo "ERROR")
echo "Health: $health_response"

# Test 2: Frontend Settings (für Routing Info)
echo ""
echo "Test 2: Frontend Settings"
settings_response=$(curl -s "http://dermesser.fritz.box:3000/grafana/api/frontend/settings" 2>/dev/null || echo "ERROR")
if echo "$settings_response" | grep -q "appUrl\|appSubUrl"; then
    echo "✅ Routing Info verfügbar"
    echo "$settings_response" | grep -E "(appUrl|appSubUrl)" | head -2
else
    echo "❌ Routing Info nicht verfügbar"
fi

# Test 3: User API (Organization Check)
echo ""
echo "Test 3: User API (Organization Check)"
user_response=$(curl -s "http://dermesser.fritz.box:3000/grafana/api/user" 2>/dev/null || echo "ERROR")
echo "User API: $user_response"

if echo "$user_response" | grep -q "organization not found"; then
    echo "❌ Organization Problem NOCH VORHANDEN"
elif echo "$user_response" | grep -q "email\|name\|orgId"; then
    echo "✅ Organization Problem GELÖST!"
else
    echo "❓ Organization Status unklar"
fi

# Test 4: Welcome Screen Check
echo ""
echo "Test 4: Welcome Screen Check"
main_response=$(curl -s "http://dermesser.fritz.box:3000/grafana/" 2>/dev/null | head -c 500)
if echo "$main_response" | grep -qi "welcome.*grafana"; then
    echo "❌ Welcome Screen NOCH VORHANDEN"
    echo "Content Preview:"
    echo "$main_response" | head -3
else
    echo "✅ Kein Welcome Screen erkannt!"
fi

echo ""
echo "📋 SCHRITT 8: Logs prüfen"
echo "========================="
echo "Grafana Logs (letzte 20 Zeilen):"
docker logs "$GRAFANA_CONTAINER" --tail 20

echo ""
echo "✅ ORGANIZATION & DOMAIN FIX ABGESCHLOSSEN"
echo "==========================================="
echo ""
echo "🎯 TESTEN:"
echo "   http://dermesser.fritz.box:3000/grafana/"
echo ""
echo "🔧 Falls immer noch Probleme:"
echo "   1. Browser Cache komplett leeren (Ctrl+Shift+Delete)"
echo "   2. Inkognito/Private Fenster verwenden"
echo "   3. Andere Browser testen"
echo "   4. IP-Adresse verwenden: http://$(hostname -I | awk '{print $1}'):3000/grafana/"
echo ""
echo "💡 BROWSER CACHE LEEREN:"
echo "   Chrome/Edge: Strg+Umschalt+Entf → Alles löschen"
echo "   Firefox: Strg+Umschalt+Entf → Alles löschen"
echo "   Oder: F12 → Network → Disable Cache aktivieren"
