#!/bin/bash
# 🔧 Docker Compose YAML Fix - Löst "unknown anchor 'default-logging'" 
# Repariert YAML anchor/reference Probleme

echo "🔧 Docker Compose YAML Fix"
echo "=========================="

# Prüfe ob docker-compose.yml existiert
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml nicht gefunden!"
    echo "   Bist du im richtigen Verzeichnis?"
    exit 1
fi

echo "📋 Aktuelles docker-compose.yml prüfen..."

# Prüfe auf YAML Probleme
if docker compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml ist bereits korrekt"
    exit 0
else
    echo "❌ YAML Probleme gefunden - wird repariert..."
fi

# Backup erstellen
cp docker-compose.yml docker-compose.yml.backup
echo "💾 Backup erstellt: docker-compose.yml.backup"

# Neues korrektes docker-compose.yml erstellen
echo "🔧 Erstelle korrektes docker-compose.yml..."

cat > docker-compose.yml << 'EOF'
# 📊 LOGGING CONFIGURATION (MUSS AM ANFANG STEHEN!)
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

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
    logging: *default-logging
    healthcheck:
      test: ["CMD", "influx", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  grafana:
    image: grafana/grafana:latest
    container_name: pi5-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      # 🔓 GRAFANA OHNE LOGIN!
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_SECURITY_ALLOW_EMBEDDING=true
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - influxdb
    logging: *default-logging
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  influxdb-data:
  grafana-data:
EOF

# YAML Syntax testen
echo "🧪 Teste YAML Syntax..."
if docker compose config > /dev/null 2>&1; then
    echo "✅ YAML ist jetzt korrekt!"
    
    # Container neu starten
    echo "🚀 Starte Container neu..."
    docker compose down 2>/dev/null || true
    docker compose up -d
    
    echo ""
    echo "🎉 Docker Compose Fix abgeschlossen!"
    echo ""
    echo "📊 Container Status:"
    docker compose ps
    
else
    echo "❌ YAML immer noch fehlerhaft!"
    echo "   Stelle Backup wieder her..."
    mv docker-compose.yml.backup docker-compose.yml
    exit 1
fi

echo ""
echo "💡 YAML REGEL:"
echo "   anchors (&name) müssen VOR references (*name) definiert werden!"
echo "   x-logging: &default-logging MUSS am Anfang stehen"
