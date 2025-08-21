#!/usr/bin/env python3
"""
Web Dashboard für Pi 5 Sensor Monitor
Minimales Flask-Interface für Live-Daten und System-Status
"""

from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import json
import time
import threading
from datetime import datetime
import logging
import configparser

# Projekt-Imports
try:
    from sensor_monitor import Pi5SensorMonitor
    from advanced_monitoring import AdvancedMonitoringService
    SENSOR_AVAILABLE = True
except ImportError:
    SENSOR_AVAILABLE = False

app = Flask(__name__)
app.config['SECRET_KEY'] = 'pi5-sensor-secret-key-2024'
socketio = SocketIO(app, cors_allowed_origins="*")

# Globale Variablen
current_sensor_data = {}
monitoring_active = False
monitoring_thread = None

logger = logging.getLogger(__name__)

class WebDashboardService:
    """Web Dashboard Service für Pi 5 Sensor Monitor"""
    
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read('config.ini')
        
        if SENSOR_AVAILABLE:
            self.sensor_monitor = Pi5SensorMonitor()
            self.advanced_monitoring = AdvancedMonitoringService()
        
        self.last_update = None
        self.system_stats = {}
    
    def get_sensor_data(self):
        """Holt aktuelle Sensor-Daten"""
        if not SENSOR_AVAILABLE:
            return self._get_mock_data()
        
        try:
            ds_temps, dht_temp, dht_humidity = self.sensor_monitor.single_reading()
            
            # Formatiere Daten für Web-Interface
            formatted_data = {}
            
            # DS18B20 Sensoren
            for sensor_name, temp in ds_temps.items():
                if temp is not None:
                    label = self.config.get('labels', sensor_name.lower(), fallback=sensor_name)
                    formatted_data[sensor_name] = {
                        'label': label,
                        'value': round(temp, 1),
                        'unit': '°C',
                        'type': 'temperature',
                        'status': 'ok' if 10 <= temp <= 30 else 'warning'
                    }
            
            # DHT22 Sensor
            if dht_temp is not None:
                formatted_data['DHT22_temp'] = {
                    'label': 'Raumtemperatur',
                    'value': round(dht_temp, 1),
                    'unit': '°C',
                    'type': 'temperature',
                    'status': 'ok' if 18 <= dht_temp <= 25 else 'warning'
                }
            
            if dht_humidity is not None:
                formatted_data['DHT22_humidity'] = {
                    'label': 'Luftfeuchtigkeit',
                    'value': round(dht_humidity, 1),
                    'unit': '%',
                    'type': 'humidity',
                    'status': 'ok' if 30 <= dht_humidity <= 70 else 'warning'
                }
            
            self.last_update = datetime.now().isoformat()
            return formatted_data
            
        except Exception as e:
            logger.error(f"Sensor-Daten Fehler: {e}")
            return {}
    
    def get_system_status(self):
        """Holt System-Status"""
        if not SENSOR_AVAILABLE:
            return self._get_mock_system_status()
        
        try:
            # Advanced Monitoring verwenden
            mock_sensor_data = {k: v['value'] for k, v in current_sensor_data.items() 
                              if v and 'value' in v}
            
            monitoring_results = self.advanced_monitoring.run_monitoring_cycle(mock_sensor_data)
            
            return {
                'cpu_usage': monitoring_results['system_health']['cpu_usage'],
                'memory_usage': monitoring_results['system_health']['memory_usage'],
                'disk_usage': monitoring_results['system_health']['disk_usage'],
                'cpu_temperature': monitoring_results['system_health'].get('cpu_temperature'),
                'active_sensors': monitoring_results['sensor_health']['active_sensors'],
                'total_sensors': monitoring_results['sensor_health']['total_sensors'],
                'last_update': self.last_update
            }
        except Exception as e:
            logger.error(f"System-Status Fehler: {e}")
            return self._get_mock_system_status()
    
    def _get_mock_data(self):
        """Mock-Daten für Tests ohne Hardware"""
        import random
        return {
            'DS18B20_1': {'label': 'Vorlauf', 'value': round(random.uniform(20, 25), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DS18B20_2': {'label': 'Rücklauf', 'value': round(random.uniform(18, 22), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DS18B20_3': {'label': 'Warmwasser', 'value': round(random.uniform(45, 55), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DS18B20_4': {'label': 'Außentemperatur', 'value': round(random.uniform(-5, 15), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DS18B20_5': {'label': 'Heizraum', 'value': round(random.uniform(15, 20), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DS18B20_6': {'label': 'Puffer oben', 'value': round(random.uniform(40, 50), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DHT22_temp': {'label': 'Raumtemperatur', 'value': round(random.uniform(19, 23), 1), 'unit': '°C', 'type': 'temperature', 'status': 'ok'},
            'DHT22_humidity': {'label': 'Luftfeuchtigkeit', 'value': round(random.uniform(40, 60), 1), 'unit': '%', 'type': 'humidity', 'status': 'ok'}
        }
    
    def _get_mock_system_status(self):
        """Mock System-Status"""
        import random
        return {
            'cpu_usage': round(random.uniform(10, 30), 1),
            'memory_usage': round(random.uniform(20, 40), 1),
            'disk_usage': round(random.uniform(15, 25), 1),
            'cpu_temperature': round(random.uniform(45, 55), 1),
            'active_sensors': 7,
            'total_sensors': 7,
            'last_update': datetime.now().isoformat()
        }

# Dashboard Service initialisieren
dashboard = WebDashboardService()

# Routes
@app.route('/')
def index():
    """Haupt-Dashboard"""
    return render_template('dashboard.html')

@app.route('/api/sensors')
def api_sensors():
    """API: Aktuelle Sensor-Daten"""
    global current_sensor_data
    current_sensor_data = dashboard.get_sensor_data()
    return jsonify(current_sensor_data)

@app.route('/api/system')
def api_system():
    """API: System-Status"""
    return jsonify(dashboard.get_system_status())

@app.route('/api/health')
def api_health():
    """API: Health Check"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'sensors_available': SENSOR_AVAILABLE
    })

# WebSocket Events
@socketio.on('connect')
def handle_connect():
    """Client verbunden"""
    emit('status', {'message': 'Verbunden mit Pi 5 Sensor Monitor'})

@socketio.on('disconnect')
def handle_disconnect():
    """Client getrennt"""
    print('Client disconnected')

@socketio.on('start_monitoring')
def handle_start_monitoring():
    """Live-Monitoring starten"""
    global monitoring_active, monitoring_thread
    
    if not monitoring_active:
        monitoring_active = True
        monitoring_thread = threading.Thread(target=live_monitoring_worker)
        monitoring_thread.daemon = True
        monitoring_thread.start()
        emit('monitoring_status', {'active': True})

@socketio.on('stop_monitoring')
def handle_stop_monitoring():
    """Live-Monitoring stoppen"""
    global monitoring_active
    monitoring_active = False
    emit('monitoring_status', {'active': False})

def live_monitoring_worker():
    """Worker für Live-Monitoring"""
    global monitoring_active, current_sensor_data
    
    while monitoring_active:
        try:
            # Sensor-Daten aktualisieren
            current_sensor_data = dashboard.get_sensor_data()
            system_status = dashboard.get_system_status()
            
            # An alle Clients senden
            socketio.emit('sensor_update', current_sensor_data)
            socketio.emit('system_update', system_status)
            
            time.sleep(5)  # 5 Sekunden Intervall
            
        except Exception as e:
            logger.error(f"Live-Monitoring Fehler: {e}")
            time.sleep(10)

# HTML Template (minimal)
html_template = '''
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi 5 Sensor Monitor</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .sensor-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .sensor-value.ok { color: #27ae60; }
        .sensor-value.warning { color: #f39c12; }
        .sensor-value.error { color: #e74c3c; }
        .system-stats { display: flex; justify-content: space-between; margin-top: 15px; }
        .stat { text-align: center; }
        .stat-value { font-size: 1.5em; font-weight: bold; }
        .controls { margin: 20px 0; }
        button { padding: 10px 20px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; }
        .btn-primary { background: #3498db; color: white; }
        .btn-success { background: #27ae60; color: white; }
        .btn-danger { background: #e74c3c; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌡️ Pi 5 Sensor Monitor</h1>
        <p>Live-Überwachung der Heizungsanlage</p>
    </div>
    
    <div class="controls">
        <button id="startBtn" class="btn-success" onclick="startMonitoring()">▶️ Live-Monitoring starten</button>
        <button id="stopBtn" class="btn-danger" onclick="stopMonitoring()">⏹️ Stoppen</button>
        <button class="btn-primary" onclick="refreshData()">🔄 Aktualisieren</button>
    </div>
    
    <div class="grid">
        <div class="card">
            <h3>🖥️ System-Status</h3>
            <div class="system-stats">
                <div class="stat">
                    <div>CPU</div>
                    <div id="cpu" class="stat-value">-</div>
                </div>
                <div class="stat">
                    <div>RAM</div>
                    <div id="memory" class="stat-value">-</div>
                </div>
                <div class="stat">
                    <div>Disk</div>
                    <div id="disk" class="stat-value">-</div>
                </div>
                <div class="stat">
                    <div>Temp</div>
                    <div id="cpuTemp" class="stat-value">-</div>
                </div>
            </div>
            <p>Aktive Sensoren: <span id="activeSensors">-</span></p>
            <p>Letzte Aktualisierung: <span id="lastUpdate">-</span></p>
        </div>
        
        <div id="sensorCards" class="grid" style="grid-column: 1 / -1;">
            <!-- Sensor-Karten werden hier eingefügt -->
        </div>
    </div>

    <script>
        const socket = io();
        let monitoringActive = false;
        
        socket.on('connect', function() {
            console.log('Verbunden mit Server');
            refreshData();
        });
        
        socket.on('sensor_update', function(data) {
            updateSensorDisplay(data);
        });
        
        socket.on('system_update', function(data) {
            updateSystemDisplay(data);
        });
        
        socket.on('monitoring_status', function(data) {
            monitoringActive = data.active;
            updateButtonStates();
        });
        
        function startMonitoring() {
            socket.emit('start_monitoring');
        }
        
        function stopMonitoring() {
            socket.emit('stop_monitoring');
        }
        
        function refreshData() {
            fetch('/api/sensors')
                .then(response => response.json())
                .then(data => updateSensorDisplay(data));
                
            fetch('/api/system')
                .then(response => response.json())
                .then(data => updateSystemDisplay(data));
        }
        
        function updateSensorDisplay(sensors) {
            const container = document.getElementById('sensorCards');
            container.innerHTML = '';
            
            Object.entries(sensors).forEach(([key, sensor]) => {
                if (sensor && sensor.value !== null) {
                    const card = document.createElement('div');
                    card.className = 'card';
                    card.innerHTML = `
                        <h4>${sensor.label}</h4>
                        <div class="sensor-value ${sensor.status}">
                            ${sensor.value} ${sensor.unit}
                        </div>
                        <small>Sensor: ${key}</small>
                    `;
                    container.appendChild(card);
                }
            });
        }
        
        function updateSystemDisplay(system) {
            document.getElementById('cpu').textContent = system.cpu_usage + '%';
            document.getElementById('memory').textContent = system.memory_usage + '%';
            document.getElementById('disk').textContent = system.disk_usage + '%';
            document.getElementById('cpuTemp').textContent = 
                system.cpu_temperature ? system.cpu_temperature + '°C' : '-';
            document.getElementById('activeSensors').textContent = 
                system.active_sensors + '/' + system.total_sensors;
            document.getElementById('lastUpdate').textContent = 
                new Date(system.last_update).toLocaleString();
        }
        
        function updateButtonStates() {
            document.getElementById('startBtn').disabled = monitoringActive;
            document.getElementById('stopBtn').disabled = !monitoringActive;
        }
        
        // Initiale Daten laden
        setTimeout(refreshData, 1000);
    </script>
</body>
</html>
'''

# Template-Verzeichnis erstellen und HTML speichern
import os
template_dir = 'templates'
if not os.path.exists(template_dir):
    os.makedirs(template_dir)

with open(os.path.join(template_dir, 'dashboard.html'), 'w', encoding='utf-8') as f:
    f.write(html_template)

if __name__ == '__main__':
    print("🌐 Pi 5 Sensor Monitor Web Dashboard")
    print("===================================")
    print("Starte Web-Server...")
    print("URL: http://localhost:5000")
    print("Drücke Ctrl+C zum Beenden")
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
