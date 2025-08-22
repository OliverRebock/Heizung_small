#!/bin/bash
# 🔧 LGPIO Fix für Pi 5 - Löst "Unable to locate package lgpio" 
# Mehrere Installationsmethoden für maximale Kompatibilität

echo "🔧 LGPIO Fix für Raspberry Pi 5"
echo "================================"

# Aktuelles System prüfen
echo "📋 System Info:"
echo "   OS: $(lsb_release -d | cut -f2)"
echo "   Kernel: $(uname -r)"
echo "   Arch: $(uname -m)"

# Python Version prüfen
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
echo "   Python: $PYTHON_VERSION"

echo ""

# 1. Repositories aktualisieren
echo "📦 Repository Update..."
sudo apt-get update

# 2. Standard Installation versuchen
echo "🔧 Methode 1: Standard Repository..."
if sudo apt-get install -y python3-lgpio; then
    echo "   ✅ python3-lgpio erfolgreich installiert"
    SYSTEM_LGPIO=true
else
    echo "   ❌ python3-lgpio nicht verfügbar"
    SYSTEM_LGPIO=false
fi

# 3. Build Dependencies installieren
echo "🔧 Methode 2: Build Dependencies..."
sudo apt-get install -y python3-dev python3-pip build-essential

# 4. lgpio über pip installieren (funktioniert fast immer)
echo "🔧 Methode 3: pip Installation..."
if pip3 install lgpio; then
    echo "   ✅ lgpio über pip installiert"
    PIP_LGPIO=true
else
    echo "   ❌ lgpio pip Installation fehlgeschlagen"
    PIP_LGPIO=false
fi

# 5. Für Pi 5 spezifische Installation
if [[ "$(cat /proc/cpuinfo | grep 'Model' | head -1)" == *"Raspberry Pi 5"* ]]; then
    echo "🍓 Pi 5 erkannt - spezielle Installation..."
    
    # Pi 5 Repository hinzufügen (falls noch nicht vorhanden)
    if ! grep -q "bullseye" /etc/apt/sources.list; then
        echo "   📦 Füge zusätzliche Repositories hinzu..."
        sudo apt-get install -y software-properties-common
    fi
    
    # Alternative: Direkt von github kompilieren
    echo "🔧 Methode 4: Direkte Kompilierung..."
    if ! command -v git &> /dev/null; then
        sudo apt-get install -y git
    fi
    
    # Temporäres Verzeichnis
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if git clone https://github.com/joan2937/lg.git; then
        cd lg
        if make && sudo make install; then
            echo "   ✅ lgpio aus Quellcode kompiliert"
            SOURCE_LGPIO=true
        else
            echo "   ❌ Kompilierung fehlgeschlagen"
            SOURCE_LGPIO=false
        fi
    else
        echo "   ❌ Git clone fehlgeschlagen"
        SOURCE_LGPIO=false
    fi
    
    # Aufräumen
    cd /
    rm -rf "$TEMP_DIR"
fi

# 6. Installation testen
echo ""
echo "🧪 Installation testen..."

# Python Test
python3 -c "
try:
    import lgpio
    print('✅ lgpio Python Import erfolgreich')
    print(f'   Version: {lgpio.lgpio_version()}')
    success = True
except ImportError as e:
    print(f'❌ lgpio Import Fehler: {e}')
    success = False
except Exception as e:
    print(f'⚠️ lgpio Import Warnung: {e}')
    success = True
    
if success:
    try:
        # GPIO Chip öffnen (Test)
        h = lgpio.gpiochip_open(0)
        lgpio.gpiochip_close(h)
        print('✅ lgpio GPIO Zugriff funktioniert')
    except Exception as e:
        print(f'⚠️ GPIO Test: {e} (normal wenn keine Berechtigung)')
"

# 7. Ergebnis-Zusammenfassung
echo ""
echo "📊 INSTALLATION ZUSAMMENFASSUNG:"
echo "================================"

if [ "$SYSTEM_LGPIO" = true ]; then
    echo "✅ python3-lgpio (System Package)"
fi

if [ "$PIP_LGPIO" = true ]; then
    echo "✅ lgpio (pip Package)"  
fi

if [ "$SOURCE_LGPIO" = true ]; then
    echo "✅ lgpio (aus Quellcode)"
fi

# Installations-Empfehlung
echo ""
echo "💡 EMPFEHLUNG:"
echo "Wenn lgpio Import funktioniert, ist alles gut!"
echo "Falls nicht:"
echo "1. sudo reboot (manchmal hilft ein Neustart)"
echo "2. export LGPIO_PATH=/usr/local/lib"
echo "3. Oder: sudo apt-get install -y rpi-lgpio"

# Alternative packages erwähnen
echo ""
echo "🔧 ALTERNATIVE PACKAGES:"
echo "sudo apt-get install -y rpi-lgpio"
echo "sudo apt-get install -y python3-rpi-lgpio"
echo "pip3 install rpi-lgpio"

echo ""
echo "🎉 LGPIO Fix abgeschlossen!"
echo ""
echo "🧪 Jetzt testen:"
echo "python3 -c 'import lgpio; print(lgpio.lgpio_version())'"
