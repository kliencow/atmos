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

This guide provides instructions for a **Native** deployment on a Linux host (e.g., a Raspberry Pi).

### 1. Stack Installation
Start by installing the core components:

```bash
make install-stack
```

### 2. Configure InfluxDB & Auto-Auth
Use the helper to initialize your database and automatically write the credentials to your `.env` file:

```bash
# Replace with your desired admin credentials
make config-influx INFLUX_USER=admin INFLUX_PASS=mysecurepassword
```

### 3. Configure Grafana Dashboard
Sync the datasource and pre-configured dashboard using your Grafana UI password (default is `admin`):

```bash
make config-grafana GRAFANA_PASS=admin
```

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

### 3. Register Your Sensors
For each AirGradient sensor, use the `Makefile` to quickly register and start new collectors.

```bash
# Register via IP
make add-sensor NAME=living_room IP=192.168.1.50

# Register via Serial (mDNS)
make add-sensor NAME=bedroom SERIAL=12345
```

### 4. Verify the Sensors
The service automatically uses the filename (e.g., `living_room`) as the **Location Tag** in Grafana.

Check the status or logs for a specific sensor:
```bash
sudo systemctl status atmos@living_room
journalctl -u atmos@living_room -f
```

---

## Maintenance & Monitoring

### **Check Global Status**
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

### **Cleaning Up Erroneous Data**
If you see spikes in your dashboard (e.g., from sensor calibration), you can surgically delete data points using the `delete-data` target.

```bash
# Delete all data in a 2-minute window
make delete-data START=2026-03-03T03:57:00Z STOP=2026-03-03T03:59:00Z

# Delete data for a specific location only
make delete-data START=2026-03-03T03:57:00Z STOP=2026-03-03T03:59:00Z PREDICATE='location="office"'
```
*Note: Timestamps must be in RFC3339 format (UTC is recommended).*

---

## Troubleshooting

### **Organization Not Found**
Ensure `INFLUX_ORG` in your `.env` matches your InfluxDB setup. Atmos expects the organization to be named `atmos` by default.

### **Port Already in Use**
If `8086` (InfluxDB) or `3000` (Grafana) are already in use, check for existing services:
```bash
sudo lsof -i :8086 -i :3000
```
You must stop conflicting services before InfluxDB or Grafana can start.
