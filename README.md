# Atmos

A lightweight Go application to poll real-time air quality data from an AirGradient ONE v9 (I-9PSL-DE) sensor and send it to InfluxDB + Grafana.

## Features

- **Real-time Monitoring**: VOC, NOX, Temp, Humidity, CO2, and PM2.5.
- **InfluxDB 2.x Integration**: Native support for time-series storage.
- **Grafana Dashboard**: Pre-configured dashboard for all sensors.
- **Flexible Deployment**: Choose between a native systemd service or Docker Compose.
- **Refactored CLI**: Powered by Cobra for modern command-line ergonomics.

---

## Path A: Docker Deployment (Recommended)

This is the fastest way to get started with zero manual configuration.

1. **Prerequisites**: Install [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/).
2. **Launch Services**:
   ```bash
   docker-compose up -d
   ```
   *This sets up InfluxDB and Grafana with your dashboard provisioned.*
3. **Configure Environment**: Copy `.env.example` to `.env` and fill in your sensor details and the InfluxDB token.
4. **Run the Collector**:
   ```bash
   go run ./cmd/atmos collect --interval 1m
   ```

---

## Path B: Bare Metal Deployment (Ubuntu)

1. **Install System Dependencies**:
   ```bash
   make setup-all
   ```
2. **Setup InfluxDB**:
   Follow the prompts at http://localhost:8086 or use the Influx CLI.
3. **Configure Environment**:
   Add your token and organization details to `.env`.
4. **Provision Grafana**:
   ```bash
   make setup-dashboard
   ```
5. **Install Collector Service**:
   ```bash
   make install-service
   ```

---

## CLI Usage

The collector is now a structured CLI.

```bash
# Get help
./atmos help collect

# One-shot reading
./atmos collect --ip 192.168.1.100

# Continuous polling
./atmos collect --serial YOUR_SERIAL --interval 10s
```

### Global Flags

| Flag | Env Var | Description | Default |
| :--- | :--- | :--- | :--- |
| `--influx-url` | `INFLUX_URL` | InfluxDB URL | `http://localhost:8086` |
| `--influx-token`| `INFLUX_TOKEN`| InfluxDB API Token | `""` |
| `--influx-org` | `INFLUX_ORG` | InfluxDB Organization | `atmos` |
| `--influx-bucket`| `INFLUX_BUCKET`| InfluxDB Bucket | `air_quality` |

### Collect Flags

| Flag | Env Var | Description | Default |
| :--- | :--- | :--- | :--- |
| `--ip` | `SENSOR_IP` | Sensor IP address | `""` |
| `--serial` | `SENSOR_SERIAL` | Sensor Serial (mDNS) | `""` |
| `--interval` | `POLLING_INTERVAL`| Polling interval | `0` (Once) |

---

## Maintenance & Development

- **Build**: `make build`
- **Unit Tests**: `make test`
- **Lint/Vet**: `make lint` and `make vet`
- **Check Status**: `sudo systemctl status atmos`

## Community & Credits

This project is a fan-made integration for the [AirGradient ONE](https://www.airgradient.com/open-airgradient/monitors/one/) sensor. We are big fans of AirGradient's commitment to open-source hardware and their mission to make air quality data accessible to everyone. 

If you're looking for high-quality, transparent, and repairable air quality monitors, check out their [official website](https://www.airgradient.com/).

## License
MIT
