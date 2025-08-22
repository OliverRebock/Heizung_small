#!/bin/bash
# =============================================================================
# SCHNELLE DOCKER-REPARATUR - Bei Installation-Problemen
# =============================================================================

echo "🔧 SCHNELLE DOCKER-REPARATUR"
echo "============================="
echo ""

# 1. Aktueller Docker Status
echo "📊 AKTUELLER DOCKER STATUS:"
if command -v docker &> /dev/null; then
    echo "✅ Docker Command verfügbar: $(docker --version)"
else
    echo "❌ Docker Command nicht verfügbar"
fi

if sudo systemctl is-active --quiet docker; then
    echo "✅ Docker Service aktiv"
else
    echo "❌ Docker Service inaktiv"
fi
echo ""

# 2. Problematische Dateien entfernen
echo "🗑️ ENTFERNE PROBLEMATISCHE KONFIGURATIONEN:"
if [ -f "/etc/docker/daemon.json" ]; then
    echo "   📋 Entferne /etc/docker/daemon.json..."
    sudo rm -f /etc/docker/daemon.json
    echo "   ✅ daemon.json entfernt"
else
    echo "   ✅ Keine daemon.json gefunden"
fi

# 3. Docker komplett stoppen
echo ""
echo "🛑 STOPPE DOCKER SERVICES:"
sudo systemctl stop docker.service 2>/dev/null || true
sudo systemctl stop docker.socket 2>/dev/null || true
echo "   ✅ Docker Services gestoppt"

# 4. Docker neu starten (ohne enable!)
echo ""
echo "🚀 STARTE DOCKER NEU:"
if sudo systemctl start docker.service 2>/dev/null; then
    sleep 5
    if sudo systemctl is-active --quiet docker; then
        echo "   ✅ Docker erfolgreich gestartet!"
        
        # Test Docker Funktionalität
        if docker --version > /dev/null 2>&1; then
            echo "   ✅ Docker Command funktioniert"
            echo ""
            echo "🎉 DOCKER-REPARATUR ERFOLGREICH!"
            echo ""
            echo "   💡 Jetzt kannst du install_minimal.sh erneut ausführen"
        else
            echo "   ⚠️  Docker Command funktioniert nicht richtig"
        fi
    else
        echo "   ❌ Docker konnte nicht gestartet werden"
        echo ""
        echo "💀 DOCKER-REPARATUR FEHLGESCHLAGEN"
        echo ""
        echo "🔧 MANUELLE REPARATUR NÖTIG:"
        echo "   1. sudo apt remove docker-ce docker-ce-cli containerd.io"
        echo "   2. sudo apt autoremove"
        echo "   3. sudo rm -rf /etc/docker /var/lib/docker"
        echo "   4. sudo reboot"
        echo "   5. Dann install_minimal.sh erneut ausführen"
    fi
else
    echo "   ❌ Docker Service start fehlgeschlagen"
    echo ""
    echo "📋 SYSTEMCTL STATUS:"
    sudo systemctl status docker.service --no-pager -l || true
    echo ""
    echo "📋 JOURNAL LOGS:"
    sudo journalctl -u docker.service --no-pager -n 10 || true
fi

echo ""
echo "🔍 FINALE DIAGNOSE:"
echo "   Docker Version: $(docker --version 2>/dev/null || echo 'Nicht verfügbar')"
echo "   Service Status: $(sudo systemctl is-active docker 2>/dev/null || echo 'Inaktiv')"
echo "   User Groups:    $(groups $USER | grep -q docker && echo 'Docker-Gruppe OK' || echo 'Neustart für Docker-Gruppe nötig')"
