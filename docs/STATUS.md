# Project Status: Atmos

## Current State
- **Core App**: Go collector for AirGradient ONE v9 (I-9PSL-DE). Supports both `IP` and `Serial` (mDNS).
- **Data Path**: AirGradient (HTTP JSON) -> Go Collector -> InfluxDB 2.x (Flux) -> Grafana.
- **Features**: One-shot mode, Interval mode, System Temp discovery, Comprehensive PM Monitoring (PM1.0, PM2.5, PM10, PM0.3 count), InfluxDB integration, Grafana provisioning.
- **Test Coverage**: Added unit tests for JSON parsing and system temperature extraction.
- **Hardware Verified**: Tested against Firmware v3.6.2 (Note: uses `float64` for all numeric fields due to firmware averaging).
- **Dashboard Refined**: Fully parameterized Grafana dashboard (Bucket, Measurement, Time Range) with Fahrenheit conversion.

## 🛠 Tech Stack
- **Backend**: Go 1.24+
- **Database**: InfluxDB 2.8.0
- **Visualization**: Grafana 12.4.0
- **Config**: `.env` (handled by `godotenv`)

## Key Architectural Decisions
1. **Float Support**: Firmware 3.6.2+ returns floats (e.g., `198.33`). `AGData` struct fields must remain `float64` to prevent unmarshaling errors.
2. **Grafana API over Provisioning**: The built-in Grafana YAML provisioning is prone to caching issues. Use `import_grafana.sh` (or `make setup-dashboard`) to force updates via the API.
3. **Data Source UID**: The InfluxDB data source is pinned to UID `P951FEA4DE68E13C5` to ensure dashboard portability.
4. **Polling Architecture**: Refactored to use a unified `poll` loop for both one-shot and continuous collection. System health (thermal zones) is now fetched during every poll to ensure real-time accuracy.
5. **Dashboard Flexibility**: Dashboard queries use `${bucket}` and `${measurement}` variables and standard Grafana time picker variables (`v.timeRangeStart`/`v.timeRangeStop`) for dynamic visualization.
6. **Unit Normalization**: Temperature is stored in Celsius in InfluxDB, but converted to Fahrenheit in the Grafana dashboard via Flux `map()` for localized preference.
7. **Unified Storage (v10+)**: Modern Grafana uses a resource-based storage system (`resource`, `resource_blob` tables). Manual database cleanup may be required if provisioned dashboards become "stuck" after their source files are deleted.

## Deployment Paths
- **Docker (Preferred)**: Uses `docker-compose.yml` for zero-config Influx/Grafana setup.
- **Bare Metal**: Uses `Makefile` + `setup_*.sh` scripts for native Ubuntu deployment.

## Known Gotchas
- **mDNS**: Depends on local host resolution (`avahi-daemon`). If `-serial` fails, fall back to `-ip`.
- **Grafana UID**: If the dashboard shows "Data source not found," verify the UID in `deploy/grafana/dashboards/air_quality.json` matches the one in `influxdb.yaml`.
- **Ghost Provisioning**: Deleting a dashboard provisioning `.yaml` file does not always remove the dashboard from the UI. If it persists, you must manually delete the entry from the Grafana `resource` and `resource_blob` tables.
- **Title Updates**: Changing a dashboard's `title` in a JSON file is often ignored by the Grafana cache unless the `uid` is also changed.
