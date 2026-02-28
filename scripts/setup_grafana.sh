#!/bin/bash
set -e

# Check for apt-get
if ! command -v apt-get >/dev/null 2>&1; then
    echo "Error: apt-get not found. This script is intended for Debian/Ubuntu systems."
    echo "Please install Grafana manually: https://grafana.com/docs/grafana/latest/setup-grafana/installation/"
    exit 1
fi

echo "--- Installing Grafana ---"
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install grafana -y

# Start and enable service
sudo systemctl enable --now grafana-server

echo "--- Grafana Installed and Started on http://localhost:3000 ---"
echo "Default login: admin / admin"
