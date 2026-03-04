# Deployment and Setup Guide

This guide provides step-by-step instructions for setting up the **Atmos** monitoring stack and deploying configuration updates to InfluxDB and Grafana.

---

## System Requirements

| Component | Minimum Version | Recommended |
| :--- | :--- | :--- |
| **AirGradient** | [ONE (v9) / DIY](about_airgradient.md) | Firmware 3.6.2+ |
| **InfluxDB** | 2.0 | 2.7.x |
| **Grafana** | 9.0 | 10.x |
| **Go** | 1.21+ | 1.22+ |

---
## Initial Setup

You can choose between a **Docker-based** deployment (recommended for ease of use) or a **Native** deployment on a Linux host (e.g., a Raspberry Pi).

### 1. Global Infrastructure Configuration
Regardless of the deployment method, start by creating your global infrastructure file. This file contains the credentials for your database.

```bash
cp .env.example .env
```

**Key variables to configure in `.env`:**
*   `INFLUX_TOKEN`: Your InfluxDB API token.
*   `INFLUX_ORG`: Your InfluxDB organization (default: `atmos`).
*   `INFLUX_BUCKET`: Your InfluxDB bucket (default: `air_quality`).

---

## Multi-Sensor Deployment (Native)

Atmos uses **systemd templates** to run multiple collectors (one per room). 

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

### 3. Identity Configuration (Per Sensor)
For each AirGradient sensor, create a small environment file in `/etc/atmos/`. This file provides the "Identity" flags to the collector service.

**Example: `/etc/atmos/living_room.env`**
```bash
# Provide either IP or Serial
SENSOR_SERIAL=12345
# SENSOR_IP=192.168.1.50
```

### 4. Start the Collectors
The service automatically uses the filename (e.g., `living_room`) as the **Location Tag** in Grafana. You can use the `Makefile` to quickly register new sensors:

```bash
# Register via IP
make setup-sensor NAME=living_room IP=192.168.1.50

# Register via Serial (mDNS)
make setup-sensor NAME=bedroom SERIAL=12345
```

Check the status or logs for a specific sensor:
```bash
sudo systemctl status atmos@living_room
journalctl -u atmos@living_room -f
```

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
1.  Modify `deploy/grafana/dashboards/air_quality.json` (e.g., change panel titles, queries, or units).
2.  Run `bash scripts/import_grafana.sh`.
3.  Refresh your browser at `http://localhost:3000/d/air_quality_v9` to see the changes.

---

## Troubleshooting & Health Checks

The primary tool for verifying your installation is the **Status Command**. It checks the database, the dashboard, and every individual sensor collector.

```bash
make status
```

### **Understanding the Status Report**
- **Stack Checks**: Verifies InfluxDB and Grafana APIs are responsive.
- **`[Reachable]`**: Atmos just performed a real-time connection check to the sensor's Local API.
- **`[Unreachable]`**: The sensor is likely offline or on a different VLAN/subnet.

#### **Status Glossary (systemd)**
| State | Sub-state | Meaning |
| :--- | :--- | :--- |
| **`active`** | **`running`** | **Normal**. The collector is in memory and polling data. |
| **`active`** | **`exited`** | **Success**. Used for "one-shot" mode where Atmos ran once and finished. |
| **`failed`** | **`failed`** | **Error**. The process crashed or could not start (check logs). |
| **`inactive`**| **`dead`** | **Stopped**. The service has been manually disabled or stopped. |

### **Check Logs for a Specific Sensor**
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
