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
FIELDS=("co2" "temp" "humidity" "pm25")
THRESHOLDS=($VACUUM_CO2_DELTA $VACUUM_TEMP_DELTA $VACUUM_HUMIDITY_DELTA $VACUUM_PM25_DELTA)

for i in "${!FIELDS[@]}"; do
    FIELD=${FIELDS[$i]}
    THRESHOLD=${THRESHOLDS[$i]}
    
    if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" -gt 0 ]; then
        echo "Scanning $FIELD for jumps > $THRESHOLD per minute..."
        
        # 2. Find the timestamps of spikes using the derivative() function
        QUERY="import \"math\"
from(bucket: \"$BUCKET\")
  |> range(start: -${DAYS}d)
  |> filter(fn: (r) => r._field == \"$FIELD\")
  |> derivative(unit: 1m, nonNegative: false)
  |> filter(fn: (r) => math.abs(x: r._value) > $THRESHOLD)
  |> keep(columns: [\"_time\"])"

        # Get raw timestamps
        SPIKES=$(influx query "$QUERY" --org "$ORG" --raw | grep -v "^#" | grep -v "^,result" | cut -d, -f6 | grep "[0-9]" || true)
        
        if [ -n "$SPIKES" ]; then
            COUNT=$(echo "$SPIKES" | wc -l)
            echo "Found $COUNT spikes in $FIELD. Deleting..."
            for TIME in $SPIKES; do
                influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "_field=\"$FIELD\""
            done
        else
            echo "No spikes found in $FIELD."
        fi
    fi

    # 3. Absolute Zero Check (Invalid readings for certain metrics)
    if [[ "$FIELD" == "co2" || "$FIELD" == "temp" || "$FIELD" == "humidity" ]]; then
        echo "Scanning $FIELD for absolute 0 values..."
        ZERO_QUERY="from(bucket: \"$BUCKET\")
  |> range(start: -${DAYS}d)
  |> filter(fn: (r) => r._field == \"$FIELD\")
  |> filter(fn: (r) => r._value == 0)
  |> keep(columns: [\"_time\"])"

        ZEROS=$(influx query "$ZERO_QUERY" --org "$ORG" --raw | grep -v "^#" | grep -v "^,result" | cut -d, -f6 | grep "[0-9]" || true)

        if [ -n "$ZEROS" ]; then
            COUNT=$(echo "$ZEROS" | wc -l)
            echo "Found $COUNT zero points in $FIELD. Deleting..."
            for TIME in $ZEROS; do
                influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "_field=\"$FIELD\""
            done
        else
            echo "No zero points found in $FIELD."
        fi
    fi
done

echo "--- Vacuuming Complete ---"
