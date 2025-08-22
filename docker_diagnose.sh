#!/bin/bash
# =============================================================================
# DOCKER DIAGNOSE SCRIPT - Bei Installation-Problemen
# =============================================================================

echo "🔍 DOCKER DIAGNOSE"
echo "=================="
echo ""

# 1. Docker Service Status
echo "📊 DOCKER SERVICE STATUS:"
sudo systemctl status docker --no-pager -l
echo ""

# 2. Docker Version
echo "🐳 DOCKER VERSION:"
docker --version 2>/dev/null || echo "❌ Docker Command nicht verfügbar"
echo ""

# 3. Docker Daemon Konfiguration
echo "⚙️ DOCKER DAEMON CONFIG:"
if [ -f "/etc/docker/daemon.json" ]; then
    echo "✅ daemon.json gefunden:"
    cat /etc/docker/daemon.json
    echo ""
    echo "🔍 JSON Syntax Check:"
    python3 -m json.tool /etc/docker/daemon.json > /dev/null 2>&1 && echo "✅ JSON Syntax OK" || echo "❌ JSON Syntax FEHLER"
else
    echo "⚠️  Keine daemon.json gefunden"
fi
echo ""

# 4. Docker Logs
echo "📋 DOCKER SERVICE LOGS (letzte 20 Zeilen):"
sudo journalctl -u docker.service --no-pager -n 20
echo ""

# 5. Docker Storage
echo "💾 DOCKER STORAGE:"
sudo docker system df 2>/dev/null || echo "❌ Docker nicht erreichbar"
echo ""

# 6. Docker Networks
echo "🌐 DOCKER NETWORKS:"
sudo docker network ls 2>/dev/null || echo "❌ Docker nicht erreichbar"
echo ""

# 7. System Resources
echo "📊 SYSTEM RESOURCES:"
echo "RAM:  $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
echo "Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
echo "CPU:  $(vcgencmd measure_temp 2>/dev/null || echo 'Temperatur nicht verfügbar')"
echo ""

# 8. Lösungsvorschläge
echo "🔧 LÖSUNGSVORSCHLÄGE:"
echo ""
echo "Falls Docker nicht startet:"
echo "1. Entferne daemon.json:     sudo rm /etc/docker/daemon.json"
echo "2. Starte Docker neu:       sudo systemctl restart docker"
echo "3. Prüfe Status:            sudo systemctl status docker"
echo ""
echo "Falls JSON Syntax-Fehler:"
echo "1. Prüfe daemon.json:       python3 -m json.tool /etc/docker/daemon.json"
echo "2. Repariere oder entferne: sudo nano /etc/docker/daemon.json"
echo ""
echo "Installation ohne Optimierung fortsetzen:"
echo "1. Entferne daemon.json:     sudo rm -f /etc/docker/daemon.json"
echo "2. Neustarte Installation:   ./install_minimal.sh"
