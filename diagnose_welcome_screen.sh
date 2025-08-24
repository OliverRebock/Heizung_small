#!/bin/bash
# =============================================================================
# GRAFANA WELCOME SCREEN DIAGNOSE - Warum kommt der Welcome Screen?
# =============================================================================

set -e

echo "🔍 GRAFANA WELCOME SCREEN DIAGNOSE"
echo "=================================="
echo ""

GRAFANA_CONTAINER="pi5-grafana"

# 1. Container Status
echo "1️⃣ CONTAINER STATUS:"
echo "==================="
if docker ps | grep -q "$GRAFANA_CONTAINER"; then
    echo "✅ Container läuft"
    docker ps | grep "$GRAFANA_CONTAINER"
else
    echo "❌ Container läuft NICHT!"
    exit 1
fi

echo ""

# 2. Container Konfiguration
echo "2️⃣ CONTAINER KONFIGURATION:"
echo "==========================="
echo "📁 /etc/grafana/grafana.ini im Container:"
echo "----------------------------------------"
docker exec "$GRAFANA_CONTAINER" cat /etc/grafana/grafana.ini | grep -E "^(domain|root_url|serve_from_sub_path|enabled)" | grep -v "^#" || echo "❌ Kann Config nicht lesen"

echo ""

# 3. Environment Variables
echo "3️⃣ ENVIRONMENT VARIABLES:"
echo "========================="
docker exec "$GRAFANA_CONTAINER" env | grep ^GF_ | sort || echo "❌ Keine GF_ Environment Variables"

echo ""

# 4. Volume Mounts
echo "4️⃣ VOLUME MOUNTS:"
echo "================="
docker inspect "$GRAFANA_CONTAINER" | grep -A 10 '"Mounts"' || echo "❌ Kann Mounts nicht lesen"

echo ""

# 5. HTTP Response Analysis
echo "5️⃣ HTTP RESPONSE ANALYSE:"
echo "========================="

# Test verschiedene URLs
declare -a urls=(
    "http://dermesser.fritz.box:3000"
    "http://dermesser.fritz.box:3000/grafana/"
    "http://dermesser.fritz.box:3000/grafana/login"
    "http://dermesser.fritz.box:3000/grafana/api/health"
)

for url in "${urls[@]}"; do
    echo ""
    echo "🌐 Test: $url"
    echo "$(printf '=%.0s' {1..50})"
    
    # HTTP Status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "ERROR")
    echo "Status: $status"
    
    # Headers
    echo "Headers:"
    curl -s -I "$url" 2>/dev/null | head -5 || echo "❌ Keine Headers"
    
    # Content Check
    echo "Content (erste 200 Zeichen):"
    content=$(curl -s "$url" 2>/dev/null | head -c 200 || echo "❌ Kein Content")
    echo "$content"
    
    # Welcome Screen Detection
    if echo "$content" | grep -qi "welcome.*grafana\|setup.*wizard\|getting.*started"; then
        echo "🚨 WELCOME SCREEN ERKANNT!"
    else
        echo "✅ Kein Welcome Screen"
    fi
done

echo ""

# 6. Database Status
echo "6️⃣ DATABASE STATUS:"
echo "=================="
echo "Grafana SQLite Database:"
if docker exec "$GRAFANA_CONTAINER" ls -la /var/lib/grafana/ 2>/dev/null; then
    echo "Database Dateien gefunden"
    docker exec "$GRAFANA_CONTAINER" ls -la /var/lib/grafana/grafana.db 2>/dev/null || echo "❌ grafana.db nicht gefunden"
else
    echo "❌ Kann Database Verzeichnis nicht lesen"
fi

echo ""

# 7. Logs Analysis
echo "7️⃣ GRAFANA LOGS (letzte 30 Zeilen):"
echo "==================================="
docker logs "$GRAFANA_CONTAINER" --tail 30 | grep -E "(error|warn|setup|initial|admin|anonymous)" || echo "Keine relevanten Log-Einträge"

echo ""

# 8. Auth Status
echo "8️⃣ AUTH STATUS CHECK:"
echo "====================="
api_url="http://dermesser.fritz.box:3000/grafana/api/user"
echo "Test: $api_url"
auth_response=$(curl -s "$api_url" 2>/dev/null || echo "ERROR")
echo "Auth Response: $auth_response"

if echo "$auth_response" | grep -q "login"; then
    echo "🚨 AUTH REQUIRED - Anonymous Auth funktioniert NICHT!"
elif echo "$auth_response" | grep -q "email\|name"; then
    echo "✅ Anonymous Auth funktioniert!"
else
    echo "❓ Unklarer Auth Status"
fi

echo ""

# 9. Routing Check
echo "9️⃣ ROUTING CHECK:"
echo "=================="
echo "Grafana URL Resolution:"
curl -s "http://dermesser.fritz.box:3000/grafana/api/frontend/settings" 2>/dev/null | grep -E "(appUrl|appSubUrl)" || echo "❌ Kann Routing Info nicht abrufen"

echo ""

# 10. Diagnose Zusammenfassung
echo "🔟 DIAGNOSE ZUSAMMENFASSUNG:"
echo "==========================="

# Check für häufige Probleme
echo "Probleme gefunden:"

# Problem 1: Welcome Screen
if curl -s "http://dermesser.fritz.box:3000/grafana/" | grep -qi "welcome.*grafana"; then
    echo "❌ WELCOME SCREEN AKTIV"
    echo "   Lösung: fix_serve_from_sub_path.sh oder kill_grafana_welcome_brutal.sh"
fi

# Problem 2: Auth
if curl -s "http://dermesser.fritz.box:3000/grafana/api/user" | grep -q "Unauthorized"; then
    echo "❌ ANONYMOUS AUTH DEAKTIVIERT"
    echo "   Lösung: Anonymous Auth in grafana.ini aktivieren"
fi

# Problem 3: Subpath
if ! docker exec "$GRAFANA_CONTAINER" grep -q "^serve_from_sub_path = true" /etc/grafana/grafana.ini; then
    echo "❌ SERVE_FROM_SUB_PATH FEHLT"
    echo "   Lösung: fix_serve_from_sub_path.sh"
fi

# Problem 4: Domain
if ! docker exec "$GRAFANA_CONTAINER" grep -q "^domain = dermesser.fritz.box" /etc/grafana/grafana.ini; then
    echo "❌ DOMAIN FALSCH KONFIGURIERT"
    echo "   Lösung: Domain in grafana.ini auf dermesser.fritz.box setzen"
fi

echo ""
echo "🔧 EMPFOHLENE ACTIONS:"
echo "====================="
echo "1. fix_serve_from_sub_path.sh - Für serve_from_sub_path Problem"
echo "2. kill_grafana_welcome_brutal.sh - Nuclear Option bei hartnäckigen Problemen"
echo "3. Browser Cache komplett leeren"
echo "4. Andere Browser/Inkognito Modus testen"

echo ""
echo "📞 DEBUG COMMANDS:"
echo "=================="
echo "# Container Config live ändern:"
echo "docker exec $GRAFANA_CONTAINER sed -i 's/^domain = .*/domain = dermesser.fritz.box/' /etc/grafana/grafana.ini"
echo "docker exec $GRAFANA_CONTAINER sed -i 's|^root_url = .*|root_url = http://dermesser.fritz.box:3000/grafana/|' /etc/grafana/grafana.ini"
echo "docker restart $GRAFANA_CONTAINER"
echo ""
echo "# Logs live verfolgen:"
echo "docker logs $GRAFANA_CONTAINER -f"
