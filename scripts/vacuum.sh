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

        # Get raw data including tags using awk
        # Output format: TIME|LOCATION|SENSOR
        DATA=$(influx query "$QUERY" --org "$ORG" --raw | awk -F, '
            NR==1 { next } 
            /^#group/ { next } 
            /^#default/ { next } 
            /^#datatype/ { 
                for(i=1;i<=NF;i++) {
                    if($i=="dateTime:RFC3339" || $i=="dateTime:RFC3339Nano") time_col=i 
                    if($i=="string" || $i=="tag") {
                        # We will look for specific tag names in the header row
                    }
                }
                next 
            } 
            /^,result/ { 
                for(i=1;i<=NF;i++) {
                    if($i=="_time") time_col=i
                    if($i=="location") loc_col=i
                    if($i=="sensor") sen_col=i
                }
                next 
            }
            { 
                if (time_col && $time_col ~ /[0-9]/) {
                    loc = (loc_col ? $loc_col : "")
                    sen = (sen_col ? $sen_col : "")
                    print $time_col "|" loc "|" sen
                }
            }
        ' || true)
        
        if [ -n "$DATA" ]; then
            COUNT=$(echo "$DATA" | wc -l)
            echo "Found $COUNT spikes in $FIELD. Deleting..."
            echo "$DATA" | while IFS='|' read -r TIME LOC SEN; do
                echo "  Deleting spike at $TIME (Location: $LOC, Sensor: $SEN)"
                # Delete by tags instead of field, as some InfluxDB versions dont support field predicates
                PRED="location=\"$LOC\""
                [ -n "$SEN" ] && PRED="$PRED AND sensor=\"$SEN\""
                influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "$PRED"
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

        ZERO_DATA=$(influx query "$ZERO_QUERY" --org "$ORG" --raw | awk -F, '
            NR==1 { next } 
            /^#group/ { next } 
            /^#default/ { next } 
            /^#datatype/ { 
                for(i=1;i<=NF;i++) if($i=="dateTime:RFC3339" || $i=="dateTime:RFC3339Nano") time_col=i 
                next 
            } 
            /^,result/ { 
                for(i=1;i<=NF;i++) {
                    if($i=="_time") time_col=i
                    if($i=="location") loc_col=i
                    if($i=="sensor") sen_col=i
                }
                next 
            }
            { 
                if (time_col && $time_col ~ /[0-9]/) {
                    loc = (loc_col ? $loc_col : "")
                    sen = (sen_col ? $sen_col : "")
                    print $time_col "|" loc "|" sen
                }
            }
        ' || true)

        if [ -n "$ZERO_DATA" ]; then
            COUNT=$(echo "$ZERO_DATA" | wc -l)
            echo "Found $COUNT zero points in $FIELD. Deleting..."
            echo "$ZERO_DATA" | while IFS='|' read -r TIME LOC SEN; do
                echo "  Deleting zero point at $TIME (Location: $LOC, Sensor: $SEN)"
                PRED="location=\"$LOC\""
                [ -n "$SEN" ] && PRED="$PRED AND sensor=\"$SEN\""
                influx delete --bucket "$BUCKET" --org "$ORG" --start "$TIME" --stop "$TIME" --predicate "$PRED"
            done
        else
            echo "No zero points found in $FIELD."
        fi
    fi
done

echo "--- Vacuuming Complete ---"
