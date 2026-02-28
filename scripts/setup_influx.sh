#!/bin/bash
set -e

# Check for apt-get
if ! command -v apt-get >/dev/null 2>&1; then
    echo "Error: apt-get not found. This script is intended for Debian/Ubuntu systems."
    echo "Please install InfluxDB manually: https://docs.influxdata.com/influxdb/v2/install/"
    exit 1
fi

echo "--- Bootstrapping InfluxDB ---"

# Add GPG key
curl -fLs https://repos.influxdata.com/influxdata-archive.key | sudo gpg --dearmor -o /usr/share/keyrings/influxdata-archive.gpg

# Add repository using 'debian stable' path (compatible with Ubuntu 24.x/25.x)
echo "deb [signed-by=/usr/share/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main" | sudo tee /etc/apt/sources.list.d/influxdata.list

# Update and install
sudo apt-get update
sudo apt-get install influxdb2 influxdb2-cli -y

# Start service
sudo systemctl enable --now influxdb

echo "--- InfluxDB Installed Successfully ---"
echo "Next, run 'influx setup' to initialize your database."
