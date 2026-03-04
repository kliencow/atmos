#!/bin/bash
# Description: Initializes InfluxDB and automatically updates the .env file with the generated credentials.
# Usage: ./scripts/init_influx.sh USERNAME PASSWORD
set -e

USERNAME=$1
PASSWORD=$2
ORG=${INFLUX_ORG:-atmos}
BUCKET=${INFLUX_BUCKET:-air_quality}
ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

# 1. Ensure .env exists
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo "Created $ENV_FILE from example."
    else
        touch "$ENV_FILE"
        echo "Created empty $ENV_FILE."
    fi
fi

echo "--- Initializing InfluxDB ---"

# 2. Run Influx Setup (Non-Interactive)
# This will fail if already setup, which is fine.
if influx setup --host http://localhost:8086 
    --username "$USERNAME" 
    --password "$PASSWORD" 
    --org "$ORG" 
    --bucket "$BUCKET" 
    --force 2>/dev/null; then
    
    echo "InfluxDB initialized successfully."
else
    echo "InfluxDB appears to be already initialized. Skipping setup."
fi

# 3. Retrieve or Create Admin Token
# We'll try to get the existing token first
TOKEN=$(influx auth list --user "$USERNAME" --hide-headers | awk '{print $4}' | head -n 1)

if [ -z "$TOKEN" ]; then
    echo "Creating new all-access token..."
    TOKEN=$(influx auth create --all-access --org "$ORG" --description "Atmos-Admin-Token" --hide-headers | awk '{print $3}')
fi

# 4. Update .env File
echo "--- Updating $ENV_FILE with new credentials ---"

# Helper function to update or append env var
update_env() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

update_env "INFLUX_TOKEN" "$TOKEN"
update_env "INFLUX_ORG" "$ORG"
update_env "INFLUX_BUCKET" "$BUCKET"
update_env "INFLUX_URL" "http://localhost:8086"

echo "Success! $ENV_FILE has been updated with your InfluxDB credentials."
echo "Token: ${TOKEN:0:4}...${TOKEN: -4}"
