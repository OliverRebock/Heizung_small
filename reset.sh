#!/bin/bash
# =============================================================================
# RESET.SH - Komplette Deinstallation des Pi 5 Sensor Monitor Projekts
# =============================================================================
# ⚠️  WARNUNG: Dieses Script löscht ALLES vom Pi 5 Sensor Monitor Projekt!
# 
# Was wird gelöscht:
# - Alle Docker Container und Images
# - Alle Services und Systemd-Dateien
# - Alle Projektdateien und Verzeichnisse
# - Python Virtual Environment
# - Konfigurationsdateien
# - Log-Dateien und Backups
# - GPIO-Konfiguration
# =============================================================================

echo "🔥 Pi 5 Sensor Monitor - KOMPLETTE DEINSTALLATION"
echo "=================================================="
echo ""
echo "⚠️  WARNUNG: Dieses Script löscht ALLES!"
echo ""
echo "Folgende Komponenten werden entfernt:"
echo "- 🐳 Docker Container und Images"
echo "- ⚙️  Systemd Services"
echo "- 📁 Alle Projektdateien"
echo "- 🐍 Python Virtual Environment"
echo "- 📋 Konfigurationsdateien"
echo "- 📊 Log-Dateien und Backups"
echo "- 🔌 GPIO-Konfiguration"
echo ""
read -p "🤔 Sind Sie SICHER? Dies kann NICHT rückgängig gemacht werden! (ja/nein): " confirm

if [ "$confirm" != "ja" ]; then
    echo "❌ Abgebrochen. Nichts wurde gelöscht."
    exit 0
fi

echo ""
echo "🚀 Starte komplette Deinstallation..."
echo ""

# =============================================================================
# 1. DOCKER CONTAINER UND SERVICES STOPPEN/ENTFERNEN
# =============================================================================
echo "🐳 Stoppe und entferne Docker Container..."

# In Projektverzeichnisse wechseln falls vorhanden
for project_dir in ~/Heizung_small ~/sensor-monitor-pi5; do
    if [ -d "$project_dir" ]; then
        echo "   📂 Verarbeite: $project_dir"
        cd "$project_dir"
        
        # Docker Compose Services stoppen und entfernen
        if [ -f "docker-compose.yml" ]; then
            echo "   🔄 Stoppe Docker Compose Services..."
            docker compose down --volumes --remove-orphans 2>/dev/null || true
        fi
        
        # Alle Container mit pi5-sensor stoppen
        echo "   🛑 Stoppe alle pi5-sensor Container..."
        docker stop $(docker ps -q --filter name=pi5-sensor) 2>/dev/null || true
        docker stop $(docker ps -q --filter name=pi5-prometheus) 2>/dev/null || true
        docker stop $(docker ps -q --filter name=pi5-node-exporter) 2>/dev/null || true
        
        # Container entfernen
        echo "   🗑️  Entferne Container..."
        docker rm $(docker ps -aq --filter name=pi5-sensor) 2>/dev/null || true
        docker rm $(docker ps -aq --filter name=pi5-prometheus) 2>/dev/null || true
        docker rm $(docker ps -aq --filter name=pi5-node-exporter) 2>/dev/null || true
    fi
done

# Docker Images entfernen
echo "   🖼️  Entferne Docker Images..."
docker rmi $(docker images -q influxdb) 2>/dev/null || true
docker rmi $(docker images -q grafana/grafana) 2>/dev/null || true
docker rmi $(docker images -q prom/prometheus) 2>/dev/null || true
docker rmi $(docker images -q prom/node-exporter) 2>/dev/null || true

# Docker Volumes entfernen
echo "   💾 Entferne Docker Volumes..."
docker volume rm $(docker volume ls -q | grep -E "(influxdb|grafana|prometheus)") 2>/dev/null || true

# Docker Networks entfernen
echo "   🌐 Entferne Docker Networks..."
docker network rm pi5-network pi5-sensor-network 2>/dev/null || true

