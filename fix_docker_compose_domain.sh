#!/bin/bash
# =============================================================================
# DOCKER COMPOSE DOMAIN FIX - Für dermesser.fritz.box Organization Problem
# =============================================================================

set -e

echo "🐳 DOCKER COMPOSE DOMAIN FIX"
echo "============================="
echo "Problem: Organization not found bei dermesser.fritz.box:3000/grafana/"
echo "Lösung: Docker Compose mit korrekten Environment Variables"
echo ""

cd ~/pi5-sensors

echo "📄 Aktuelle docker-compose.yml Backup erstellen..."
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)

echo ""
echo "🔧 Docker Compose mit DOMAIN-spezifischen Environment Variables neu erstellen..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  influxdb:
    image: influxdb:2.7
    container_name: pi5-influxdb
    restart: unless-stopped
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=pi5sensors2024
      - DOCKER_INFLUXDB_INIT_ORG=pi5org
      - DOCKER_INFLUXDB_INIT_BUCKET=sensors
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=pi5-token-2024
    volumes:
      - influxdb-data:/var/lib/influxdb2

  grafana:
    image: grafana/grafana:latest
    container_name: pi5-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      # 🌐 DOMAIN-SPEZIFISCHE KONFIGURATION für dermesser.fritz.box
      - GF_SERVER_DOMAIN=dermesser.fritz.box
      - GF_SERVER_ROOT_URL=http://dermesser.fritz.box:3000/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      
      # 🚨 NUCLEAR WELCOME SCREEN ELIMINATION
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_ANONYMOUS_ORG_NAME=Pi5SensorOrg
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_SECURITY_ALLOW_EMBEDDING=true
      - GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION=true
      - GF_SECURITY_ADMIN_USER=
      - GF_SECURITY_ADMIN_PASSWORD=
      
      # 🔧 ORGANIZATION FIX
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_USERS_ALLOW_ORG_CREATE=false
      - GF_USERS_AUTO_ASSIGN_ORG=true
      - GF_USERS_AUTO_ASSIGN_ORG_ROLE=Admin
      
      # 📊 ANALYTICS & FEATURES DISABLE
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_SNAPSHOTS_EXTERNAL_ENABLED=false
      - GF_FEATURE_TOGGLES_ENABLE=
      - GF_UNIFIED_ALERTING_ENABLED=false
      - GF_INSTALL_CHECK_FOR_UPDATES=false
      - GF_DATABASE_TYPE=sqlite3
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  grafana-data:
EOF

echo "✅ Neue docker-compose.yml erstellt mit:"
echo "   - GF_SERVER_DOMAIN=dermesser.fritz.box"
echo "   - GF_SERVER_ROOT_URL=http://dermesser.fritz.box:3000/grafana/"
echo "   - GF_SERVER_SERVE_FROM_SUB_PATH=true"
echo "   - GF_AUTH_ANONYMOUS_ORG_NAME=Pi5SensorOrg"
echo "   - Volume Mount für grafana.ini"

echo ""
echo "🔄 Container mit neuer Konfiguration neu starten..."
docker compose down
sleep 3
docker compose up -d

echo ""
echo "⏳ Warte auf Container Initialisierung..."
sleep 15

echo ""
echo "🔍 Container Status prüfen..."
docker ps | grep -E "(pi5-grafana|pi5-influxdb)"

echo ""
echo "🧪 Environment Variables im Container prüfen..."
echo "================================================"
docker exec pi5-grafana env | grep ^GF_ | sort

echo ""
echo "📄 Grafana Konfiguration im Container..."
echo "========================================"
docker exec pi5-grafana cat /etc/grafana/grafana.ini | grep -E "^(domain|root_url|serve_from_sub_path|org_name)" | grep -v "^#"

echo ""
echo "🌐 URL Tests..."
echo "=============="

# Test 1: Health
echo "Health Check:"
curl -s "http://dermesser.fritz.box:3000/grafana/api/health" || echo "❌ Health Check fehlgeschlagen"

echo ""
echo "User API Test:"
user_response=$(curl -s "http://dermesser.fritz.box:3000/grafana/api/user" || echo "ERROR")
echo "$user_response"

if echo "$user_response" | grep -q "organization not found"; then
    echo "❌ Organization Problem NOCH VORHANDEN!"
    echo ""
    echo "🚨 ZUSÄTZLICHE SCHRITTE erforderlich:"
    echo "   1. fix_organization_not_found.sh ausführen"
    echo "   2. Oder komplette Neuinstallation"
elif echo "$user_response" | grep -q "email\|name\|orgId"; then
    echo "✅ Organization Problem GELÖST!"
else
    echo "❓ Organization Status unklar"
fi

echo ""
echo "Welcome Screen Check:"
if curl -s "http://dermesser.fritz.box:3000/grafana/" | grep -qi "welcome.*grafana"; then
    echo "❌ Welcome Screen noch vorhanden"
else
    echo "✅ Kein Welcome Screen!"
fi

echo ""
echo "✅ DOCKER COMPOSE DOMAIN FIX ABGESCHLOSSEN"
echo "=========================================="
echo ""
echo "🎯 TESTEN: http://dermesser.fritz.box:3000/grafana/"
echo ""
echo "🔧 Falls Organization Problem weiterhin besteht:"
echo "   ./fix_organization_not_found.sh"
