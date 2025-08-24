#!/bin/bash

# 🧪 Grafana URL Test für dermesser.fritz.box
# Testet verschiedene URLs und zeigt was funktioniert

echo "🧪 Grafana URL Test für dermesser.fritz.box"
echo "==========================================="

echo ""
echo "🔗 Teste verschiedene URLs:"
echo "==========================="

# Test 1: Standard URL (sollte redirect oder error sein)
echo "1. http://dermesser.fritz.box:3000/"
HTTP_1=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/ 2>/dev/null || echo "FEHLER")
echo "   ➜ HTTP Code: $HTTP_1"

# Test 2: Subpath URL (sollte 200 sein)
echo ""
echo "2. http://dermesser.fritz.box:3000/grafana/"
HTTP_2=$(curl -s -o /dev/null -w "%{http_code}" http://dermesser.fritz.box:3000/grafana/ 2>/dev/null || echo "FEHLER")
echo "   ➜ HTTP Code: $HTTP_2"

# Test 3: Mit verbose curl für Details
echo ""
echo "3. Detaillierter Test mit curl -v:"
echo "=================================="
echo "curl -v http://dermesser.fritz.box:3000/grafana/ (erste 20 Zeilen):"
timeout 10 curl -v http://dermesser.fritz.box:3000/grafana/ 2>&1 | head -20 || echo "Timeout oder Fehler"

echo ""
echo "🐳 Docker Container Status:"
echo "==========================="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "(grafana|NAMES)"

# Finde Grafana Container
GRAFANA_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(grafana|pi5.*grafana)" | head -1)

if [ -n "$GRAFANA_CONTAINER" ]; then
    echo ""
    echo "🔍 Container-Konfiguration:"
    echo "=========================="
    echo "Container: $GRAFANA_CONTAINER"
    echo ""
    echo "Wichtige Einstellungen:"
    docker exec "$GRAFANA_CONTAINER" grep -E "^(domain|root_url|serve_from_sub_path)" /etc/grafana/grafana.ini 2>/dev/null || echo "❌ Kann Konfiguration nicht lesen"
    
    echo ""
    echo "📋 Container Logs (letzte 5 Zeilen):"
    docker logs --tail 5 "$GRAFANA_CONTAINER" 2>/dev/null || echo "❌ Kann Logs nicht lesen"
else
    echo "❌ Grafana Container nicht gefunden!"
fi

echo ""
echo "📋 ERGEBNIS:"
echo "============"

if [ "$HTTP_2" = "200" ]; then
    echo "✅ ERFOLG: http://dermesser.fritz.box:3000/grafana/ funktioniert!"
    echo "   🌐 Öffne die URL in deinem Browser"
elif [ "$HTTP_2" = "404" ]; then
    echo "❌ FEHLER: Page not found (404)"
    echo "   🔧 Grafana Subpath-Konfiguration fehlt"
    echo "   🚀 Ausführen: ./fix_grafana_subpath_emergency.sh"
elif [ "$HTTP_2" = "FEHLER" ]; then
    echo "❌ FEHLER: Kann dermesser.fritz.box nicht erreichen"
    echo "   🔍 Prüfe Netzwerk-Verbindung"
    echo "   🔧 Alternative: Verwende IP-Adresse statt Hostname"
else
    echo "⚠️ UNBEKANNT: HTTP Code $HTTP_2"
    echo "   🔧 Ausführen: ./fix_grafana_subpath_emergency.sh"
fi

echo ""
echo "🔧 Nächste Schritte bei Problemen:"
echo "=================================="
echo "1. cd ~/pi5-sensors"
echo "2. wget https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/fix_grafana_subpath_emergency.sh"
echo "3. chmod +x fix_grafana_subpath_emergency.sh"
echo "4. ./fix_grafana_subpath_emergency.sh"
