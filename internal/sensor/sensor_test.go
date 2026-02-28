package sensor

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAGDataUnmarshal(t *testing.T) {
	// Test camelCase (like firmware 3.6.2)
	jsonData := `{"tvocIndex": 198.33, "noxIndex": 1.5, "atmp": 20.5, "rhum": 45.2, "rco2": 800.0, "pm02": 0.5}`
	var data AGData
	if err := json.Unmarshal([]byte(jsonData), &data); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if data.VOC != 198.33 {
		t.Errorf("expected 198.33, got %f", data.VOC)
	}
	if data.Temp != 20.5 {
		t.Errorf("expected 20.5, got %f", data.Temp)
	}

	// Test snake_case fallback
	jsonDataSnake := `{"tvoc_index": 150, "nox_index": 2}`
	var dataSnake AGData
	if err := json.Unmarshal([]byte(jsonDataSnake), &dataSnake); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if dataSnake.VOC != 150 {
		t.Errorf("expected 150, got %f", dataSnake.VOC)
	}
	if dataSnake.NOX != 2 {
		t.Errorf("expected 2, got %f", dataSnake.NOX)
	}
}

func TestFetch(t *testing.T) {
	// Setup mock server
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/measures/current" {
			t.Errorf("expected path /measures/current, got %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"tvocIndex": 100, "atmp": 22.5}`))
	}))
	defer ts.Close()

	// Use mock server's address (strip http://)
	addr := ts.Listener.Addr().String()

	data, err := Fetch(context.Background(), addr, false)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if data.VOC != 100 {
		t.Errorf("expected 100, got %f", data.VOC)
	}
	if data.Temp != 22.5 {
		t.Errorf("expected 22.5, got %f", data.Temp)
	}
}

func TestFetchError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer ts.Close()

	addr := ts.Listener.Addr().String()
	_, err := Fetch(context.Background(), addr, false)
	if err == nil {
		t.Fatal("expected error for 500 status, got nil")
	}
}
