# 📋 GitHub Repository erstellen - Anleitung

## 🌐 Repository auf GitHub erstellen

1. **Gehe zu GitHub**: https://github.com/OliverRebock
2. **Klicke auf "New Repository"** (grüner Button)
3. **Repository-Einstellungen**:
   - **Repository name**: `Heizung_small`
   - **Description**: `Raspberry Pi 5 optimized sensor monitoring for 6x DS18B20 + 1x DHT22`
   - **Visibility**: Public ✅
   - **Initialize repository**: ❌ NICHT ankreuzen (wir haben bereits Code)
   - **Add .gitignore**: ❌ NICHT wählen
   - **Add license**: ❌ NICHT wählen

4. **Klicke "Create repository"**

## 🚀 Nach Repository-Erstellung

Führe diese Befehle aus:

```bash
# Im Projekt-Verzeichnis:
cd c:\Users\reboc\OneDrive\Desktop\HeizungsPI2

# Pushe zu GitHub
git push origin main --tags
```

## ✅ Repository-Inhalt

Nach dem Push enthält das Repository:

- `README.md` - Haupt-Dokumentation
- `QUICKSTART.md` - Schnellstart-Anleitung  
- `sensor_monitor.py` - Pi 5 optimiertes Sensor-Script
- `install_sensors.sh` - Automatische Installation
- `sensor_installation_guide.md` - Komplette Hardware-Anleitung
- `test_sensors_fixed.py` - Umfassendes Test-Script
- `.gitignore` - Git-Ignore-Regeln
- `release.sh` - Release-Management

## 🏷️ Release v1.0.0

Das Repository enthält bereits den Tag `v1.0.0` für die erste stabile Version.

Nach dem Push kannst du auf GitHub ein Release erstellen:
1. Gehe zu "Releases" 
2. Klicke "Create a new release"
3. Wähle Tag "v1.0.0"
4. Titel: "Raspberry Pi 5 Sensor Monitor v1.0.0"

## 📊 Repository-Features

- ✅ Raspberry Pi 5 optimiert
- ✅ 6x DS18B20 parallel reading
- ✅ 1x DHT22 mit lgpio
- ✅ High-Performance Modus
- ✅ Automatische Installation
- ✅ Umfassende Diagnose

---

**Repository bereit für GitHub! 🚀**
