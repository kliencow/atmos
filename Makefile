.PHONY: build test fmt vet lint install-service clean help install-influx install-grafana setup-all setup-dashboard setup-system install-provisioning setup-instance

BINARY_NAME=atmos
SERVICE_TEMPLATE=atmos@.service

help:
	@echo "Atmos Management - Usage:"
	@echo "  make build           - Build the Go binary"
	@echo "  make test            - Run unit tests"
	@echo "  make setup-system    - FULL INSTALL: Influx, Grafana, Provisioning, and Service Template"
	@echo "  make setup-instance  - Create a new room instance (e.g. make setup-instance NAME=living_room)"
	@echo "  make setup-dashboard - Sync the latest dashboard via Grafana API"
	@echo "  make clean           - Remove binary and build artifacts"

# --- Development ---
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

# --- System-level Setup ---
setup-system: install-influx install-grafana install-provisioning install-service
	@echo ""
	@echo "--- Bare Metal Installation Complete! ---"
	@echo "1. Run 'influx setup' to initialize your database."
	@echo "2. Copy .env.example to .env and update with your new INFLUX_TOKEN."
	@echo "3. Run 'make setup-instance NAME=living_room' to configure your first sensor."
	@echo "4. Run 'make setup-dashboard' to finalize the UI."
	@echo "----------------------------------------"

install-influx:
	bash scripts/setup_influx.sh

install-grafana:
	bash scripts/setup_grafana.sh

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

install: build
	sudo cp $(BINARY_NAME) /usr/local/bin/$(BINARY_NAME)

install-service: install
	@echo "Installing systemd service template..."
	sudo cp deploy/systemd/$(SERVICE_TEMPLATE) /etc/systemd/system/$(SERVICE_TEMPLATE)
	sudo sed -i "s|User=USER_PLACEHOLDER|User=$(USER)|" /etc/systemd/system/$(SERVICE_TEMPLATE)
	sudo sed -i "s|DIR_PLACEHOLDER|$(PWD)|g" /etc/systemd/system/$(SERVICE_TEMPLATE)
	sudo systemctl daemon-reload
	@echo "Service template installed."

# --- Instance-level Management ---
setup-instance:
	@if [ -z "$(NAME)" ]; then echo "Error: NAME is required. Usage: make setup-instance NAME=room_name"; exit 1; fi
	@echo "Setting up instance for: $(NAME)"
	sudo mkdir -p /etc/atmos
	@if [ ! -f /etc/atmos/$(NAME).env ]; then \
		echo "SENSOR_SERIAL=CHANGE_ME" | sudo tee /etc/atmos/$(NAME).env; \
		echo "Created /etc/atmos/$(NAME).env - Please edit it with your sensor details."; \
	fi
	sudo systemctl enable --now atmos@$(NAME)
	@echo "Instance atmos@$(NAME) started. Check logs with: journalctl -u atmos@$(NAME) -f"

setup-dashboard:
	bash scripts/import_grafana.sh

clean:
	rm -f $(BINARY_NAME)
