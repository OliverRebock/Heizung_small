#!/bin/bash
# Test für MQTT Script Syntax

echo "Teste install_mqtt.sh Syntax..."

# Prüfe Bash Syntax
if bash -n install_mqtt.sh 2>/dev/null; then
    echo "✅ Bash Syntax OK"
else
    echo "❌ Bash Syntax Error:"
    bash -n install_mqtt.sh
fi
