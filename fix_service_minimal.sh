#!/bin/bash
# =============================================================================
# SERVICE FIX MINIMAL - Mit Python venv (WICHTIG für DHT22!)
# =============================================================================

echo "🔧 SERVICE FIX - Mit Python venv für DHT22 Sensor"
echo "================================================="

# Service stoppen
echo "🛑 Stoppe Service..."
sudo systemctl stop pi5-sensor-minimal.service 2>/dev/null || true

# Ins Projektverzeichnis wechseln
cd /home/pi/sensor-monitor

# Python venv erstellen falls nicht vorhanden
echo "� Erstelle/Prüfe Python Virtual Environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# venv aktivieren und Dependencies installieren
echo "📦 Installiere Dependencies in venv..."
source venv/bin/activate
pip install --upgrade pip
pip install influxdb-client lgpio adafruit-circuitpython-dht configparser

# Korrigierten Service erstellen (mit venv!)
echo "⚙️ Erstelle korrigierten Service (mit venv)..."
sudo tee /etc/systemd/system/pi5-sensor-minimal.service > /dev/null << 'EOF'
[Unit]
Description=Pi 5 Sensor Monitor (Minimal with venv)
After=docker.service network.target
Requires=docker.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/sensor-monitor
ExecStartPre=/bin/sleep 30
ExecStartPre=/usr/bin/docker compose up -d
ExecStart=/home/pi/sensor-monitor/venv/bin/python sensor_monitor.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Service neu laden
echo "🔄 Lade Service neu..."
sudo systemctl daemon-reload
sudo systemctl enable pi5-sensor-minimal.service

# Test der Python Module (in venv)
echo "🧪 Teste Python Module in venv..."
source venv/bin/activate

echo ""
echo "📦 Teste Module:"
python -c "import influxdb_client; print('✅ influxdb_client OK')" || echo "❌ influxdb_client FEHLT"
python -c "import lgpio; print('✅ lgpio OK')" || echo "❌ lgpio FEHLT"
python -c "import configparser; print('✅ configparser OK')" || echo "❌ configparser FEHLT"

echo ""
echo "🚀 Teste Sensor Script..."
python sensor_monitor.py test

echo ""
echo "🔄 Starte Service..."
sudo systemctl start pi5-sensor-minimal.service

echo ""
echo "📊 Service Status:"
sudo systemctl status pi5-sensor-minimal.service --no-pager

echo ""
echo "✅ SERVICE FIX MIT VENV ABGESCHLOSSEN!"
echo ""
echo "🔍 Logs prüfen:"
echo "sudo journalctl -u pi5-sensor-minimal -f"
