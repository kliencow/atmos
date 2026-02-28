# Atmos: High-Performance Air Quality Monitoring

[![Go Version](https://img.shields.io/github/go-mod/go-version/kliencow/atmos)](https://go.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](#) 

**Atmos** is a lightweight, zero-dependency Go collector designed to bridge the gap between your **AirGradient ONE** sensors and a professional-grade **InfluxDB + Grafana** stack. 

> [!TIP]
> **Why Atmos?** Unlike generic scripts, Atmos is built for long-term stability with local-first polling, native host-thermal monitoring, and resilient firmware handling.

---

### Monitoring in Action
![Grafana Dashboard Preview](https://raw.githubusercontent.com/kliencow/atmos/main/docs/dashboard_preview.png)
*Beautiful, pre-configured dashboards for CO2, PM2.5, VOC, NOX, and local system health.*

---

### Key Features

- **Go-Native Performance**: Minimal CPU/Memory footprint, perfect for Raspberry Pi or home servers.
- **Firmware Resilient**: Custom unmarshaling logic that gracefully handles `voc` vs `tvoc_index` across different AirGradient versions.
- **Integrated Host Health**: Automatically collects Linux thermal zone data (CPU/GPU) alongside air quality.
- **Zero-Config Dashboards**: Pre-provisioned Grafana templates that work out of the box.
- **Docker & Systemd Ready**: Deploy it your way—as a containerized stack or a native background service.

---

### Quick Start

The fastest way to get your environment live is using our Docker Compose stack.

```bash
# 1. Clone and Launch the stack
git clone https://github.com/kliencow/atmos.git && cd atmos
docker-compose up -d

# 2. Configure your sensor
cp .env.example .env
# Edit .env with your SENSOR_IP and INFLUX_TOKEN

# 3. Start the collector
go run ./cmd/atmos collect --interval 1m
```

---

### Architecture

Atmos follows a modular "Collector-Writer" pattern. It polls your AirGradient sensor via its **Local HTTP API**, normalizes the data, and pipes it into InfluxDB 2.x for long-term time-series analysis.

| Component | Responsibility |
| :--- | :--- |
| **`internal/sensor`** | Resilient polling & normalization of AirGradient metrics. |
| **`internal/influx`** | Batching and writing time-series points to InfluxDB. |
| **`internal/sys`** | Extracting host-level environmental metrics (thermal zones). |

---

### ⌨️ CLI Reference

Atmos is powered by a structured, modern CLI built with [Cobra](https://github.com/spf13/cobra).

```bash
# Continuous polling (Production)
./atmos collect --serial YOUR_SERIAL --interval 60s

# One-shot diagnostic
./atmos collect --ip 192.168.1.100
```

### Global Flags

| Flag | Env Var | Description | Default |
| :--- | :--- | :--- | :--- |
| `--influx-url` | `INFLUX_URL` | InfluxDB URL | `http://localhost:8086` |
| `--influx-token`| `INFLUX_TOKEN`| InfluxDB API Token | `""` |
| `--influx-org` | `INFLUX_ORG` | InfluxDB Organization | `atmos` |
| `--influx-bucket`| `INFLUX_BUCKET`| InfluxDB Bucket | `air_quality` |

---

### Community & Support

We are huge fans of [AirGradient's](https://www.airgradient.com/) commitment to open-source hardware. If you're looking for high-quality, repairable air quality monitors, support them directly!

**Contributions welcome!** See an area for improvement? Open a PR or an Issue.

## License
MIT
