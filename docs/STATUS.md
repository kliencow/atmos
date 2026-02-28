# Project Status: Atmos

## 🎯 Current State
- **Core App**: Go collector for AirGradient ONE v9 (I-9PSL-DE). Supports both `IP` and `Serial` (mDNS).
- **Data Path**: AirGradient (HTTP JSON) -> Go Collector -> InfluxDB 2.x (Flux) -> Grafana.
- **Features**: One-shot mode, Interval mode, System Temp discovery, InfluxDB integration, Grafana provisioning.
- **Test Coverage**: Added unit tests for environment loading and JSON parsing. Added integration tests for end-to-end data flow (Mock Sensor -> Go App -> InfluxDB) and Grafana health.
- **Hardware Verified**: Tested against Firmware v3.6.2 (Note: uses `float64` for all numeric fields due to firmware averaging).

## 🛠 Tech Stack
- **Backend**: Go 1.24+
- **Database**: InfluxDB 2.8.0
- **Visualization**: Grafana 12.4.0
- **Config**: `.env` (handled by `godotenv`)

## 🔑 Key Architectural Decisions
1. **Float Support**: Firmware 3.6.2+ returns floats (e.g., `198.33`). `AGData` struct fields must remain `float64` to prevent unmarshaling errors.
2. **Grafana API over Provisioning**: The built-in Grafana YAML provisioning is prone to caching issues. Use `import_grafana.sh` (or `make setup-dashboard`) to force updates via the API.
3. **Data Source UID**: The InfluxDB data source is pinned to UID `P951FEA4DE68E13C5` to ensure dashboard portability.

## 🚀 Deployment Paths
- **Docker (Preferred)**: Uses `docker-compose.yml` for zero-config Influx/Grafana setup.
- **Bare Metal**: Uses `Makefile` + `setup_*.sh` scripts for native Ubuntu deployment.

## 📋 Backlog / Next Steps
- [ ] Add Alerting rules in Grafana (e.g., high CO2).
- [ ] Implement multi-sensor support (polling multiple IPs from a single collector).
- [ ] Create a consolidated "Home Health" dashboard layout.
- [ ] Add persistence/retry logic to the Go collector for network blips.

## ⚠️ Known Gotchas
- **mDNS**: Depends on local host resolution (`avahi-daemon`). If `-serial` fails, fall back to `-ip`.
- **Grafana UID**: If the dashboard shows "Data source not found," verify the UID in `full_dashboard.json` matches the one in `influxdb.yaml`.
