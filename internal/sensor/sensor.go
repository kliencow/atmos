package sensor

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

// AGData represents the AirGradient sensor data
type AGData struct {
	VOC      float64 `json:"-"`
	NOX      float64 `json:"-"`
	Temp     float64 `json:"atmp"`
	Humidity float64 `json:"rhum"`
	CO2      float64 `json:"rco2"`
	PM25     float64 `json:"pm02"`
}

// UnmarshalJSON handles field variations across firmware versions
func (a *AGData) UnmarshalJSON(data []byte) error {
	type Alias AGData
	aux := struct {
		VOC            float64 `json:"voc"`
		TVOCIndex      float64 `json:"tvoc_index"`
		TVOCIndexCamel float64 `json:"tvocIndex"`
		NOXIndex       float64 `json:"nox_index"`
		NOXIndexCamel  float64 `json:"noxIndex"`
		*Alias
	}{
		Alias: (*Alias)(a),
	}
	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}

	// VOC consolidation logic
	a.VOC = aux.TVOCIndex
	if a.VOC == 0 {
		a.VOC = aux.TVOCIndexCamel
	}
	if a.VOC == 0 {
		a.VOC = aux.VOC
	}

	// NOX consolidation logic
	a.NOX = aux.NOXIndex
	if a.NOX == 0 {
		a.NOX = aux.NOXIndexCamel
	}

	return nil
}

// Fetch returns data from a sensor at the given IP address
func Fetch(ctx context.Context, ip string, debug bool) (AGData, error) {
	var data AGData
	client := http.Client{
		Timeout: 5 * time.Second,
	}
	req, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("http://%s/measures/current", ip), nil)
	if err != nil {
		return data, err
	}

	resp, err := client.Do(req)
	if err != nil {
		return data, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return data, fmt.Errorf("sensor returned unexpected status: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return data, err
	}

	if debug {
		log.Printf("DEBUG Raw JSON: %s", string(body))
	}

	if err := json.Unmarshal(body, &data); err != nil {
		return data, err
	}
	return data, nil
}
