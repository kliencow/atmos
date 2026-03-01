#!/bin/bash
# Description: Provisions the InfluxDB datasource and AirQuality dashboard into a running Grafana instance.
# Usage: ./scripts/import_grafana.sh
# Note: Requires a .env file with INFLUX_TOKEN, INFLUX_ORG, and INFLUX_BUCKET.
set -e

# Load .env to get the Influx token
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

GRAFANA_URL="http://localhost:3000"
AUTH="admin:admin"
DS_UID="P951FEA4DE68E13C5"

echo "--- Waiting for Grafana to be ready... ---"
until curl -s "$GRAFANA_URL/api/health" | grep "ok" > /dev/null; do
    sleep 2
done

echo "--- Provisioning InfluxDB Datasource ---"
curl -X POST -H "Content-Type: application/json" -u "$AUTH" "$GRAFANA_URL/api/datasources" -d '{
  "name": "InfluxDB",
  "type": "influxdb",
  "access": "proxy",
  "url": "http://localhost:8086",
  "uid": "'$DS_UID'",
  "jsonData": { "version": "Flux", "organization": "'$INFLUX_ORG'", "defaultBucket": "'$INFLUX_BUCKET'" },
  "secureJsonData": { "token": "'$INFLUX_TOKEN'" }
}' || echo "Datasource might already exist, continuing..."

echo "--- Provisioning Dashboard ---"
curl -X POST -H "Content-Type: application/json" -u "$AUTH" "$GRAFANA_URL/api/dashboards/db" -d @deploy/grafana/full_dashboard.json

echo "--- Done! Dashboard available at $GRAFANA_URL/d/air_quality_v9 ---"
