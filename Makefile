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
	@echo "  make install-provisioning - Copy provisioning files to host Grafana"
	@echo "  make setup-system    - Complete bare-metal installation (Influx, Grafana, Service)"
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

install-provisioning:
	@echo "Provisioning Grafana..."
	sudo mkdir -p /etc/grafana/provisioning/dashboards
	sudo mkdir -p /etc/grafana/provisioning/datasources
	sudo mkdir -p /var/lib/grafana/dashboards
	sudo cp deploy/grafana/dashboards.yaml /etc/grafana/provisioning/dashboards/dashboards.yaml
	sudo cp deploy/grafana/datasources/influxdb.yaml /etc/grafana/provisioning/datasources/influxdb.yaml
	sudo cp deploy/grafana/dashboards/air_quality.json /var/lib/grafana/dashboards/
	sudo chown -R grafana:grafana /var/lib/grafana/dashboards
	sudo systemctl restart grafana-server

setup-system: setup-all install-provisioning install-service
	@echo ""
	@echo "--- Bare Metal Installation Complete! ---"
	@echo "1. Run 'influx setup' to initialize your database."
	@echo "2. Update your .env file with the generated INFLUX_TOKEN."
	@echo "3. Run 'make setup-dashboard' to push the API configuration."
	@echo "----------------------------------------"

setup-dashboard:
	bash scripts/import_grafana.sh

clean:
	rm -f $(BINARY_NAME)