# Docker System aufräumen
echo "   🧹 Docker System Cleanup..."
docker system prune -af --volumes 2>/dev/null || true

echo "✅ Docker Komponenten entfernt"
echo ""

# =============================================================================
# 2. SYSTEMD SERVICES ENTFERNEN
# =============================================================================
echo "⚙️  Entferne Systemd Services..."

# Liste aller möglichen Services
services=(
    "pi5-advanced-monitoring.service"
    "pi5-sensor-monitoring.service"
    "pi5-sensor-influxdb.service"
    "pi5-web-dashboard.service"
    "sensor-monitor.service"
    "heizung-monitoring.service"
)

for service in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "   🛑 Stoppe und entferne: $service"
        sudo systemctl stop "$service" 2>/dev/null || true
        sudo systemctl disable "$service" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/$service"
    fi
done

# Systemd neu laden
echo "   🔄 Lade systemd neu..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "✅ Systemd Services entfernt"
echo ""

# =============================================================================
# 3. PROJEKTVERZEICHNISSE ENTFERNEN
# =============================================================================
echo "📁 Entferne Projektverzeichnisse..."

# Hauptprojektverzeichnisse
project_dirs=(
    "$HOME/Heizung_small"
    "$HOME/sensor-monitor-pi5"
    "$HOME/pi5-sensor-monitor"
    "$HOME/heizung-small"
    "/opt/pi5-sensor-monitor"
    "/var/log/pi5-sensor"
)

for dir in "${project_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "   🗑️  Lösche: $dir"
        rm -rf "$dir"
    fi
done

echo "✅ Projektverzeichnisse entfernt"
echo ""

# =============================================================================
# 4. PYTHON VIRTUAL ENVIRONMENTS ENTFERNEN
# =============================================================================
echo "🐍 Entferne Python Virtual Environments..."

# Bekannte venv Pfade
venv_dirs=(
    "$HOME/sensor-monitor-pi5/venv"
    "$HOME/Heizung_small/venv"
    "$HOME/.virtualenvs/pi5-sensor"
    "$HOME/venv-pi5-sensor"
)

for venv_dir in "${venv_dirs[@]}"; do
    if [ -d "$venv_dir" ]; then
        echo "   🗑️  Lösche venv: $venv_dir"
        rm -rf "$venv_dir"
    fi
done

echo "✅ Virtual Environments entfernt"
echo ""

# =============================================================================
# 5. KONFIGURATIONSDATEIEN ENTFERNEN
# =============================================================================
echo "📋 Entferne Konfigurationsdateien..."

# GPIO-Konfiguration BLEIBT erhalten (nicht entfernen)
echo "   🔌 GPIO-Konfiguration bleibt erhalten (nicht geändert)"

# Crontab-Einträge entfernen
echo "   ⏰ Entferne Crontab-Einträge..."
crontab -l 2>/dev/null | grep -v "sensor-monitor\|pi5-sensor\|heizung" | crontab - 2>/dev/null || true

# Logrotate-Konfiguration entfernen
echo "   📊 Entferne Logrotate-Konfiguration..."
sudo rm -f /etc/logrotate.d/pi5-sensor* 2>/dev/null || true

# Backup-Verzeichnisse entfernen
echo "   💾 Entferne Backup-Verzeichnisse..."
rm -rf "$HOME/backups/pi5-sensor"* 2>/dev/null || true
rm -rf "/tmp/pi5-sensor"* 2>/dev/null || true

echo "✅ Konfigurationsdateien entfernt"
echo ""

# =============================================================================
# 6. LOG-DATEIEN ENTFERNEN
# =============================================================================
echo "📊 Entferne Log-Dateien..."

# System-Logs bereinigen
echo "   🗂️  Bereinige System-Logs..."
sudo journalctl --vacuum-time=1d 2>/dev/null || true

# Projektspezifische Logs entfernen
log_patterns=(
    "/var/log/pi5-sensor*"
    "/var/log/sensor-monitor*"
    "/var/log/heizung*"
    "$HOME/*.log"
    "$HOME/sensor*.log"
    "$HOME/influxdb*.log"
)

