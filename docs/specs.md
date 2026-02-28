# AirGradient ONE v9 (I-9PSL-DE) Specifications

This document outlines the local API specifications for the AirGradient ONE v9 monitor based on research and empirical testing with firmware v3.6.2.

## Local API Endpoint

The device serves real-time data at:
`http://<SENSOR_IP>/measures/current`

## JSON Response Fields

The following fields are typically present in the response. Note that firmware v3.x often returns **averaged** values as floating-point numbers.

| JSON Key (Snake/Camel) | Description | Unit | Sensor |
| :--- | :--- | :--- | :--- |
| `atmp` / `atmpCompensated` | Ambient Temperature | Celsius (°C) | Sensirion SHT40 |
| `rhum` / `rhumCompensated` | Relative Humidity | % | Sensirion SHT40 |
| `rco2` | CO2 Concentration | ppm | SenseAir S8 |
| `pm02` / `pm02Compensated` | PM2.5 Concentration | µg/m³ | Plantower PMS5003 |
| `tvoc_index` / `tvocIndex` | VOC Index | 1 - 500 | Sensirion SGP41 |
| `nox_index` / `noxIndex` | NOX Index | 1 - 500 | Sensirion SGP41 |
| `tvocRaw` / `noxRaw` | Raw Sensor Signal | Ticks | Sensirion SGP41 |
| `wifi` | WiFi Signal Strength | dBm | ESP32 |
| `boot` / `bootCount` | Boot Cycle Counter | Count | System |
| `serialno` | Device Serial Number | String | System |
| `firmware` | Firmware Version | String | System |
| `model` | Device Model (I-9PSL) | String | System |

## Sensor Details

- **CO2 (SenseAir S8)**: NDIR sensor with ±40 ppm accuracy.
- **Particulate Matter (Plantower PMS5003)**: Laser scattering sensor measuring PM1.0, PM2.5, and PM10.
- **VOC/NOX (Sensirion SGP41)**: 
    - **VOC Index**: 100 is the 24-hour average baseline. Values >100 indicate increased VOCs.
    - **NOX Index**: Primarily for Nitrogen Oxide detection (combustion byproduct).
- **Temp/Humidity (Sensirion SHT40)**: High-accuracy digital sensor.

## Implementation Notes

- **Data Types**: While older documentation suggests integers, firmware 3.6.2+ returns floats for almost all metrics (e.g., `"tvocIndex": 198.33`).
- **Field Naming**: The API uses a mix of snake_case and camelCase. Robust implementations should check for both (e.g., `tvoc_index` vs `tvocIndex`).
- **Polling Rate**: The internal sensors update approximately every 1-10 seconds. Polling more frequently than 1s is not recommended.
