#!/bin/bash
"""
Setup-Script für individualisierte Sensor-Namen
Konfiguriert das System für 8x DS18B20 + 1x DHT22
"""

echo "🏷️  Setup: Individualisierte Sensor-Namen"
echo "==========================================="

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Prüfe ob config.ini existiert
if [ ! -f "config.ini" ]; then
    echo -e "${RED}❌ config.ini nicht gefunden!${NC}"
    echo "Erstelle zuerst die Basis-Konfiguration"
    exit 1
fi

echo -e "${YELLOW}📝 Konfiguriere individuelle Sensor-Namen...${NC}"

# Interaktive Sensor-Benennung
echo ""
echo "Bitte geben Sie individuelle Namen für Ihre 8 DS18B20 Sensoren ein:"
echo "(Leer lassen für Standard-Namen)"

# Array für Sensor-Namen
declare -a sensor_names

# Standard-Namen als Vorschläge
default_names=(
    "Vorlauf Heizkreis 1"
    "Rücklauf Heizkreis 1" 
    "Vorlauf Heizkreis 2"
    "Rücklauf Heizkreis 2"
    "Warmwasser Speicher"
    "Außentemperatur"
    "Heizraum Ambient"
    "Pufferspeicher Oben"
)

# DS18B20 Sensoren
for i in {1..8}; do
    default_name="${default_names[$((i-1))]}"
    echo ""
    read -p "DS18B20_${i} Name [${default_name}]: " user_input
    
    if [ -z "$user_input" ]; then
        sensor_names[$i]="$default_name"
    else
        sensor_names[$i]="$user_input"
    fi
    
    echo -e "${GREEN}✓ DS18B20_${i} → ${sensor_names[$i]}${NC}"
done

# DHT22 Sensor
echo ""
read -p "DHT22 Name [Raumklima Heizraum]: " dht22_name
if [ -z "$dht22_name" ]; then
    dht22_name="Raumklima Heizraum"
fi
echo -e "${GREEN}✓ DHT22 → ${dht22_name}${NC}"

# Backup der aktuellen config.ini
echo -e "${YELLOW}💾 Erstelle Backup der aktuellen Konfiguration...${NC}"
cp config.ini config.ini.backup.$(date +%Y%m%d_%H%M%S)

# Aktualisiere config.ini mit neuen Namen
echo -e "${YELLOW}✏️  Aktualisiere config.ini...${NC}"

# Temporäre Datei für neue config.ini
temp_file=$(mktemp)

# Labels-Sektion erstellen
{
    # Alles bis zur [labels] Sektion kopieren
    sed '/^\[labels\]/,$d' config.ini
    
    # Neue Labels-Sektion hinzufügen
    echo ""
    echo "# Sensor Labels (für Grafana und InfluxDB)"
    echo "[labels]"
    
    for i in {1..8}; do
        echo "ds18b20_${i} = \"${sensor_names[$i]}\""
    done
    
    echo "dht22 = \"${dht22_name}\""
    
    # Alles nach der [labels] Sektion (falls vorhanden)
    sed -n '/^\[labels\]/,/^\[/p' config.ini | sed '1d' | sed '$d' > /dev/null 2>&1
    
    # Nächste Sektion finden und ab dort kopieren
    next_section=$(sed -n '/^\[labels\]/,/^\[/p' config.ini | tail -1)
    if [ ! -z "$next_section" ] && [ "$next_section" != "[labels]" ]; then
        sed -n "/^${next_section//[/\\[}/,\$p" config.ini
    fi
    
} > "$temp_file"

# Temporäre Datei nach config.ini kopieren
mv "$temp_file" config.ini

echo -e "${GREEN}✅ config.ini wurde aktualisiert${NC}"

# Test der individualisierten Sensoren
echo ""
echo -e "${YELLOW}🧪 Teste individualisierte Sensor-Namen...${NC}"

if python3 individualized_sensors.py > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Individualisierte Sensoren funktionieren${NC}"
else
    echo -e "${RED}❌ Fehler bei individualisierten Sensoren${NC}"
    echo "Prüfe die Python-Dependencies:"
    echo "pip install -r requirements.txt"
fi

# InfluxDB Test
echo ""
echo -e "${YELLOW}🗄️  Teste InfluxDB Integration...${NC}"

if python3 influxdb_individualized.py > /dev/null 2>&1; then
    echo -e "${GREEN}✅ InfluxDB Integration funktioniert${NC}"
else
    echo -e "${YELLOW}⚠️  InfluxDB nicht verfügbar (normal wenn Docker nicht läuft)${NC}"
fi

# Zusammenfassung
echo ""
echo -e "${GREEN}🎉 Setup abgeschlossen!${NC}"
echo "================================"
echo ""
echo "📋 Ihre konfigurierten Sensoren:"
for i in {1..8}; do
    echo "   DS18B20_${i} → ${sensor_names[$i]}"
done
echo "   DHT22     → ${dht22_name}"
echo ""
echo "📄 Nächste Schritte:"
echo "💡 python individualized_sensors.py     # Sensor-Namen testen"
echo "💡 python influxdb_individualized.py    # InfluxDB mit Namen"
echo "💡 nano config.ini                      # Namen manuell anpassen"
echo ""
echo "🔄 Backup erstellt: config.ini.backup.*"

# Grafana Dashboard Info
echo ""
echo -e "${YELLOW}📊 Grafana Dashboard Update:${NC}"
echo "Die Dashboards werden automatisch die neuen Namen verwenden."
echo "Bei Problemen können Sie die Dashboards neu importieren."
