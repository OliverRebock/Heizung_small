#!/bin/bash
# =============================================================================
# QUICK FIX - Python Dependencies für Pi 5 Sensor Monitor
# =============================================================================

echo "🔧 QUICK FIX - Installiere fehlende Python Module"
echo "================================================"

# System updaten
echo "📦 Update System..."
sudo apt update

# Python Dependencies installieren
echo "🐍 Installiere Python Dependencies..."
sudo apt install -y python3-pip python3-dev python3-venv

# InfluxDB Client installieren (mehrere Methoden)
echo "📊 Installiere InfluxDB Client..."
sudo pip3 install influxdb-client
pip3 install --user influxdb-client

# Weitere Sensor Dependencies
echo "🔌 Installiere Sensor Libraries..."
sudo pip3 install lgpio adafruit-circuitpython-dht
pip3 install --user lgpio adafruit-circuitpython-dht

# ConfigParser (sollte bereits vorhanden sein)
sudo pip3 install configparser
pip3 install --user configparser

echo ""
echo "✅ Dependencies installiert!"
echo ""
echo "🧪 Teste jetzt:"
echo "cd ~/sensor-monitor"
echo "python3 sensor_monitor.py test"
echo ""
echo "📋 Falls noch Fehler auftreten:"
echo "sudo apt install python3-influxdb"
echo "sudo apt install python3-configparser"
