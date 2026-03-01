# Deployment and Setup Guide

This guide provides step-by-step instructions for setting up the **Atmos** monitoring stack and deploying configuration updates to InfluxDB and Grafana.

---

## Initial Setup

You can choose between a **Docker-based** deployment (recommended for ease of use) or a **Native** deployment on a Linux host (e.g., a Raspberry Pi).

### 1. Environment Configuration
Regardless of the deployment method, start by creating your environment file:

```bash
cp .env.example .env
```

**Key variables to configure in `.env`:**
*   `INFLUX_TOKEN`: Your InfluxDB API token.
*   `INFLUX_ORG`: Your InfluxDB organization (default: `atmos`).
*   `INFLUX_BUCKET`: Your InfluxDB bucket (default: `air_quality`).

---

## Multi-Sensor Deployment (Native)

Atmos uses **systemd templates** to run multiple collectors (one per room) from a single binary and service file.

### 1. Install the Atmos Binary
```bash
make build
sudo cp atmos /usr/local/bin/
```

### 2. Install the Service Template
```bash
# This installs atmos@.service
sudo cp deploy/systemd/atmos@.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### 3. Configure Your Locations
For each AirGradient sensor, create a configuration file in `/etc/atmos/`. The filename will be used as the **Location Tag** in Grafana.

**Example: `/etc/atmos/living_room.env`**
```bash
# Use either IP or Serial (for mDNS)
SENSOR_SERIAL=12345
# SENSOR_IP=192.168.1.50
```

### 4. Start the Collectors
Enable and start the service instance for each location:

```bash
sudo systemctl enable --now atmos@living_room
sudo systemctl enable --now atmos@bedroom
```

---

## Dashboard Configuration

### **Pushing Dashboard & Datasource Updates**
The `scripts/import_grafana.sh` script automates the provisioning of the InfluxDB datasource and the Air Quality dashboard.

```bash
# Ensure your .env file is correctly configured with your INFLUX_TOKEN
bash scripts/import_grafana.sh
```

**Multi-Sensor Support in Grafana:**
- **Grouping**: Each panel is pre-configured to group data by the `location` tag.
- **Filtering**: Use the **Location** dropdown at the top of the dashboard to filter for a specific room or select "All" to overlay every sensor on a single graph.

### **Developing Configuration Changes**
1.  Modify `deploy/grafana/full_dashboard.json` (e.g., change panel titles, queries, or units).
2.  Run `bash scripts/import_grafana.sh`.
3.  Refresh your browser at `http://localhost:3000/d/air_quality_v9` to see the changes.

---

## Troubleshooting

### **Check Logs for a Specific Location**
```bash
journalctl -u atmos@living_room -f
```

### **Organization Not Found**
Ensure `INFLUX_ORG` in your `.env` matches your InfluxDB setup. Atmos expects the organization to be named `atmos` by default.

### **Port Already in Use**
If `8086` (InfluxDB) or `3000` (Grafana) are already in use, check for native services:
```bash
sudo lsof -i :8086 -i :3000
```
Stop the native services (`sudo systemctl stop influxdb grafana-server`) before starting the Docker stack.
