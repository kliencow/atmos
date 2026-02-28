.PHONY: build test fmt vet lint install-service clean help install-influx install-grafana setup-all setup-dashboard

BINARY_NAME=atmos
SERVICE_NAME=atmos.service

help:
	@echo "Usage:"
	@echo "  make build           - Build the Go binary"
	@echo "  make test            - Run unit tests"
	@echo "  make fmt             - Run go fmt"
	@echo "  make vet             - Run go vet"
	@echo "  make lint            - Run static analysis"
	@echo "  make install-service - Install and enable the systemd service"
	@echo "  make install-influx  - Install InfluxDB and CLI (Ubuntu only)"
	@echo "  make install-grafana - Install Grafana (Ubuntu only)"
	@echo "  make setup-all       - Install both InfluxDB and Grafana"
	@echo "  make setup-dashboard - Provision Grafana dashboard via API"
	@echo "  make clean           - Remove binary and build artifacts"

build: fmt vet
	go build -o $(BINARY_NAME) ./cmd/atmos

test:
	go test -v ./...

fmt:
	go fmt ./...

vet:
	go vet ./...

lint:
	@if command -v staticcheck > /dev/null; then \
		staticcheck ./...; \
	else \
		echo "staticcheck not found, skipping. Install it with: go install honnef.co/go/tools/cmd/staticcheck@latest"; \
	fi

install: build
	sudo cp $(BINARY_NAME) /usr/local/bin/$(BINARY_NAME)

install-service: install
	@echo "Installing systemd service..."
	sudo cp deploy/systemd/$(SERVICE_NAME) /etc/systemd/system/$(SERVICE_NAME)
	sudo sed -i "s|User=USER_PLACEHOLDER|User=$(USER)|" /etc/systemd/system/$(SERVICE_NAME)
	sudo sed -i "s|DIR_PLACEHOLDER|$(PWD)|g" /etc/systemd/system/$(SERVICE_NAME)
	sudo systemctl daemon-reload
	sudo systemctl enable --now $(SERVICE_NAME)
	@echo "Service installed and started. Check status with: sudo systemctl status $(SERVICE_NAME)"

install-influx:
	bash scripts/setup_influx.sh

install-grafana:
	bash scripts/setup_grafana.sh

setup-all: install-influx install-grafana

setup-dashboard:
	bash scripts/import_grafana.sh

clean:
	rm -f $(BINARY_NAME)