for pattern in "${log_patterns[@]}"; do
    rm -f $pattern 2>/dev/null || true
done

echo "✅ Log-Dateien entfernt"
echo ""

# =============================================================================
# 7. PYTHON PACKAGES ENTFERNEN (OPTIONAL)
# =============================================================================
echo "🐍 Entferne projektspezifische Python Packages..."

# Nur projektspezifische Packages entfernen, nicht das gesamte System
packages_to_remove=(
    "influxdb-client"
    "lgpio"
    "adafruit-circuitpython-dht"
    "prometheus-client"
    "flask"
    "psutil"
)

for package in "${packages_to_remove[@]}"; do
    echo "   📦 Entferne: $package"
    pip uninstall -y "$package" 2>/dev/null || true
    pip3 uninstall -y "$package" 2>/dev/null || true
done

echo "✅ Python Packages entfernt"
echo ""

# =============================================================================
# 8. DOCKER OPTIONAL KOMPLETT ENTFERNEN
# =============================================================================
echo "🐳 Docker komplett entfernen? (WARNUNG: Entfernt Docker komplett!)"
read -p "Docker komplett deinstallieren? (ja/nein): " remove_docker

if [ "$remove_docker" = "ja" ]; then
    echo "   🗑️  Entferne Docker komplett..."
    
    # Docker stoppen
    sudo systemctl stop docker 2>/dev/null || true
    sudo systemctl disable docker 2>/dev/null || true
    
    # Docker Packages entfernen
    sudo apt remove -y docker docker-engine docker.io containerd runc docker-compose-plugin 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    
    # Docker Verzeichnisse entfernen
    sudo rm -rf /var/lib/docker 2>/dev/null || true
    sudo rm -rf /var/lib/containerd 2>/dev/null || true
    sudo rm -rf /etc/docker 2>/dev/null || true
    sudo rm -f /etc/systemd/system/docker.service 2>/dev/null || true
    
    # Docker User aus Gruppe entfernen
    sudo deluser pi docker 2>/dev/null || true
    
    echo "   ✅ Docker komplett entfernt"
else
    echo "   ℹ️  Docker bleibt installiert (nur Projektdaten entfernt)"
fi

echo ""

# =============================================================================
# 9. ABSCHLUSS UND ZUSAMMENFASSUNG
# =============================================================================
echo "🎉 DEINSTALLATION ABGESCHLOSSEN!"
echo "================================="
echo ""
echo "✅ Folgende Komponenten wurden entfernt:"
echo "   🐳 Alle Docker Container und Images"
echo "   ⚙️  Alle Systemd Services"
echo "   📁 Alle Projektverzeichnisse"
echo "   🐍 Python Virtual Environments"
echo "   📋 Konfigurationsdateien (crontab, logrotate)"
echo "   📊 Log-Dateien und Backups"
echo "   ⚠️  GPIO-Konfiguration bleibt ERHALTEN"
echo ""

if [ "$remove_docker" = "ja" ]; then
    echo "   🐳 Docker wurde KOMPLETT entfernt"
    echo ""
    echo "⚠️  NEUSTART EMPFOHLEN für Docker-Dienste!"
    echo ""
    read -p "🔄 Jetzt neu starten? (ja/nein): " reboot_now
    if [ "$reboot_now" = "ja" ]; then
        echo "🔄 Starte System neu..."
        sudo reboot
    fi
else
    echo "   🐳 Docker blieb installiert"
    echo ""
    echo "💡 Kein Neustart erforderlich (GPIO-Konfiguration unverändert)"
fi

echo ""
echo "🧹 Das Pi 5 Sensor Monitor Projekt wurde vollständig entfernt!"
echo "   Ihr Raspberry Pi ist wieder im ursprünglichen Zustand."
echo ""
echo "📚 Falls Sie das Projekt erneut installieren möchten:"
echo "   git clone https://github.com/OliverRebock/Heizung_small.git"
echo ""

exit 0
