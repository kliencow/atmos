package sys

import (
	"testing"
)

func TestGPUTemp(t *testing.T) {
	// This test might pass or fail depending on the host,
	// but we can at least ensure it returns a result or a known error.
	temp, err := GPUTemp()
	if err != nil {
		if err.Error() != "no thermal sensors found" {
			t.Errorf("unexpected error: %v", err)
		}
		if temp != nil {
			t.Errorf("expected nil temperature on error, got %f", *temp)
		}
	} else {
		if temp == nil {
			t.Fatal("expected non-nil temperature, got nil")
		}
		if *temp <= 0 {
			t.Errorf("expected positive temperature, got %f", *temp)
		}
	}
}
