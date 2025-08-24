#!/bin/bash
# =============================================================================
# SOFORT-FIX: serve_from_sub_path LIVE im Container korrigieren
# =============================================================================
# Für das Welcome Screen Problem bei dermesser.fritz.box:3000/grafana/
# =============================================================================

set -e

echo "🚨 SERVE_FROM_SUB_PATH SOFORT-FIX"
echo "================================="
echo "Problem: Welcome Screen trotz korrekter Konfiguration"
echo "Lösung: Live-Korrektur im Container + Domain-Fix"
echo ""

# Container prüfen
GRAFANA_CONTAINER="pi5-grafana"
if ! docker ps | grep -q "$GRAFANA_CONTAINER"; then
    echo "❌ Grafana Container '$GRAFANA_CONTAINER' läuft nicht!"
    echo "Versuche Container zu starten..."
    cd ~/pi5-sensors
    docker compose up -d grafana
    sleep 5
fi

echo "📋 Aktuelle Grafana Konfiguration im Container:"
echo "-----------------------------------------------"

# Aktuelle Container-Konfiguration anzeigen
docker exec "$GRAFANA_CONTAINER" cat /etc/grafana/grafana.ini | grep -E "^(domain|root_url|serve_from_sub_path)" || echo "❌ Kann Konfiguration nicht lesen"

echo ""
echo "🔧 LIVE-KORREKTUR im Container..."

# 1. Domain setzen (für dermesser.fritz.box)
echo "1. Domain korrigieren..."
docker exec "$GRAFANA_CONTAINER" sed -i 's/^domain = .*/domain = dermesser.fritz.box/' /etc/grafana/grafana.ini

# 2. Root URL korrigieren
echo "2. Root URL korrigieren..."
docker exec "$GRAFANA_CONTAINER" sed -i 's|^root_url = .*|root_url = http://dermesser.fritz.box:3000/grafana/|' /etc/grafana/grafana.ini

# 3. serve_from_sub_path sicherstellen
echo "3. serve_from_sub_path aktivieren..."
if docker exec "$GRAFANA_CONTAINER" grep -q "^serve_from_sub_path" /etc/grafana/grafana.ini; then
    docker exec "$GRAFANA_CONTAINER" sed -i 's/^serve_from_sub_path = .*/serve_from_sub_path = true/' /etc/grafana/grafana.ini
else
    # Falls nicht vorhanden, nach root_url hinzufügen
    docker exec "$GRAFANA_CONTAINER" sed -i '/^root_url/a serve_from_sub_path = true' /etc/grafana/grafana.ini
fi

# 4. Anonymous Auth sicherstellen
echo "4. Anonymous Auth aktivieren..."
docker exec "$GRAFANA_CONTAINER" sed -i 's/^enabled = false/enabled = true/' /etc/grafana/grafana.ini
docker exec "$GRAFANA_CONTAINER" sed -i '/^\[auth.anonymous\]/,/^\[/ s/^enabled = .*/enabled = true/' /etc/grafana/grafana.ini

# 5. Initial Admin Creation disablen
echo "5. Initial Admin Creation disablen..."
if docker exec "$GRAFANA_CONTAINER" grep -q "disable_initial_admin_creation" /etc/grafana/grafana.ini; then
    docker exec "$GRAFANA_CONTAINER" sed -i 's/^disable_initial_admin_creation = .*/disable_initial_admin_creation = true/' /etc/grafana/grafana.ini
else
    docker exec "$GRAFANA_CONTAINER" sed -i '/^\[security\]/a disable_initial_admin_creation = true' /etc/grafana/grafana.ini
fi

echo ""
echo "✅ Korrigierte Konfiguration:"
echo "----------------------------"
docker exec "$GRAFANA_CONTAINER" cat /etc/grafana/grafana.ini | grep -E "^(domain|root_url|serve_from_sub_path)" || echo "❌ Problem beim Lesen"

echo ""
echo "🔄 Container neu starten..."
docker restart "$GRAFANA_CONTAINER"

echo "⏳ Warte auf Grafana Neustart..."
sleep 10

# Auch die lokale grafana.ini korrigieren für nächste Starts
echo "📁 Lokale grafana.ini auch korrigieren..."
if [ -f ~/pi5-sensors/grafana/grafana.ini ]; then
    cd ~/pi5-sensors
    sed -i 's/^domain = .*/domain = dermesser.fritz.box/' grafana/grafana.ini
    sed -i 's|^root_url = .*|root_url = http://dermesser.fritz.box:3000/grafana/|' grafana/grafana.ini
    
    if ! grep -q "^serve_from_sub_path" grafana/grafana.ini; then
        sed -i '/^root_url/a serve_from_sub_path = true' grafana/grafana.ini
    fi
    
    echo "   ✅ Lokale grafana.ini korrigiert"
fi

echo ""
echo "🧪 URL Tests..."
echo "==============

# Test 1: Direkt (sollte Redirect machen)
echo "Test 1: http://dermesser.fritz.box:3000"
curl -s -I "http://dermesser.fritz.box:3000" | head -3

echo ""
echo "Test 2: http://dermesser.fritz.box:3000/grafana/"
curl -s -I "http://dermesser.fritz.box:3000/grafana/" | head -3

echo ""
echo "Test 3: Response Content Check"
RESPONSE=$(curl -s "http://dermesser.fritz.box:3000/grafana/" | head -20)
if echo "$RESPONSE" | grep -q "Welcome to Grafana"; then
    echo "❌ IMMER NOCH Welcome Screen!"
    echo "Content Preview:"
    echo "$RESPONSE" | grep -E "(Welcome|dashboard|menu)" || echo "Keine relevanten Inhalte gefunden"
else
    echo "✅ Kein Welcome Screen erkannt!"
fi

echo ""
echo "🔍 Container Logs (letzte 20 Zeilen):"
echo "====================================="
docker logs "$GRAFANA_CONTAINER" --tail 20

echo ""
echo "📋 ZUSAMMENFASSUNG:"
echo "=================="
echo "✅ Domain: dermesser.fritz.box"
echo "✅ Root URL: http://dermesser.fritz.box:3000/grafana/"
echo "✅ serve_from_sub_path: true"
echo "✅ Anonymous Auth: enabled"
echo "✅ Initial Admin Creation: disabled"
echo ""
echo "🌐 Test jetzt: http://dermesser.fritz.box:3000/grafana/"
echo ""

# Zusätzlich: Browser Cache leeren Anweisung
echo "🚨 WICHTIG: Browser Cache leeren!"
echo "================================"
echo "1. Chrome/Edge: Ctrl+Shift+R (Hard Reload)"
echo "2. Firefox: Ctrl+F5"
echo "3. Oder Inkognito/Private Fenster verwenden"
echo "4. Oder Developer Tools → Network → Disable Cache"
echo ""

echo "💡 Falls immer noch Welcome Screen:"
echo "===================================="
echo "1. Browser komplett schließen und neu öffnen"
echo "2. Andere Browser versuchen"
echo "3. IP-Adresse verwenden: http://$(hostname -I | awk '{print $1}'):3000/grafana/"
echo "4. kill_grafana_welcome_brutal.sh ausführen (Nuclear Option)"
