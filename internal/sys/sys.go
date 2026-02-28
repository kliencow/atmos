package sys

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// GPUTemp returns the temperature from the first available thermal zone
func GPUTemp() (*float64, error) {
	// Try multiple common thermal zones
	zones := []string{
		"/sys/class/thermal/thermal_zone0/temp",
		"/sys/class/thermal/thermal_zone1/temp",
		"/sys/class/hwmon/hwmon0/temp1_input",
	}

	for _, path := range zones {
		data, err := os.ReadFile(path)
		if err == nil {
			t, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
			if err == nil {
				val := t / 1000.0
				return &val, nil
			}
		}
	}
	return nil, fmt.Errorf("no thermal sensors found")
}
