#!/bin/bash
# Fix für Docker Compose Version Warning
cd ~/pi5-sensors

echo "🔧 Docker Compose Version Warning Fix"
echo "====================================="
echo "Entferne obsolete 'version' Zeile aus docker-compose.yml"
echo ""

# Backup erstellen
cp docker-compose.yml docker-compose.yml.backup-version-fix

# Version-Zeile entfernen
sed -i '/^version:/d' docker-compose.yml

echo "✅ Version-Zeile entfernt"
echo ""
echo "Vorher:"
head -3 docker-compose.yml.backup-version-fix

echo ""
echo "Nachher:"
head -3 docker-compose.yml

echo ""
echo "🔄 Container neu starten (um Warning zu vermeiden):"
docker compose down
docker compose up -d

echo ""
echo "✅ Docker Compose Version Warning behoben!"
