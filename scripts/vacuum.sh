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
        # We use math.abs and float comparison
        QUERY="import \"math\"
from(bucket: \"$BUCKET\")
  |> range(start: -${DAYS}d)
  |> filter(fn: (r) => r._field == \"$FIELD\")
  |> derivative(unit: 1m, nonNegative: false)
  |> filter(fn: (r) => math.abs(x: r._value) > float(v: $THRESHOLD))"

        # Get raw timestamps using awk to find the _time column
        SPIKES=$(influx query "$QUERY" --org "$ORG" --raw | awk -F, '
            NR==1 { next } 
            /^#group/ { next } 
            /^#default/ { next } 
            /^#datatype/ { 
                for(i=1;i<=NF;i++) if($i=="dateTime:RFC3339" || $i=="dateTime:RFC3339Nano") time_col=i 
                next 
            } 
            /^,result/ { 
                if (!time_col) for(i=1;i<=NF;i++) if($i=="_time") time_col=i
                next 
            }
            { if (time_col && $time_col ~ /[0-9]/) print $time_col }
        ' || true)
        
        if [ -n "$SPIKES" ]; then
            COUNT=$(echo "$SPIKES" | wc -l)
            echo "Found $COUNT spikes in $FIELD. Deleting..."
            for TIME in $SPIKES; do
                echo "  Deleting spike at $TIME"
                influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "_field=\"$FIELD\""
            done
        else
            echo "No spikes found in $FIELD."
        fi
    fi

    # 3. Absolute Zero Check (Invalid readings for certain metrics)
    if [[ "$FIELD" == "co2" || "$FIELD" == "temp" || "$FIELD" == "humidity" ]]; then
        echo "Scanning $FIELD for absolute 0 values..."
        # Use 0.0 for float comparison
        ZERO_QUERY="from(bucket: \"$BUCKET\")
  |> range(start: -${DAYS}d)
  |> filter(fn: (r) => r._field == \"$FIELD\")
  |> filter(fn: (r) => r._value == 0.0)"

        ZEROS=$(influx query "$ZERO_QUERY" --org "$ORG" --raw | awk -F, '
            NR==1 { next } 
            /^#group/ { next } 
            /^#default/ { next } 
            /^#datatype/ { 
                for(i=1;i<=NF;i++) if($i=="dateTime:RFC3339" || $i=="dateTime:RFC3339Nano") time_col=i 
                next 
            } 
            /^,result/ { 
                if (!time_col) for(i=1;i<=NF;i++) if($i=="_time") time_col=i
                next 
            }
            { if (time_col && $time_col ~ /[0-9]/) print $time_col }
        ' || true)

        if [ -n "$ZEROS" ]; then
            COUNT=$(echo "$ZEROS" | wc -l)
            echo "Found $COUNT zero points in $FIELD. Deleting..."
            for TIME in $ZEROS; do
                echo "  Deleting zero point at $TIME"
                influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "_field=\"$FIELD\""
            done
        else
            echo "No zero points found in $FIELD."
        fi
    fi
done

echo "--- Vacuuming Complete ---"
