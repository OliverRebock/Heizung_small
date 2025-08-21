#!/bin/bash
"""
Backup und Recovery System für Pi 5 Sensor Monitor
Automatische Sicherung von InfluxDB-Daten und Konfiguration
"""

# Konfiguration
BACKUP_DIR="/home/pi/sensor-backups"
INFLUX_TOKEN="pi5-sensor-token-2024-super-secret"
INFLUX_ORG="Pi5SensorOrg"
INFLUX_BUCKET="sensor_data"
INFLUX_URL="http://localhost:8086"
RETENTION_DAYS=30

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Pi 5 Sensor Monitor - Backup System${NC}"
echo "=================================================="

# Backup-Verzeichnis erstellen
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly" 
mkdir -p "${BACKUP_DIR}/monthly"
mkdir -p "${BACKUP_DIR}/config"

# Zeitstempel
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE_ONLY=$(date +"%Y%m%d")

backup_influxdb() {
    echo -e "${YELLOW}📊 InfluxDB Backup wird erstellt...${NC}"
    
    # InfluxDB Backup
    docker exec pi5-sensor-influxdb influx backup \
        --token "${INFLUX_TOKEN}" \
        --org "${INFLUX_ORG}" \
        "/backups/influxdb_backup_${TIMESTAMP}" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Backup aus Container kopieren
        docker cp pi5-sensor-influxdb:/backups/influxdb_backup_${TIMESTAMP} \
            "${BACKUP_DIR}/daily/"
        
        echo -e "${GREEN}✅ InfluxDB Backup erfolgreich: ${BACKUP_DIR}/daily/influxdb_backup_${TIMESTAMP}${NC}"
    else
        echo -e "${RED}❌ InfluxDB Backup fehlgeschlagen${NC}"
    fi
}

backup_config() {
    echo -e "${YELLOW}⚙️ Konfiguration wird gesichert...${NC}"
    
    # Konfigurationsdateien sichern
    CONFIG_BACKUP="${BACKUP_DIR}/config/config_backup_${TIMESTAMP}.tar.gz"
    
    tar -czf "${CONFIG_BACKUP}" \
        docker-compose.yml \
        config.ini \
        .env \
        grafana_dashboard_*.json \
        prometheus/ \
        grafana/ \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Konfiguration gesichert: ${CONFIG_BACKUP}${NC}"
    else
        echo -e "${RED}❌ Konfiguration-Backup fehlgeschlagen${NC}"
    fi
}

backup_system_info() {
    echo -e "${YELLOW}💻 System-Information wird gesichert...${NC}"
    
    INFO_FILE="${BACKUP_DIR}/daily/system_info_${TIMESTAMP}.txt"
    
    {
        echo "Pi 5 Sensor Monitor - System Backup Info"
        echo "========================================"
        echo "Backup Time: $(date)"
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime)"
        echo ""
        echo "Docker Container Status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "Disk Usage:"
        df -h
        echo ""
        echo "Memory Usage:"
        free -h
        echo ""
        echo "Active Sensors:"
        ls /sys/bus/w1/devices/28-* 2>/dev/null | wc -l
        echo ""
        echo "Python Packages:"
        pip list | grep -E "(lgpio|influxdb|adafruit)"
    } > "${INFO_FILE}"
    
    echo -e "${GREEN}✅ System-Info gesichert: ${INFO_FILE}${NC}"
}

cleanup_old_backups() {
    echo -e "${YELLOW}🧹 Alte Backups werden bereinigt...${NC}"
    
    # Daily backups älter als RETENTION_DAYS löschen
    find "${BACKUP_DIR}/daily" -name "*backup*" -mtime +${RETENTION_DAYS} -delete
    
    # Weekly backups älter als 12 Wochen löschen
    find "${BACKUP_DIR}/weekly" -name "*backup*" -mtime +84 -delete
    
    # Monthly backups älter als 1 Jahr löschen
    find "${BACKUP_DIR}/monthly" -name "*backup*" -mtime +365 -delete
    
    echo -e "${GREEN}✅ Alte Backups bereinigt (>${RETENTION_DAYS} Tage)${NC}"
}

create_weekly_backup() {
    # Jeden Sonntag Weekly-Backup erstellen
    if [ "$(date +%u)" -eq 7 ]; then
        echo -e "${YELLOW}📅 Weekly Backup wird erstellt...${NC}"
        
        # Neuestes Daily-Backup nach Weekly kopieren
        LATEST_DAILY=$(ls -t "${BACKUP_DIR}/daily/influxdb_backup_"* 2>/dev/null | head -1)
        if [ -n "${LATEST_DAILY}" ]; then
            cp -r "${LATEST_DAILY}" "${BACKUP_DIR}/weekly/"
            echo -e "${GREEN}✅ Weekly Backup erstellt${NC}"
        fi
    fi
}

create_monthly_backup() {
    # Am 1. des Monats Monthly-Backup erstellen
    if [ "$(date +%d)" -eq 1 ]; then
        echo -e "${YELLOW}📅 Monthly Backup wird erstellt...${NC}"
        
        # Neuestes Weekly-Backup nach Monthly kopieren
        LATEST_WEEKLY=$(ls -t "${BACKUP_DIR}/weekly/influxdb_backup_"* 2>/dev/null | head -1)
        if [ -n "${LATEST_WEEKLY}" ]; then
            cp -r "${LATEST_WEEKLY}" "${BACKUP_DIR}/monthly/"
            echo -e "${GREEN}✅ Monthly Backup erstellt${NC}"
        fi
    fi
}

