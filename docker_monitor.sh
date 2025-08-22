#!/bin/bash
# =============================================================================
# DOCKER MONITORING FÜR RASPBERRY PI 5
# =============================================================================
# Überwacht Docker Container Gesundheit und Ressourcenverbrauch

echo "🐳 DOCKER SYSTEM STATUS - Raspberry Pi 5"
echo "========================================"
echo ""

# =============================================================================
# 1. SYSTEM RESSOURCEN
# =============================================================================
echo "📊 SYSTEM RESSOURCEN:"
echo "CPU:        $(vcgencmd measure_temp)"
echo "RAM:        $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
echo "SD-Karte:   $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
echo ""

# =============================================================================
# 2. DOCKER CONTAINER STATUS
# =============================================================================
echo "📦 CONTAINER STATUS:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

# =============================================================================
# 3. CONTAINER RESOURCES
# =============================================================================
echo "💾 CONTAINER RESSOURCEN:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
echo ""

# =============================================================================
# 4. CONTAINER HEALTHCHECKS
# =============================================================================
echo "🏥 HEALTHCHECK STATUS:"

# InfluxDB Health
INFLUX_HEALTH=$(docker compose exec -T influxdb influx ping 2>/dev/null && echo "✅ HEALTHY" || echo "❌ UNHEALTHY")
echo "InfluxDB: $INFLUX_HEALTH"

# Grafana Health  
GRAFANA_HEALTH=$(curl -f -s http://localhost:3000/api/health > /dev/null && echo "✅ HEALTHY" || echo "❌ UNHEALTHY")
echo "Grafana:  $GRAFANA_HEALTH"
echo ""

# =============================================================================
# 5. DOCKER LOGS (LETZTE 10 ZEILEN)
# =============================================================================
echo "📋 AKTUELLE LOGS (letzte 5 Zeilen):"
echo ""
echo "--- InfluxDB ---"
docker compose logs --tail=5 influxdb

echo ""
echo "--- Grafana ---"
docker compose logs --tail=5 grafana

# =============================================================================
# 6. DOCKER SYSTEM INFO
# =============================================================================
echo ""
echo "🔧 DOCKER SYSTEM:"
echo "Docker Version: $(docker --version)"
echo "Docker Compose: $(docker compose version)"
echo "Aktive Container: $(docker ps -q | wc -l)"
echo "Verwendete Images: $(docker images -q | wc -l)"
echo ""

# =============================================================================
# 7. DISK SPACE FÜR DOCKER
# =============================================================================
echo "💿 DOCKER SPEICHERPLATZ:"
echo "Docker Root: $(docker system df)"
echo ""
echo "Datenverzeichnisse:"
echo "InfluxDB: $(du -sh /opt/docker-data/influxdb 2>/dev/null || echo 'Nicht gefunden')"
echo "Grafana:  $(du -sh /opt/docker-data/grafana 2>/dev/null || echo 'Nicht gefunden')"

# =============================================================================
# 8. NETZWERK STATUS
# =============================================================================
echo ""
echo "🌐 NETZWERK:"
echo "Lokale IP: $(hostname -I | awk '{print $1}')"
echo "Services erreichbar:"
echo "  📊 Grafana:  http://$(hostname -I | awk '{print $1}'):3000"
echo "  🗄️  InfluxDB: http://$(hostname -I | awk '{print $1}'):8086"

echo ""
echo "🎯 Für detailliertere Logs: docker compose logs -f [SERVICE]"
