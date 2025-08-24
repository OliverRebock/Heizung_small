#!/bin/bash

# 🔍 Docker Grafana Konfiguration Diagnose
# Prüft ob grafana.ini korrekt in Docker Container gemounted ist

set -e

echo "🔍 Docker Grafana Konfiguration Diagnose"
echo "========================================"

# Prüfe ob Container läuft
echo "📦 Prüfe Docker Container Status..."
if ! docker ps | grep pi5-sensor-grafana; then
    echo "❌ Grafana Container läuft nicht!"
    echo "🔧 Starte Container:"
    cd ~/pi5-sensors
    docker compose up -d grafana
    sleep 5
fi

echo ""
echo "📁 Lokale grafana.ini Datei:"
echo "=============================="
if [ -f "/home/pi/pi5-sensors/grafana/grafana.ini" ]; then
    echo "✅ Lokale grafana.ini gefunden"
    echo "🔍 root_url Einstellung:"
    grep "root_url" /home/pi/pi5-sensors/grafana/grafana.ini || echo "❌ root_url nicht gefunden"
    echo ""
    echo "📄 Erste 20 Zeilen der lokalen Datei:"
    head -20 /home/pi/pi5-sensors/grafana/grafana.ini
else
    echo "❌ Lokale grafana.ini nicht gefunden!"
fi

echo ""
echo "🐳 Docker Container grafana.ini:"
echo "================================="
echo "🔍 Prüfe ob grafana.ini im Container gemounted ist..."

# Prüfe Container-Konfiguration
CONTAINER_CONFIG=$(docker exec pi5-sensor-grafana cat /etc/grafana/grafana.ini 2>/dev/null || echo "FEHLER")

if [ "$CONTAINER_CONFIG" = "FEHLER" ]; then
    echo "❌ Kann grafana.ini im Container nicht lesen!"
    echo ""
    echo "🔧 Mögliche Lösungen:"
    echo "1. Container neu starten:"
    echo "   cd ~/pi5-sensors"
    echo "   docker compose down"
    echo "   docker compose up -d"
    echo ""
    echo "2. Mount-Punkt prüfen:"
    echo "   docker exec pi5-sensor-grafana ls -la /etc/grafana/"
    
else
    echo "✅ grafana.ini im Container gefunden"
    echo ""
    echo "🔍 root_url Einstellung im Container:"
    echo "$CONTAINER_CONFIG" | grep "root_url" || echo "❌ root_url nicht gefunden im Container"
    
    echo ""
    echo "📄 Erste 20 Zeilen der Container-Datei:"
    echo "$CONTAINER_CONFIG" | head -20
    
    echo ""
    echo "🔄 Vergleiche lokale vs Container-Datei:"
    LOCAL_LINES=$(wc -l < /home/pi/pi5-sensors/grafana/grafana.ini)
    CONTAINER_LINES=$(echo "$CONTAINER_CONFIG" | wc -l)
    
    echo "   📁 Lokale Datei: $LOCAL_LINES Zeilen"
    echo "   🐳 Container Datei: $CONTAINER_LINES Zeilen"
    
    if [ "$LOCAL_LINES" -eq "$CONTAINER_LINES" ]; then
        echo "✅ Zeilenzahl stimmt überein - Mount funktioniert"
    else
        echo "❌ Unterschiedliche Zeilenzahl - Mount Problem!"
        echo ""
        echo "🔧 Container neu starten um Mount zu reparieren:"
        echo "   cd ~/pi5-sensors"
        echo "   docker compose down"
        echo "   docker compose up -d"
    fi
fi

echo ""
echo "🌐 Teste Grafana Zugriff:"
echo "========================="
echo "🔗 Standard URL: http://localhost:3000"
echo "🔗 Subpath URL:  http://localhost:3000/grafana/"

# Teste beide URLs
echo ""
echo "🧪 Teste Standard URL..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ || echo "❌ Standard URL nicht erreichbar"

echo ""
echo "🧪 Teste Subpath URL..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/grafana/ || echo "❌ Subpath URL nicht erreichbar"

echo ""
echo "📋 Docker Volume Mount Info:"
echo "============================"
docker inspect pi5-sensor-grafana | grep -A 5 -B 5 "grafana.ini" || echo "❌ Mount Info nicht gefunden"

echo ""
echo "✅ Diagnose abgeschlossen!"
echo "=========================="
echo ""
echo "🔧 Falls root_url nicht richtig ist:"
echo "1. cd ~/pi5-sensors"
echo "2. docker compose down"  
echo "3. nano grafana/grafana.ini  # Prüfe root_url = %(protocol)s://%(domain)s/grafana/"
echo "4. docker compose up -d"
