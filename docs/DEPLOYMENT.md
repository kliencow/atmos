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
*   `SENSOR_IP`: The IP address of your AirGradient sensor (e.g., `192.168.1.100`).
*   `INFLUX_TOKEN`: Your InfluxDB API token.
*   `INFLUX_ORG`: Your InfluxDB organization (default: `atmos`).
*   `INFLUX_BUCKET`: Your InfluxDB bucket (default: `air_quality`).

---

### 2. Docker Deployment (Quick Start)

The Docker Compose stack includes InfluxDB and Grafana, pre-configured with the Atmos dashboard.

```bash
# Start the stack
docker-compose up -d

# Verify services are running
docker-compose ps
```

---

### 3. Native Linux Deployment

If you prefer to run services directly on your host (e.g., Ubuntu/Debian), use the provided installation scripts:

#### **A. Install InfluxDB**
```bash
bash scripts/setup_influx.sh
```
After installation, run `influx setup` to initialize your organization, bucket, and admin user.

#### **B. Install Grafana**
```bash
bash scripts/setup_grafana.sh
```
Access Grafana at `http://localhost:3000` (Default: `admin` / `admin`).

---

## Pushing Configuration Updates

If you make changes to the dashboard JSON or the datasource configuration, you can sync them to your running Grafana instance without manually using the UI.

### **Pushing Dashboard & Datasource Updates**
The `scripts/import_grafana.sh` script automates the provisioning of the InfluxDB datasource and the Air Quality dashboard.

```bash
# Ensure your .env file is correctly configured with your INFLUX_TOKEN
bash scripts/import_grafana.sh
```

**What this script does:**
1.  **Loads `.env`**: Automatically exports variables for use in the API calls.
2.  **Configures InfluxDB Datasource**: Uses the Grafana API to create or update the InfluxDB Flux datasource.
3.  **Imports Dashboard**: Uploads the content of `deploy/grafana/full_dashboard.json` to Grafana.

### **Developing Configuration Changes**
1.  Modify `deploy/grafana/full_dashboard.json` (e.g., change panel titles, queries, or units).
2.  Run `bash scripts/import_grafana.sh`.
3.  Refresh your browser at `http://localhost:3000/d/air_quality_v9` to see the changes.

---

## Troubleshooting

### **Permission Denied (Docker)**
If you get a permission error with Docker, ensure your user is in the `docker` group or use `sudo`.

### **Port Already in Use**
If `8086` (InfluxDB) or `3000` (Grafana) are already in use, check for native services:
```bash
sudo lsof -i :8086 -i :3000
```
Stop the native services (`sudo systemctl stop influxdb grafana-server`) before starting the Docker stack.
