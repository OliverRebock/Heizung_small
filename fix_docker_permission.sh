#!/bin/bash
# =============================================================================
# Docker Permission Fix für Pi5 Heizungs Messer
# =============================================================================

echo "🔧 Docker Permission Fix"
echo "======================="

# User zur docker group hinzufügen
sudo usermod -aG docker $USER
echo "✅ User $USER zur docker group hinzugefügt"

# Docker Service neustarten
sudo systemctl restart docker
echo "✅ Docker Service neugestartet"

# Container mit sudo starten (falls nötig)
if [ -d "$HOME/pi5-sensors" ]; then
    cd $HOME/pi5-sensors
    echo "🚀 Starte Container mit sudo..."
    sudo docker compose up -d
    echo "✅ Container gestartet"
    
    echo ""
    echo "💡 TIPP: Nach dem nächsten Neustart funktioniert Docker ohne sudo!"
    echo "    sudo reboot"
else
    echo "⚠️ pi5-sensors Verzeichnis nicht gefunden"
fi

echo ""
echo "🧪 Docker Test:"
if docker info &>/dev/null; then
    echo "✅ Docker funktioniert ohne sudo"
else
    echo "⚠️ Docker benötigt noch sudo - Neustart erforderlich"
    echo "   Verwende: sudo docker compose up -d"
fi
