#!/bin/bash
# =============================================================================
# SERVICE FIX MINIMAL - Repariert pi5-sensor-minimal Service 
# =============================================================================

echo "🔧 SERVICE FIX - Repariere pi5-sensor-minimal Service"
echo "===================================================="

# Service stoppen
echo "🛑 Stoppe Service..."
sudo systemctl stop pi5-sensor-minimal.service 2>/dev/null || true

# Dependencies nochmals installieren (robust)
echo "🐍 Installiere Python Dependencies (robust)..."
sudo apt update
sudo apt install -y python3-pip python3-dev

# Mehrere Installationsmethoden
echo "📦 Installiere influxdb-client..."
sudo pip3 install --break-system-packages influxdb-client 2>/dev/null || sudo pip3 install influxdb-client
pip3 install --user influxdb-client

echo "📦 Installiere lgpio..."
sudo pip3 install --break-system-packages lgpio 2>/dev/null || sudo pip3 install lgpio
pip3 install --user lgpio

echo "📦 Installiere DHT22 Library..."
sudo pip3 install --break-system-packages adafruit-circuitpython-dht 2>/dev/null || sudo pip3 install adafruit-circuitpython-dht
pip3 install --user adafruit-circuitpython-dht

# Korrigierten Service erstellen
echo "⚙️ Erstelle korrigierten Service..."
sudo tee /etc/systemd/system/pi5-sensor-minimal.service > /dev/null << 'EOF'
[Unit]
Description=Pi 5 Sensor Monitor (Minimal)
After=docker.service network.target
Requires=docker.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/sensor-monitor
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/home/pi/.local/bin
Environment=PYTHONPATH=/usr/local/lib/python3.11/site-packages:/home/pi/.local/lib/python3.11/site-packages
ExecStartPre=/bin/sleep 30
ExecStartPre=/usr/bin/docker compose up -d
ExecStart=/usr/bin/python3 sensor_monitor.py
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

# Test der Python Module
echo "🧪 Teste Python Module..."
cd /home/pi/sensor-monitor

echo ""
echo "📦 Teste Module:"
python3 -c "import influxdb_client; print('✅ influxdb_client OK')" || echo "❌ influxdb_client FEHLT"
python3 -c "import lgpio; print('✅ lgpio OK')" || echo "❌ lgpio FEHLT"
python3 -c "import configparser; print('✅ configparser OK')" || echo "❌ configparser FEHLT"

echo ""
echo "🚀 Teste Sensor Script..."
python3 sensor_monitor.py test

echo ""
echo "🔄 Starte Service..."
sudo systemctl start pi5-sensor-minimal.service

echo ""
echo "📊 Service Status:"
sudo systemctl status pi5-sensor-minimal.service --no-pager

echo ""
echo "✅ SERVICE FIX ABGESCHLOSSEN!"
echo ""
echo "🔍 Logs prüfen:"
echo "sudo journalctl -u pi5-sensor-minimal -f"
