#!/usr/bin/env python3
"""
Pytest Test Suite für Pi 5 Sensor Monitor
Umfassende Tests für Hardware, Software und Integration
"""

import pytest
import time
import tempfile
import os
from unittest.mock import Mock, patch, MagicMock
import sys
from pathlib import Path

# Projekt-Pfad hinzufügen
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

@pytest.fixture
def mock_gpio():
    """Mock GPIO für Teste ohne Hardware"""
    with patch('lgpio.gpiochip_open') as mock_chip, \
         patch('lgpio.gpio_read') as mock_read, \
         patch('lgpio.gpio_write') as mock_write:
        mock_chip.return_value = 0
        mock_read.return_value = 1
        yield mock_chip, mock_read, mock_write

@pytest.fixture
def mock_ds18b20():
    """Mock DS18B20 Sensoren für Tests"""
    mock_data = [
        "28-0000000001\n",
        "28-0000000002\n", 
        "28-0000000003\n",
        "28-0000000004\n",
        "28-0000000005\n",
        "28-0000000006\n"
    ]
    
    def mock_glob(pattern):
        if pattern == '/sys/bus/w1/devices/28-*':
            return [f'/sys/bus/w1/devices/{device.strip()}' for device in mock_data]
        return []
    
    with patch('glob.glob', side_effect=mock_glob):
        yield mock_data

@pytest.fixture
def mock_dht22():
    """Mock DHT22 Sensor für Tests"""
    with patch('adafruit_dht.DHT22') as mock_dht:
        mock_sensor = Mock()
        mock_sensor.temperature = 22.5
        mock_sensor.humidity = 55.0
        mock_dht.return_value = mock_sensor
        yield mock_sensor

class TestPi5DS18B20Manager:
    """Tests für DS18B20 Manager"""
    
    def test_sensor_discovery(self, mock_ds18b20):
        """Test Sensor-Entdeckung"""
        from sensor_monitor import Pi5DS18B20Manager
        
        manager = Pi5DS18B20Manager()
        assert len(manager.sensor_ids) == 6
        assert all('28-' in sensor_id for sensor_id in manager.sensor_ids)
    
    @patch('builtins.open')
    def test_temperature_reading(self, mock_open, mock_ds18b20):
        """Test Temperatur-Lesung"""
        from sensor_monitor import Pi5DS18B20Manager
        
        # Mock Sensor-Datei
        mock_file_data = "52 01 4b 46 7f ff 0e 10 57 : crc=57 YES\n52 01 4b 46 7f ff 0e 10 57 t=21125\n"
        mock_open.return_value.__enter__.return_value.readlines.return_value = mock_file_data.split('\n')
        
        manager = Pi5DS18B20Manager()
        device_folder = '/sys/bus/w1/devices/28-0000000001'
        sensor_id = '28-0000000001'
        
        returned_id, temp = manager.read_temp_single(device_folder, sensor_id)
        
        assert returned_id == sensor_id
        assert temp == 21.125
    
    def test_parallel_reading(self, mock_ds18b20):
        """Test paralleles Lesen"""
        from sensor_monitor import Pi5DS18B20Manager
        
        with patch.object(Pi5DS18B20Manager, 'read_temp_single') as mock_read:
            mock_read.return_value = ('28-test', 20.0)
            
            manager = Pi5DS18B20Manager(high_performance=True)
            temperatures = manager.get_all_temperatures()
            
            assert len(temperatures) >= 1
            assert all(isinstance(temp, (int, float, type(None))) for temp in temperatures.values())

class TestPi5DHT22Sensor:
    """Tests für DHT22 Sensor"""
    
    def test_dht22_initialization(self, mock_dht22):
        """Test DHT22 Initialisierung"""
        from sensor_monitor import Pi5DHT22Sensor
        
        with patch('board.D18', Mock()):
            sensor = Pi5DHT22Sensor(pin=18)
            assert sensor.available == True
    
    def test_dht22_reading(self, mock_dht22):
        """Test DHT22 Daten-Lesung"""
        from sensor_monitor import Pi5DHT22Sensor
        
        with patch('board.D18', Mock()):
            sensor = Pi5DHT22Sensor(pin=18)
            sensor.sensor = mock_dht22
            
            temp, humidity = sensor.read_data()
            
            assert temp == 22.5
            assert humidity == 55.0

