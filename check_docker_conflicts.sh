#!/bin/bash
# =============================================================================
# DOCKER KONFLIKT-CHECK - Prüft existierende Docker Services vor Installation
# =============================================================================

echo "🔍 DOCKER KONFLIKT-CHECK"
echo "========================"
echo "Prüft ob bereits Docker Services laufen die Konflikte verursachen könnten"
echo ""

# Docker Status prüfen
if ! command -v docker &> /dev/null; then
    echo "✅ Docker nicht installiert - keine Konflikte möglich"
    echo "   → Verwende normale Installation:"
    echo "   curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
    exit 0
fi

echo "🐳 Docker gefunden - prüfe laufende Services..."
echo ""

# Laufende Container prüfen
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "(grafana|influxdb)" || echo "")

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "✅ KEINE KONFLIKTE - Keine Grafana/InfluxDB Container laufen"
    echo ""
    echo "📋 EMPFEHLUNG: Normale Installation verwenden"
    echo "   curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
else
    echo "⚠️  KONFLIKTE ERKANNT:"
    echo "===================="
    echo "$RUNNING_CONTAINERS"
    echo ""
    
    # Port-Konflikte prüfen
    echo "🌐 PORT-KONFLIKTE PRÜFEN:"
    echo "========================="
    
    PORT_3000_USED=false
    PORT_8086_USED=false
    
    if netstat -tuln 2>/dev/null | grep -q ":3000 " || docker ps | grep -q "3000:"; then
        echo "❌ Port 3000 (Grafana) bereits belegt"
        PORT_3000_USED=true
    else
        echo "✅ Port 3000 frei"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":8086 " || docker ps | grep -q "8086:"; then
        echo "❌ Port 8086 (InfluxDB) bereits belegt"
        PORT_8086_USED=true
    else
        echo "✅ Port 8086 frei"
    fi
    
    echo ""
    echo "🚨 EMPFEHLUNG: KONFLIKT-SICHERE Installation verwenden!"
    echo "======================================================"
    echo ""
    echo "# Basis Installation (KONFLIKT-SICHER):"
    echo "curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_existing_docker.sh | bash"
    echo ""
    echo "# Mit Home Assistant MQTT (KONFLIKT-SICHER):"
    echo "curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_mqtt_existing_docker.sh | bash -s -- HA_IP MQTT_USER MQTT_PASS"
    echo ""
    echo "📦 KONFLIKT-SICHERE FEATURES:"
    echo "   - Verwendet Ports 3001/8087 (falls 3000/8086 belegt)"
    echo "   - Container Namen: pi5-sensors-grafana, pi5-sensors-influxdb"
    echo "   - Eigenes Docker Network: pi5-sensors-network"
    echo "   - Keine Interferenz mit existierenden Services"
fi

echo ""
echo "🔧 ALTERNATIVE: Existierende Services stoppen"
echo "=============================================="
echo "Falls du die normalen Ports (3000/8086) verwenden möchtest:"
echo ""

if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "# Existierende Grafana/InfluxDB Container stoppen:"
    docker ps | grep -E "(grafana|influxdb)" | awk '{print $1}' | while read container; do
        container_name=$(docker ps | grep "$container" | awk '{print $NF}')
        echo "docker stop $container_name"
    done
    echo ""
    echo "# Dann normale Installation ausführen:"
    echo "curl -sSL https://raw.githubusercontent.com/OliverRebock/Heizung_small/main/install_simple.sh | bash"
fi

echo ""
echo "💡 ZUSÄTZLICHE INFORMATIONEN:"
echo "============================"
echo "# Alle Docker Container anzeigen:"
echo "docker ps -a"
echo ""
echo "# Verwendete Ports anzeigen:"
echo "netstat -tuln | grep -E ':(3000|8086) '"
echo ""
echo "# Existierende Docker Volumes anzeigen:"
echo "docker volume ls | grep -E '(grafana|influxdb)'"
