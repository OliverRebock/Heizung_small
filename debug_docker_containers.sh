#!/bin/bash

# 🔍 Docker Container Debug - Findet alle Container und deren Status
# Hilft bei "No such container" Fehlern

echo "🐳 Docker Container Diagnose"
echo "============================"

echo ""
echo "📦 Aktuell laufende Container:"
echo "=============================="
if docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | wc -l | grep -q "0"; then
    echo "❌ Keine Container laufen!"
else
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
fi

echo ""
echo "📦 Alle Container (auch gestoppte):"
echo "==================================="
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Suche nach Grafana Containern:"
echo "================================="
GRAFANA_CONTAINERS=$(docker ps -a --format "{{.Names}}" | grep -i grafana)
if [ -z "$GRAFANA_CONTAINERS" ]; then
    echo "❌ Keine Grafana Container gefunden!"
else
    echo "✅ Gefundene Grafana Container:"
    echo "$GRAFANA_CONTAINERS"
fi

echo ""
echo "📁 docker-compose.yml prüfen:"
echo "=============================="
if [ -f "docker-compose.yml" ]; then
    echo "✅ docker-compose.yml gefunden"
    echo ""
    echo "🔍 Grafana Service Definition:"
    grep -A 15 -B 2 "grafana:" docker-compose.yml || echo "❌ Grafana Service nicht gefunden"
    
    echo ""
    echo "🔍 Container Names in docker-compose.yml:"
    grep "container_name:" docker-compose.yml || echo "ℹ️ Keine expliziten Container-Namen definiert"
    
else
    echo "❌ docker-compose.yml nicht gefunden!"
fi

echo ""
echo "🚀 Docker Compose Status:"
echo "========================="
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ docker-compose verfügbar"
    echo "📋 Services in docker-compose.yml:"
    docker-compose config --services 2>/dev/null || echo "❌ docker-compose config fehlgeschlagen"
else
    echo "⚠️ docker-compose nicht verfügbar, verwende 'docker compose'"
fi

echo ""
echo "🔧 Empfohlene Aktionen:"
echo "======================"
echo "1. Alle Container starten:"
echo "   docker compose up -d"
echo ""
echo "2. Container Logs prüfen:"
echo "   docker compose logs"
echo ""
echo "3. Bestimmten Service starten:"
echo "   docker compose up -d grafana"
echo ""
echo "4. Container neu erstellen:"
echo "   docker compose down"
echo "   docker compose up -d --force-recreate"

echo ""
echo "✅ Diagnose abgeschlossen!"