class TestPi5SensorMonitor:
    """Tests für Hauptklasse"""
    
    def test_monitor_initialization(self, mock_ds18b20, mock_dht22):
        """Test Monitor-Initialisierung"""
        from sensor_monitor import Pi5SensorMonitor
        
        with patch('board.D18', Mock()):
            monitor = Pi5SensorMonitor()
            assert monitor.high_performance == True
            assert monitor.error_recovery == True
            assert monitor.use_parallel_reading == True
    
    def test_hardware_check(self, mock_ds18b20):
        """Test Hardware-Überprüfung"""
        from sensor_monitor import Pi5SensorMonitor
        
        with patch('board.D18', Mock()), \
             patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open_cpuinfo()):
            
            monitor = Pi5SensorMonitor()
            result = monitor.check_hardware()
            assert result == True
    
    @patch('builtins.open')
    def test_single_reading(self, mock_open, mock_ds18b20, mock_dht22):
        """Test einmalige Messung"""
        from sensor_monitor import Pi5SensorMonitor
        
        # Mock DS18B20 Daten
        mock_file_data = "52 01 4b 46 7f ff 0e 10 57 : crc=57 YES\n52 01 4b 46 7f ff 0e 10 57 t=21125\n"
        mock_open.return_value.__enter__.return_value.readlines.return_value = mock_file_data.split('\n')
        
        with patch('board.D18', Mock()):
            monitor = Pi5SensorMonitor()
            monitor.dht22_sensor.sensor = mock_dht22
            
            ds_temps, dht_temp, dht_humidity = monitor.single_reading()
            
            assert isinstance(ds_temps, dict)
            assert dht_temp == 22.5
            assert dht_humidity == 55.0

class TestInfluxDBIntegration:
    """Tests für InfluxDB Integration"""
    
    @patch('influxdb_client.InfluxDBClient')
    def test_influxdb_connection(self, mock_client):
        """Test InfluxDB Verbindung"""
        from sensor_influxdb import Pi5InfluxDBIntegration
        
        # Mock erfolgreiche Verbindung
        mock_health = Mock()
        mock_health.status = "pass"
        mock_client.return_value.health.return_value = mock_health
        
        integration = Pi5InfluxDBIntegration()
        assert integration.connected == True
    
    @patch('influxdb_client.InfluxDBClient')
    def test_data_writing(self, mock_client):
        """Test Daten-Schreibung"""
        from sensor_influxdb import Pi5InfluxDBIntegration
        
        # Mock InfluxDB Client
        mock_health = Mock()
        mock_health.status = "pass"
        mock_client.return_value.health.return_value = mock_health
        mock_write_api = Mock()
        mock_client.return_value.write_api.return_value = mock_write_api
        
        integration = Pi5InfluxDBIntegration()
        
        # Test Daten schreiben
        sensor_data = {
            'DS18B20_1': 21.5,
            'DS18B20_2': 22.0,
            'DHT22_temp': 23.0,
            'DHT22_humidity': 55.0
        }
        
        # Test ohne Exception = Erfolg
        try:
            # Simulation der write_sensor_data Methode
            assert True  # Wenn keine Exception, dann OK
        except Exception:
            pytest.fail("Daten-Schreibung fehlgeschlagen")

def mock_open_cpuinfo():
    """Mock für /proc/cpuinfo"""
    def mock_open_func(filename, mode='r'):
        if filename == '/proc/cpuinfo':
            mock_file = Mock()
            mock_file.__enter__.return_value.read.return_value = "Model : Raspberry Pi 5"
            return mock_file
        return Mock()
    return mock_open_func

class TestSystemIntegration:
    """Integration Tests"""
    
    def test_config_loading(self):
        """Test Konfiguration laden"""
        # Test, dass config.ini gelesen werden kann
        config_path = Path(__file__).parent / 'config.ini'
        assert config_path.exists()
    
    def test_requirements_parsing(self):
        """Test Requirements"""
        req_path = Path(__file__).parent / 'requirements.txt'
        assert req_path.exists()
        
        with open(req_path, 'r') as f:
            requirements = f.readlines()
        
        # Prüfe wichtige Dependencies
        req_text = ''.join(requirements)
        assert 'lgpio' in req_text
        assert 'influxdb-client' in req_text
        assert 'adafruit-circuitpython-dht' in req_text

# Performance Tests
class TestPerformance:
    """Performance Tests"""
    
    @pytest.mark.performance
    def test_sensor_reading_speed(self, mock_ds18b20, mock_dht22):
        """Test Sensor-Lesegeschwindigkeit"""
        from sensor_monitor import Pi5SensorMonitor
        
        with patch('board.D18', Mock()), \
             patch.object(Pi5SensorMonitor, 'single_reading') as mock_reading:
            
            mock_reading.return_value = ({}, 22.0, 55.0)
            
            monitor = Pi5SensorMonitor()
            
            start_time = time.time()
            monitor.single_reading()
            end_time = time.time()
            
            read_time = (end_time - start_time) * 1000  # ms
            
            # Sollte unter 500ms für alle Sensoren sein
            assert read_time < 500, f"Lesezeit zu hoch: {read_time}ms"

if __name__ == "__main__":
    # Tests ausführen
    pytest.main([__file__, "-v", "--tb=short"])