restore_backup() {
    local backup_path="$1"
    
    if [ -z "${backup_path}" ]; then
        echo -e "${RED}❌ Backup-Pfad nicht angegeben${NC}"
        echo "Verwendung: $0 restore <backup-pfad>"
        return 1
    fi
    
    if [ ! -d "${backup_path}" ]; then
        echo -e "${RED}❌ Backup-Verzeichnis nicht gefunden: ${backup_path}${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔄 Backup wird wiederhergestellt: ${backup_path}${NC}"
    echo -e "${RED}⚠️  WARNUNG: Alle aktuellen Daten werden überschrieben!${NC}"
    read -p "Fortfahren? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # InfluxDB stoppen
        docker compose stop influxdb
        
        # Backup kopieren und wiederherstellen
        docker cp "${backup_path}" pi5-sensor-influxdb:/backups/restore_backup
        
        docker compose start influxdb
        sleep 10
        
        # Restore durchführen
        docker exec pi5-sensor-influxdb influx restore \
            --token "${INFLUX_TOKEN}" \
            --org "${INFLUX_ORG}" \
            "/backups/restore_backup"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Backup erfolgreich wiederhergestellt${NC}"
        else
            echo -e "${RED}❌ Backup-Wiederherstellung fehlgeschlagen${NC}"
        fi
    else
        echo -e "${YELLOW}❌ Wiederherstellung abgebrochen${NC}"
    fi
}

export_csv_data() {
    echo -e "${YELLOW}📊 CSV-Export wird erstellt...${NC}"
    
    local start_date="${1:-$(date -d '7 days ago' '+%Y-%m-%d')}"
    local end_date="${2:-$(date '+%Y-%m-%d')}"
    
    CSV_DIR="${BACKUP_DIR}/csv_exports"
    mkdir -p "${CSV_DIR}"
    
    # InfluxDB Query für CSV-Export
    local query="from(bucket: \"${INFLUX_BUCKET}\")
        |> range(start: ${start_date}T00:00:00Z, stop: ${end_date}T23:59:59Z)
        |> filter(fn: (r) => r._measurement == \"temperature\" or r._measurement == \"humidity\")
        |> pivot(rowKey:[\"_time\"], columnKey: [\"sensor_name\"], valueColumn: \"_value\")"
    
    # CSV-Export über InfluxDB CLI
    docker exec pi5-sensor-influxdb influx query \
        --token "${INFLUX_TOKEN}" \
        --org "${INFLUX_ORG}" \
        "${query}" \
        --raw > "${CSV_DIR}/sensor_data_${start_date}_to_${end_date}.csv"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ CSV-Export erstellt: ${CSV_DIR}/sensor_data_${start_date}_to_${end_date}.csv${NC}"
    else
        echo -e "${RED}❌ CSV-Export fehlgeschlagen${NC}"
    fi
}

show_backup_status() {
    echo -e "${GREEN}📊 Backup-Status${NC}"
    echo "================"
    
    echo "Backup-Verzeichnis: ${BACKUP_DIR}"
    echo "Retention: ${RETENTION_DAYS} Tage"
    echo ""
    
    echo "Daily Backups:"
    ls -la "${BACKUP_DIR}/daily/" 2>/dev/null | tail -5
    echo ""
    
    echo "Weekly Backups:"
    ls -la "${BACKUP_DIR}/weekly/" 2>/dev/null | tail -3
    echo ""
    
    echo "Monthly Backups:"
    ls -la "${BACKUP_DIR}/monthly/" 2>/dev/null | tail -3
    echo ""
    
    echo "Gesamtgröße:"
    du -sh "${BACKUP_DIR}" 2>/dev/null
}

# Hauptfunktion
case "$1" in
    "daily"|"")
        backup_influxdb
        backup_config
        backup_system_info
        create_weekly_backup
        create_monthly_backup
        cleanup_old_backups
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "export")
        export_csv_data "$2" "$3"
        ;;
    "status")
        show_backup_status
        ;;
    "help")
        echo "Pi 5 Sensor Monitor Backup System"
        echo "================================="
        echo "Verwendung: $0 [OPTION]"
        echo ""
        echo "Optionen:"
        echo "  daily     Tägliches Backup (Standard)"
        echo "  restore   Backup wiederherstellen"
        echo "  export    CSV-Export erstellen"
        echo "  status    Backup-Status anzeigen"
        echo "  help      Diese Hilfe anzeigen"
        echo ""
        echo "Beispiele:"
        echo "  $0                                    # Tägliches Backup"
        echo "  $0 restore /path/to/backup            # Backup wiederherstellen"
        echo "  $0 export 2024-01-01 2024-01-31      # CSV-Export für Januar"
        echo "  $0 status                             # Status anzeigen"
        ;;
    *)
        echo -e "${RED}❌ Unbekannte Option: $1${NC}"
        echo "Verwende '$0 help' für Hilfe"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Backup-Vorgang abgeschlossen${NC}"
