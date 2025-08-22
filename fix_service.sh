#!/bin/bash
# Service-Fix Script für pi5-advanced-monitoring.service
echo "🔧 Repariere pi5-advanced-monitoring.service..."

# Service stoppen und deaktivieren
echo "⏹️  Stoppe alten Service..."
sudo systemctl stop pi5-advanced-monitoring.service 2>/dev/null || true
sudo systemctl disable pi5-advanced-monitoring.service 2>/dev/null || true

# Alte Service-Datei entfernen
echo "🗑️  Entferne fehlerhafte Service-Datei..."
sudo rm -f /etc/systemd/system/pi5-advanced-monitoring.service

# Systemd Cache leeren
echo "🔄 Lade systemd neu..."
sudo systemctl daemon-reload

# Prüfe ob neue Service-Datei existiert
if [ -f "pi5-advanced-monitoring.service" ]; then
    echo "✅ Installiere neue Service-Datei..."
    sudo cp pi5-advanced-monitoring.service /etc/systemd/system/
    
    # Service aktivieren
    echo "🚀 Aktiviere Service..."
    sudo systemctl daemon-reload
    sudo systemctl enable pi5-advanced-monitoring.service
    sudo systemctl start pi5-advanced-monitoring.service
    
    echo "📊 Service-Status:"
    sudo systemctl status pi5-advanced-monitoring.service --no-pager -l
else
    echo "❌ Fehler: pi5-advanced-monitoring.service nicht gefunden!"
    echo "💡 Führe 'git pull origin main' aus um die neueste Version zu erhalten"
    exit 1
fi

echo "✅ Service-Reparatur abgeschlossen!"
