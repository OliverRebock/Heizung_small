#!/bin/bash
# Release-Script für Heizung_small
# Erstellt einen neuen Git-Tag und Release

VERSION="v1.0.0"
RELEASE_NAME="Raspberry Pi 5 Sensor Monitor v1.0.0"

echo "🚀 Erstelle Release $VERSION für Heizung_small"

# Füge neue Dateien hinzu
git add QUICKSTART.md

# Commit
git commit -m "Add QuickStart guide and prepare v1.0.0 release

- QUICKSTART.md für schnelle Installation
- Ready for v1.0.0 release
- Raspberry Pi 5 optimized sensor monitoring"

# Tag erstellen
git tag -a $VERSION -m "$RELEASE_NAME

Features:
- 6x DS18B20 parallel reading
- 1x DHT22 with Pi 5 optimizations
- lgpio support for Pi 5
- High-performance mode
- Automatic installation
- Comprehensive diagnostics

Hardware:
- Raspberry Pi 5
- DS18B20 temperature sensors
- DHT22 humidity/temperature sensor
- Pull-up resistors"

echo "✅ Tag $VERSION erstellt"
echo "💡 Führe aus: git push origin main --tags"
echo "💡 Dann auf GitHub Release erstellen"
