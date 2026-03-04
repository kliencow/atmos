#!/bin/bash
# Description: Automatically finds and deletes data points that exhibit impossible "jumps" (spikes).
# Usage: ./scripts/vacuum.sh [DAYS_BACK]
set -e

# Load .env to get tokens/org
export $(grep -v '^#' .env | xargs) || { echo "Error: .env file not found or invalid."; exit 1; }

DAYS=${1:-7}
ORG=${INFLUX_ORG:-atmos}
BUCKET=${INFLUX_BUCKET:-air_quality}

echo "--- Starting Delta-Based Vacuum (Last $DAYS days) ---"

# 1. Prepare Fields and Thresholds
FIELDS=("co2" "humidity" "pm25")
THRESHOLDS=($VACUUM_CO2_DELTA $VACUUM_HUMIDITY_DELTA $VACUUM_PM25_DELTA)

for i in "${!FIELDS[@]}"; do
    FIELD=${FIELDS[$i]}
    THRESHOLD=${THRESHOLDS[$i]}
    
    if [ -z "$THRESHOLD" ] || [ "$THRESHOLD" -le 0 ]; then
        echo "Skipping $FIELD (no threshold set in .env)"
        continue
    fi
    
    echo "Scanning $FIELD for jumps > $THRESHOLD per minute..."
    
    # 2. Find the timestamps of spikes using the derivative() function
    # derivative(unit: 1m) gives the rate of change per minute.
    # math.abs() ensures we catch both upward and downward jumps.
    QUERY="import \"math\"
from(bucket: \"$BUCKET\")
  |> range(start: -${DAYS}d)
  |> filter(fn: (r) => r._field == \"$FIELD\")
  |> derivative(unit: 1m, nonNegative: false)
  |> filter(fn: (r) => math.abs(x: r._value) > $THRESHOLD)
  |> keep(columns: [\"_time\"])"

    # Get raw timestamps
    # Filter out empty lines and CSV headers
    SPIKES=$(influx query "$QUERY" --org "$ORG" --raw | grep -v "^#" | grep -v "^,result" | cut -d, -f6 | grep "[0-9]" || true)
    
    # 3. Delete the specific spikes
    if [ -n "$SPIKES" ]; then
        COUNT=$(echo "$SPIKES" | wc -l)
        echo "Found $COUNT spikes in $FIELD. Deleting..."
        
        for TIME in $SPIKES; do
            # Using the exact timestamp for both start and stop is valid in InfluxDB
            # to target a single point if it matches exactly. 
            # Note: We need to use the exact string Influx returned.
            echo "  Deleting spike at $TIME"
            influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "_field=\"$FIELD\""
        done
    else
        echo "No spikes found in $FIELD."
    fi
done

echo "--- Vacuuming Complete ---"
